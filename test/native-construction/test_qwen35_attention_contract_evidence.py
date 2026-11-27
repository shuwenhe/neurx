"""Evidence consistency tests, not Native numerical acceptance."""
import json,unittest
from pathlib import Path
P=Path(__file__).resolve().parents[2]/'artifact/build/qwen35_attention_bf16/contract-review/v4'
class Evidence(unittest.TestCase):
 def test_norm_coverage_and_real_gpu(self):
  a=json.loads((P/'norm.json').read_text());self.assertEqual(len(a),48)
  self.assertEqual({r['d'] for r in a},{6,8,64,256})
  for r in a:
   self.assertTrue(all(e['device'].startswith('cuda') for e in r['events']))
   self.assertTrue(any(e['op']=='aten.rsqrt.default' for e in r['events']))
   self.assertEqual(r['events'][-1]['dtype'],'torch.bfloat16')
   self.assertEqual(r['weight'][1],-0.99609375)
   self.assertEqual(r['weight'][2],-1.0078125)
   if r['kind']=='zero':self.assertEqual(r['metrics']['max_absolute_error'],0)
 def test_softmax_mask_policies(self):
  a=json.loads((P/'softmax.json').read_text());self.assertEqual(len(a),72)
  for r in a:
   m=r['fp32_metrics']
   if r['kind']=='all_inf_mask':self.assertEqual(m['nan'],2*r['n']);self.assertTrue(m['nan_pattern_equal'])
   else:self.assertEqual(m['nan'],0);self.assertEqual(m['inf'],0)
   if r['kind']=='all_finite_mask':
    self.assertTrue(all(abs(x-1/r['n'])<2**-23 for row in r['fp32_output'] for x in row))
 def test_composition_coverage(self):
  a=json.loads((P/'composition.json').read_text());self.assertEqual(len(a),9)
  self.assertEqual({r['length'] for r in a},{3,17,65})
  for r in a:
   self.assertEqual(r['output_vs_prefill']['nan'],0)
   self.assertTrue(r['local_same_operands'])
if __name__=='__main__':unittest.main(verbosity=2)
