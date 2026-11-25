"""Incomplete checkpoints and unsupported architectures must fail before startup."""
import importlib.util,json,pathlib,struct,tempfile,unittest
root=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('preflight',root/'scripts/check_inference_model.py');preflight=importlib.util.module_from_spec(spec);spec.loader.exec_module(preflight)
class PreflightTests(unittest.TestCase):
 def fixture(self,p,model_type='qwen2'):
  (p/'config.json').write_text(json.dumps({'model_type':model_type}));(p/'tokenizer.json').write_text('{}')
  h=json.dumps({'w':{'dtype':'BF16','shape':[1],'data_offsets':[0,2]}}).encode();(p/'model.safetensors').write_bytes(struct.pack('<Q',len(h))+h+b'\0\0')
 def test_complete_supported_model(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);self.fixture(p);self.assertEqual(preflight.check_model(p)['errors'],[])
 def test_missing_shards_and_tokenizer_reported_together(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);self.fixture(p,'qwen3_5_moe');(p/'tokenizer.json').unlink();(p/'model.safetensors').rename(p/'model-00007-of-00026.safetensors')
   errors='; '.join(preflight.check_model(p)['errors']);self.assertIn('tokenizer.json',errors);self.assertIn('1/26',errors);self.assertIn('index',errors);self.assertIn('Gated DeltaNet',errors)
 def test_truncated_weight_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);self.fixture(p);f=p/'model.safetensors';f.write_bytes(f.read_bytes()[:-1]);self.assertIn('truncated','; '.join(preflight.check_model(p)['errors']))
 def test_model_index_checks_referenced_shards(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);self.fixture(p);(p/'model.safetensors').unlink();(p/'model.safetensors.index.json').write_text(json.dumps({'weight_map':{'w':'model-00001-of-00002.safetensors'}}));self.assertIn('missing shard','; '.join(preflight.check_model(p)['errors']))
if __name__=='__main__':unittest.main()
