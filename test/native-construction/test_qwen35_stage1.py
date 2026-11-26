"""Native metadata tests: real files and hand-derived byte ranges, no mock decoder."""
import copy
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "artifact/build/qwen35_stage1"
MODEL = ROOT.parent / "model/Qwen3.6-35B-A3B"


def config():
    return {"model_type":"qwen3_5_moe", "text_config":{
        "model_type":"qwen3_5_moe_text", "hidden_size":8, "vocab_size":16,
        "num_hidden_layers":2, "layer_types":["linear_attention","full_attention"],
        "num_attention_heads":2, "num_key_value_heads":1, "head_dim":4,
        "attention_bias":False, "attention_dropout":0, "attn_output_gate":True,
        "hidden_act":"silu", "tie_word_embeddings":False, "rms_norm_eps":1e-6,
        "dtype":"bfloat16", "max_position_embeddings":64,
        "linear_num_key_heads":1,"linear_num_value_heads":2,
        "linear_key_head_dim":2,"linear_value_head_dim":3,"linear_conv_kernel_dim":4,
        "mamba_ssm_dtype":"float32", "num_experts":4,"num_experts_per_tok":2,
        "moe_intermediate_size":4,"shared_expert_intermediate_size":4,
        "partial_rotary_factor":.5,
        "rope_parameters":{"rope_type":"default","rope_theta":10000,
                           "partial_rotary_factor":.5,"mrope_section":[1,0,0],"mrope_interleaved":True}}}


def shard(path, tensors, *, raw_header=None, payload=None):
    header = {}; data = bytearray()
    for name, shape in tensors.items():
        count = 1
        for dim in shape: count *= dim
        start = len(data)
        data.extend(b"\x80\x3f" * count)  # genuine BF16 1.0 metadata fixtures
        header[name] = dict(dtype="BF16",shape=shape,data_offsets=[start,len(data)])
    encoded = raw_header if raw_header is not None else json.dumps(header).encode()
    path.write_bytes(struct.pack("<Q",len(encoded))+encoded+(data if payload is None else payload))
    return header


def model_fixture(path):
    (path/"config.json").write_text(json.dumps(config()))
    tensors = {"model.language_model.embed_tokens.weight":[16,8],
               "model.language_model.norm.weight":[8],"lm_head.weight":[16,8]}
    for layer in range(2):
        pre = f"model.language_model.layers.{layer}."
        fields = {"input_layernorm.weight":[8],"post_attention_layernorm.weight":[8],
                  "mlp.gate.weight":[4,8],"mlp.experts.gate_up_proj":[4,8,8],
                  "mlp.experts.down_proj":[4,8,4],"mlp.shared_expert_gate.weight":[1,8],
                  "mlp.shared_expert.gate_proj.weight":[4,8],"mlp.shared_expert.up_proj.weight":[4,8],
                  "mlp.shared_expert.down_proj.weight":[8,4]}
        if layer == 0:
            fields.update({"linear_attn.in_proj_qkv.weight":[10,8],"linear_attn.in_proj_z.weight":[6,8],
                           "linear_attn.in_proj_a.weight":[2,8],"linear_attn.in_proj_b.weight":[2,8],
                           "linear_attn.A_log":[2],"linear_attn.dt_bias":[2],
                           "linear_attn.conv1d.weight":[10,1,4],"linear_attn.norm.weight":[3],
                           "linear_attn.out_proj.weight":[8,6]})
        else:
            fields.update({"self_attn.q_proj.weight":[16,8],"self_attn.k_proj.weight":[4,8],
                           "self_attn.v_proj.weight":[4,8],"self_attn.o_proj.weight":[8,8],
                           "self_attn.q_norm.weight":[4],"self_attn.k_norm.weight":[4]})
        tensors.update({pre+k:v for k,v in fields.items()})
    shard(path/"model.safetensors",tensors)
    return tensors


