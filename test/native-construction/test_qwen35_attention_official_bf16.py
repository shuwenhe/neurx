"""Phase A GPU oracle/observation gates; no Native Attention kernels exist here."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from qwen35_attention_official_reference import load_official, fixture, run_reference, configure_runtime, ROOT
BUILD = ROOT/'artifact/build/qwen35_attention_bf16/reference'
REQUIRED = {'q_projection','k_projection','v_projection','gate_projection','q_rmsnorm','k_rmsnorm',
            'partial_rope_q','partial_rope_k','kv_cache_k','kv_cache_v','qk_score','scale','causal_mask',
            'fp32_softmax','bf16_probability','av','sigmoid_gate','gated_av','output_projection'}

class OfficialAttention(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        BUILD.mkdir(parents=True,exist_ok=True)
        cls.runtime=configure_runtime();cls.results=[]
        (BUILD/'runtime.json').write_text(json.dumps(cls.runtime,indent=2)+'\n')

    def save(self,label,j,result):
        if sum(len(j[k]) for k in ['qg','k','v','o']) > 1_000_000:
            manifest={k:v for k,v in j.items() if k not in ['qg','k','v','o','qnorm','knorm','x']}
            manifest['numpy_version']=np.__version__
            manifest['payload_float32_sha256']={k:hashlib.sha256(np.asarray(j[k],dtype='<f4').tobytes()).hexdigest() for k in ['qg','k','v','o','qnorm','knorm','x']}
            manifest['reproduce']='fixture(**parameters): fixed RNG generation order in hash-pinned harness'
            (BUILD/(label+'-manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n')
        else:
            (BUILD/(label+'-fixture.json')).write_text(json.dumps(j)+'\n')
        (BUILD/(label+'-trace.json')).write_text(json.dumps(result,indent=2)+'\n')
        self.results.append(dict(case=label,node_count=len(result['nodes']),trace_bytes=result['trace_bytes']))

    def test_all_required_nodes_and_dtype_boundaries(self):
        for seed in [521,1807]:
            j=fixture(seed=seed);a=run_reference(j);self.save(f'seed{seed}',j,a)
            names={n['node'] for n in a['nodes']}
            self.assertTrue(REQUIRED<=names, sorted(REQUIRED-names))
            for n in a['nodes']:
                self.assertEqual(n['output_dtype'],'torch.float32' if n['node']=='fp32_softmax' else 'torch.bfloat16',n)
                self.assertEqual(n['metrics']['nan'],0);self.assertEqual(n['metrics']['inf'],0)
                self.assertIn('max_absolute_error',n['metrics']);self.assertIn('mean_absolute_error',n['metrics']);self.assertIn('max_relative_error',n['metrics'])
            self.assertEqual(a['inv_freq_dtype'],'torch.float32');self.assertEqual(a['backend'],'eager')
            self.assertEqual(a['library_accumulation'],'UNVERIFIED')
            self.assertEqual(a['cache'][-1]['length'],5)

    def test_hash_rejection_before_source_execution(self):
        with tempfile.TemporaryDirectory(dir=BUILD) as d:
            p=Path(d)/'wrong.py';p.write_text('raise AssertionError("must not execute")\n')
            with self.assertRaisesRegex(ValueError,'SHA256'):load_official(p)

    def test_observation_does_not_change_results(self):
        j=fixture();a=run_reference(j);b=run_reference(j,observe=False);c=run_reference(j)
        np.testing.assert_array_equal(a['output'],b['output']);np.testing.assert_array_equal(a['output'],c['output'])
        self.assertEqual(a['arrays'],c['arrays'])
        self.assertEqual(a['cache'],b['cache'])

    def test_cached_decode_and_chunks_observation(self):
        j=fixture(length=5);j['origin']=7;j['chunks']=[2,2,1]
        for partition in ['prefill','decode','chunks']:
            a=run_reference(j,partition=partition);self.save('cache-'+partition,j,a)
            self.assertEqual(a['cache'][-1]['length'],5)
            self.assertTrue(all(c['dtype_k']==c['dtype_v']=='torch.bfloat16' for c in a['cache']))
            # Self-tests check dtype/state structure only; cross-partition numeric
            # differences are observations until the comparison budget is frozen.
            expected=[5] if partition=='prefill' else [1,2,3,4,5] if partition=='decode' else [2,4,5]
            self.assertEqual([c['length'] for c in a['cache']],expected)

    def test_real_head_width_and_rope_generation(self):
        j=fixture(seed=1807,length=3,dim=256,rotary=64,hidden=2048,qh=16,kh=2)
        a=run_reference(j);self.save('real-head-shape',j,a)
        self.assertTrue(REQUIRED<={n['node'] for n in a['nodes']})
        self.assertEqual(a['inv_freq_dtype'],'torch.float32')
        self.assertEqual(len(a['inv_freq']),32)
        self.assertTrue(np.isfinite(np.asarray(a['output'])).all())

    def test_reference_only_boundary_calibration(self):
        for length,dim,rotary in [(1,6,2),(3,6,2),(63,8,4),(64,8,4),(65,8,4)]:
            j=fixture(seed=521,length=length,dim=dim,rotary=rotary)
            a=run_reference(j);self.save(f'calibration-t{length}-d{dim}',j,a)
            self.assertTrue(REQUIRED<={n['node'] for n in a['nodes']})
            self.assertTrue(np.isfinite(np.asarray(a['output'])).all())
        # Held-out identifier is fixed; this is oracle self-test, never fitting a native budget.
        j=fixture(seed=7319);a=run_reference(j);self.save('heldout7319',j,a)
        self.assertTrue(REQUIRED<={n['node'] for n in a['nodes']})

    @classmethod
    def tearDownClass(cls):
        (BUILD/'self-test-summary.json').write_text(json.dumps(cls.results,indent=2)+'\n')

if __name__=='__main__':unittest.main(verbosity=2)
