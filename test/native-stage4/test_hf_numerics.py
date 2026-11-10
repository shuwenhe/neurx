"""Numerical Qwen regressions executed by the native S compiler."""
import json
import math
import struct
import shutil
import numpy as np
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
S_ROOT = Path(os.environ.get('S_REPO_ROOT', ROOT.parent / 's'))
COMPILER = Path(os.environ.get('S_NATIVE_COMPILER', S_ROOT / 'bin/s_compiler'))


class NativeHFNumerics(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='neurx-hf-numerics-')
        cls.folder = Path(cls.temporary.name)
        result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--compiler', str(COMPILER),
                                 '--s-root', str(S_ROOT), '--commands', 'serve', '--output-dir', str(cls.folder / 'build')],
                                capture_output=True, text=True, timeout=180)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        cls.sources = [source for source in (cls.folder / 'build/serve.sources').read_text().splitlines()
                       if Path(source) != ROOT / 'cmd/serve/main.s']

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def probe(self, body):
        source = self.folder / 'probe.s'
        source.write_text('package main\nimport ("neurx.backends.cpu.transformer_decode"; "neurx.models.loaders.hf_transformer"; "neurx.models.formats.hf_config")\nfunc main() int {\n' + body + '\nreturn 0\n}\n')
        assembly, executable = self.folder / 'probe.sasm', self.folder / 'probe'
        result = subprocess.run([str(COMPILER), '--compile-unit', str(assembly), str(source), *self.sources],
                                capture_output=True, text=True, timeout=180)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = subprocess.run([str(COMPILER), '--emit-bin', str(assembly), str(executable)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, 'native probe exit=' + str(result.returncode) + result.stdout + result.stderr)

    def test_qwen_rope_uses_split_halves_and_head_dimension_frequencies(self):
        body = 'float[] input = float[]{1.0, 2.0, 3.0, 4.0}\n'
        for index, position in enumerate((1, 63)):
            expected = [math.cos(position) - 3 * math.sin(position),
                        2 * math.cos(position / 100) - 4 * math.sin(position / 100),
                        3 * math.cos(position) + math.sin(position),
                        4 * math.cos(position / 100) + 2 * math.sin(position / 100)]
            body += f'float[] output{index} = hf_rope(input, 1, 4, {position}, 10000.0)\n'
            for dim, value in enumerate(expected):
                body += f'if cpu_abs(output{index}[{dim}] - ({value:.16f})) > 0.0000001 {{ return {1 + 4 * index + dim} }}\n'
        self.probe(body)

    def test_exp_and_rms_preserve_small_values_without_softmax_clamping(self):
        body = ''
        for index, value in enumerate((-30., -15., -3., 0., 3., 15.)):
            expected = math.exp(value)
            body += f'if cpu_abs(cpu_exp({value}) - {expected:.18f}) > {max(1e-15, expected * 1e-10):.18f} {{ return {index + 1} }}\n'
        body += 'float[] normalized = hf_rms_norm(float[]{0.00001, 0.00002}, float[]{1.0, 1.0}, 0.000001)\n'
        expected = .00001 / math.sqrt((.00001 ** 2 + .00002 ** 2) / 2 + .000001)
        body += f'if cpu_abs(normalized[0] - {expected:.16f}) > 0.00000001 {{ return 10 }}\n'
        self.probe(body)

    def test_bias_free_omitted_flag_remains_loadable(self):
        model = self.folder / 'llama-no-bias-flag'
        shutil.copytree(ROOT / 'test/fixture/hf_tiny', model)
        config = json.loads((model / 'config.json').read_text())
        del config['attention_bias']
        config['model_type'] = 'llama'
        (model / 'config.json').write_text(json.dumps(config))
        (model / 'model.safetensors').write_bytes(bytes.fromhex((model / 'model.safetensors.hex').read_text()))
        self.probe(f'hf_model_weights model = load_hf_model("{model}")\nif !model.valid {{ return 91 }}')
        for model_type, expected in [('qwen2', True), ('llama', False)]:
            config['model_type'] = model_type
            literal = json.dumps(json.dumps(config))
            self.probe(f'hf_model_config config = parse_hf_config({literal})\nif config.attention_bias != {str(expected).lower()} {{ return 92 }}')
        config['attention_bias'] = True
        (model / 'config.json').write_text(json.dumps(config))
        self.probe(f'hf_model_weights model = load_hf_model("{model}")\nif model.valid {{ return 93 }}')

    def test_bf16_qwen_bias_and_multitoken_forward_match_numpy(self):
        rng = np.random.default_rng(991)
        hidden, intermediate, vocabulary = 4, 6, 7
        tensors = {}
        def add(name, shape, scale=.2, norm=False):
            value = (rng.normal(size=shape) * scale + (1 if norm else 0)).astype('<f4')
            bits = value.view('<u4') >> 16
            tensors[name] = ((bits << 16).astype('<u4').view('<f4').astype(np.float64), bits.astype('<u2').tobytes())
        add('model.embed_tokens.weight', (vocabulary, hidden))
        add('model.norm.weight', (hidden,), norm=True)
        for layer in range(2):
            prefix = f'model.layers.{layer}.'
            for name in ('input_layernorm.weight', 'post_attention_layernorm.weight'):
                add(prefix + name, (hidden,), norm=True)
            for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj'):
                add(prefix + 'self_attn.' + name + '.weight', (hidden, hidden))
                if name != 'o_proj':
                    add(prefix + 'self_attn.' + name + '.bias', (hidden,), scale=.3)
            for name in ('gate_proj', 'up_proj', 'down_proj'):
                add(prefix + 'mlp.' + name + '.weight', (hidden, intermediate) if name == 'down_proj' else (intermediate, hidden))
        model = self.folder / 'qwen-bf16'
        model.mkdir(exist_ok=True)
        config = dict(hidden_size=hidden, intermediate_size=intermediate, num_attention_heads=1,
                      num_key_value_heads=1, num_hidden_layers=2, vocab_size=vocabulary,
                      rms_norm_eps=1e-6, rope_theta=10000, max_position_embeddings=64,
                      attention_bias=True, tie_word_embeddings=True, model_type='qwen2')
        (model / 'config.json').write_text(json.dumps(config))
        def write_weights():
            header, data = {}, b''
            for name, (value, raw) in tensors.items():
                header[name] = dict(dtype='BF16', shape=list(value.shape), data_offsets=[len(data), len(data) + len(raw)])
                data += raw
            encoded = json.dumps(header, separators=(',', ':')).encode()
            (model / 'model.safetensors').write_bytes(struct.pack('<Q', len(encoded)) + encoded + data)
        write_weights()
        cache = [([], []) for _ in range(2)]
        def norm(value, weight):
            return value / np.sqrt(np.mean(value * value) + 1e-6) * weight
        def tensor(name):
            return tensors[name][0]
        body = f'hf_model_weights model = load_hf_model("{model}")\nif !model.valid {{ return 50 }}\n'
        body += 'float[] keys = make(float[], 2 * 8 * 4)\nfloat[] values = make(float[], 2 * 8 * 4)\n'
        for position, token in enumerate((1, 4, 2)):
            value = tensor('model.embed_tokens.weight')[token].copy()
            for layer in range(2):
                prefix = f'model.layers.{layer}.'
                normalized = norm(value, tensor(prefix + 'input_layernorm.weight'))
                q, k, v = [tensor(prefix + 'self_attn.' + name + '.weight') @ normalized + tensor(prefix + 'self_attn.' + name + '.bias') for name in ('q_proj', 'k_proj', 'v_proj')]
                angles = position / (10000 ** (np.arange(0, hidden, 2) / hidden))
                for vector in (q, k):
                    left, right = vector[:2].copy(), vector[2:].copy()
                    vector[:2] = left * np.cos(angles) - right * np.sin(angles)
                    vector[2:] = right * np.cos(angles) + left * np.sin(angles)
                cache[layer][0].append(k)
                cache[layer][1].append(v)
                scores = np.array(cache[layer][0]) @ q / math.sqrt(hidden)
                scores = np.exp(scores - np.max(scores)); scores /= scores.sum()
                value += tensor(prefix + 'self_attn.o_proj.weight') @ (scores @ np.array(cache[layer][1]))
                normalized = norm(value, tensor(prefix + 'post_attention_layernorm.weight'))
                gate = tensor(prefix + 'mlp.gate_proj.weight') @ normalized
                up = tensor(prefix + 'mlp.up_proj.weight') @ normalized
                value += tensor(prefix + 'mlp.down_proj.weight') @ (gate / (1 + np.exp(-gate)) * up)
            logits = tensor('model.embed_tokens.weight') @ norm(value, tensor('model.norm.weight'))
            body += f'hf_layer_result state{position} = hf_forward_token(model, {token}, keys, values, 8, {position})\n'
            body += f'if !state{position}.ok {{ return {51 + position} }}\n'
            for dimension, expected in enumerate(value):
                body += f'if cpu_abs(state{position}.hidden[{dimension}] - ({expected:.16f})) > 0.000001 {{ return {60 + position * hidden + dimension} }}\n'
            body += f'if hf_argmax_logits(model, state{position}.hidden) != {np.argmax(logits)} {{ return {80 + position} }}\n'
            body += f'keys = state{position}.cache.keys\nvalues = state{position}.cache.values\n'
        self.probe(body)
        # Bias-enabled checkpoints must fail closed if a required bias is missing.
        del tensors['model.layers.0.self_attn.q_proj.bias']
        write_weights()
        self.probe(f'hf_model_weights model = load_hf_model("{model}")\nif model.valid {{ return 90 }}')


if __name__ == '__main__':
    unittest.main()