class Stage1(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        BUILD.mkdir(parents=True,exist_ok=True)
        cls.probe = BUILD/"probe"
        if os.environ.get("QWEN35_STAGE1_PROBE"):
            cls.probe=Path(os.environ["QWEN35_STAGE1_PROBE"]).resolve()
            if not cls.probe.is_file(): raise AssertionError("selected native probe is missing")
            return
        sources = [ROOT/"test/native-construction/qwen35_stage1_probe.cpp"]
        sources += [ROOT/"src/runtime/model"/(name+".cpp") for name in
                    ("hybrid_config","mapped_weight_store","architecture_registry")]
        cmd = [os.environ.get("CXX","g++"),"-std=c++17","-O2","-Wall","-Wextra","-Werror",
               *map(str,sources),"-lcrypto","-o",str(cls.probe)]
        result = subprocess.run(cmd,capture_output=True,text=True)
        if result.returncode: raise AssertionError("Stage1 native build failed:\n"+result.stderr)

    def run_probe(self, op, path, *args, reject=False):
        r = subprocess.run([str(self.probe),op,str(path),*map(str,args)],capture_output=True,text=True,timeout=30)
        if reject:
            self.assertEqual(r.returncode,1,r.stdout+r.stderr)
            self.assertIn("REJECTED:",r.stderr)
            return r.stderr
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        return json.loads(r.stdout)

    def test_config_reads_mixed_shapes_and_checked_state_bytes(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d);(p/"config.json").write_text(json.dumps(config()))
            result=self.run_probe("config",p,32)
            self.assertEqual([result[k] for k in ("layers","full","linear","hidden","query_width")],[2,1,1,8,8])
            self.assertEqual([result[k] for k in ("kv_bytes","recurrent_bytes","conv_bytes")],[1024,48,160])
            self.run_probe("config",p,65,reject=True)

    def test_config_rejects_invalid_or_unsupported_semantics(self):
        mutations = [("hidden_size",0),("hidden_size",8.5),("hidden_size",2**63),
                     ("layer_types",["linear_attention"]),("layer_types",["unknown","full_attention"]),
                     ("num_key_value_heads",3),("num_experts_per_tok",5),("linear_num_key_heads",3),
                     ("attn_output_gate",False),("attention_bias",True),("hidden_act","relu"),
                     ("dtype","int4"),("mamba_ssm_dtype","float16"),("tie_word_embeddings",True),
                     ("attention_dropout",.1),("partial_rotary_factor",.25),("use_sliding_window",True),
                     ("unrecognized_position_policy","alternate")]
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d)
            for key,value in mutations:
                with self.subTest(key=key,value=value):
                    cfg=config();cfg["text_config"][key]=value;(p/"config.json").write_text(json.dumps(cfg))
                    self.run_probe("config",p,reject=True)
            cfg=config();cfg["text_config"]["rope_parameters"]["rope_type"]="unknown"
            (p/"config.json").write_text(json.dumps(cfg));self.run_probe("config",p,reject=True)

    def test_config_duplicate_keys_rejected(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d);text=json.dumps(config()).replace('"hidden_size": 8','"hidden_size": 8, "hidden_size": 9')
            (p/"config.json").write_text(text);self.run_probe("config",p,reject=True)

    def test_expert_slice_rows_and_mapping_lifetime(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d);raw=bytes(range(24));h=b'{"experts":{"dtype":"BF16","shape":[2,2,3],"data_offsets":[0,24]}}'
            shard(p/"model.safetensors",{},raw_header=h,payload=raw)
            result=self.run_probe("expert",p,"experts",1)
            self.assertEqual((result["shape"],result["size"],result["hex"]),([2,3],12,"0c0d0e0f1011121314151617"))
            self.run_probe("expert",p,"experts",2,reject=True)
            result=self.run_probe("lifetime",p,"experts")
            self.assertEqual(result["hex"],raw.hex());self.assertTrue(result["bounds_rejected"])
            shard(p/"model.safetensors",{},raw_header=b'{"w":{"dtype":"F32","shape":[2,3],"data_offsets":[0,24]}}',payload=raw)
            self.assertEqual(self.run_probe("rows",p,"w",1,1)["hex"],"0c0d0e0f1011121314151617")
            self.run_probe("rows",p,"w",1,2,reject=True)

    def test_metadata_limits_total_size_dtype_and_fd_cleanup(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d);header=shard(p/"model.safetensors",{"x":[2]})
            self.run_probe("store-limit",p,1,1024,reject=True)
            self.run_probe("store-limit",p,1024,1,reject=True)
            self.assertEqual(self.run_probe("store-limit",p,1024,1024)["tensors"],1)
            r=self.run_probe("fd-stress",p);self.assertEqual(r["fd_before"],r["fd_after"])
            (p/"model.safetensors").rename(p/"a.safetensors")
            (p/"model.safetensors.index.json").write_text(json.dumps({"metadata":{"total_size":6},"weight_map":{"x":"a.safetensors"}}))
            self.run_probe("store",p,reject=True)
            r=self.run_probe("fd-stress",p);self.assertEqual(r["fd_before"],r["fd_after"])
            (p/"model.safetensors.index.json").write_text('{"weight_map":{"x":"a.safetensors","x":"a.safetensors"}}')
            self.run_probe("store",p,reject=True)
            (p/"model.safetensors.index.json").unlink();(p/"a.safetensors").unlink()
            model_fixture(p)
            raw=(p/"model.safetensors").read_bytes();n=struct.unpack("<Q",raw[:8])[0];h=json.loads(raw[8:8+n])
            h["model.language_model.norm.weight"]["dtype"]="F16"
            shard(p/"model.safetensors",{},raw_header=json.dumps(h).encode(),payload=raw[8+n:])
            self.run_probe("inspect",p,reject=True)

    def test_fifo_inputs_fail_without_blocking(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d)
            for name,op in [("config.json","config"),("model.safetensors","store"),
                            ("model.safetensors.index.json","store")]:
                with self.subTest(name=name):
                    os.mkfifo(p/name)
                    try:
                        r=subprocess.run([str(self.probe),op,str(p)],capture_output=True,text=True,timeout=2)
                        self.assertEqual(r.returncode,1,r.stdout+r.stderr)
                    finally: (p/name).unlink()

    def test_raw_index_bytes_count_against_metadata_budget(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d);shard(p/"a.safetensors",{"x":[2]})
            text=json.dumps({"weight_map":{"x":"a.safetensors"}})+" "*4096
            (p/"model.safetensors.index.json").write_text(text)
            self.run_probe("store-limit",p,1024,1024,reject=True)

    def test_shard_index_and_malformed_metadata_fail_closed(self):
        cases = [
            b'{"x":{"dtype":"BF16","shape":[2],"data_offsets":[0,3]}}',
            b'{"x":{"dtype":"BF16","shape":[2],"data_offsets":[1,5]}}',
            b'{"x":{"dtype":"BF16","shape":[2],"data_offsets":[0,4]},"y":{"dtype":"BF16","shape":[2],"data_offsets":[2,6]}}',
            b'{"x":{"dtype":"BF16","shape":[9223372036854775808,4],"data_offsets":[0,4]}}',
            b'{"x":{"dtype":"INT4","shape":[2],"data_offsets":[0,4]}}',
            b'{"x":{"dtype":"BF16","shape":[2],"data_offsets":[0,4]},"x":{"dtype":"BF16","shape":[2],"data_offsets":[0,4]}}',
            b'{}']
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d)
            for header in cases:
                with self.subTest(header=header):
                    shard(p/"model.safetensors",{},raw_header=header,payload=b"\0"*4)
                    self.run_probe("store",p,reject=True)
            shard(p/"a.safetensors",{"x":[2]});(p/"model.safetensors").unlink()
            for wm in ({"x":"../a.safetensors"},{"x":"/a.safetensors"},{"x":"missing"},{"missing":"a.safetensors"},{},
                       {"x":"a.safetensors","y":"link.safetensors"}):
                (p/"model.safetensors.index.json").write_text(json.dumps({"weight_map":wm}))
                (p/"link.safetensors").unlink(missing_ok=True);(p/"link.safetensors").symlink_to(p/"a.safetensors")
                self.run_probe("store",p,reject=True)
            (p/"model.safetensors.index.json").write_text(json.dumps({"weight_map":{"x":"a.safetensors"}}))
            self.assertEqual(self.run_probe("store",p)["payload_bytes"],4)
            (p/"a.safetensors").write_bytes(b"short");self.run_probe("store",p,reject=True)

    def test_manifest_exact_shapes_and_unsupported_runtime(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d);tensors=model_fixture(p)
            result=self.run_probe("inspect",p)
            self.assertEqual((result["text"],result["vision"],result["mtp"]),(36,0,0))
            self.assertFalse(result["runtime_supported"])
            identity=result["metadata_identity"];self.assertEqual(len(identity),64)
            cfg=config();cfg["text_config"]["rms_norm_eps"]=2e-6
            (p/"config.json").write_text(json.dumps(cfg))
            self.assertNotEqual(self.run_probe("inspect",p)["metadata_identity"],identity)
            for key,shape in [("model.language_model.layers.0.linear_attn.norm.weight",[2]),
                              ("model.language_model.layers.1.self_attn.q_proj.weight",[8,8]),
                              ("model.language_model.layers.0.mlp.experts.gate_up_proj",[4,4,8]),
                              ("unrecognized.weight",[1])]:
                with self.subTest(key=key):
                    changed=copy.deepcopy(tensors);changed[key]=shape;shard(p/"model.safetensors",changed)
                    self.run_probe("inspect",p,reject=True)
            del tensors["lm_head.weight"];shard(p/"model.safetensors",tensors)
            self.run_probe("inspect",p,reject=True)

    def test_sparse_large_payload_does_not_materialize_weights(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d);size=2**32
            h=json.dumps({"huge":{"dtype":"BF16","shape":[size//2],"data_offsets":[0,size]}}).encode()
            with (p/"model.safetensors").open("wb") as f:
                f.write(struct.pack("<Q",len(h))+h);f.truncate(8+len(h)+size)
            result=self.run_probe("store",p)
            self.assertEqual(result["payload_bytes"],4294967296)
            self.assertLess(result["max_rss_kib"],96*1024)

    def test_real_checkpoint_metadata_and_expert_sample(self):
        self.assertTrue(MODEL.is_dir(),"real acceptance model missing")
        c=self.run_probe("config",MODEL,2048)
        self.assertEqual([c[k] for k in ("layers","linear","full","hidden","query_width")],[40,30,10,2048,4096])
        self.assertEqual([c[k] for k in ("kv_bytes","recurrent_bytes","conv_bytes")],[83886080,62914560,3932160])
        result=self.run_probe("inspect",MODEL)
        self.assertEqual([result[k] for k in ("tensors","text","vision","mtp","payload_bytes")],[1045,693,333,19,71903645408])
        self.assertFalse(result["runtime_supported"]);self.assertLess(result["max_rss_kib"],96*1024)
        name="model.language_model.layers.0.mlp.experts.gate_up_proj"
        sample=self.run_probe("expert",MODEL,name,7)
        index=json.loads((MODEL/"model.safetensors.index.json").read_text())
        with (MODEL/index["weight_map"][name]).open("rb") as f:
            n=struct.unpack("<Q",f.read(8))[0];header=json.loads(f.read(n))
            f.seek(8+n+header[name]["data_offsets"][0]+7*4194304);expected=f.read(32).hex()
        self.assertEqual(sample["hex"],expected);self.assertEqual(sample["size"],4194304)


if __name__ == "__main__": unittest.main(verbosity=2)
