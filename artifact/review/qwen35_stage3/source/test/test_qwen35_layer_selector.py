"""Real-model probe must select exactly a requested DeltaNet layer and fail closed."""
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT.parent / 'model/Qwen3.6-35B-A3B'
PROBE = Path(os.environ.get('QWEN35_STAGE3_PROBE', ROOT / 'artifact/build/qwen35_stage3/probe'))

class LayerSelector(unittest.TestCase):
    def run_layer(self, layer, nonzero=False):
        config = json.loads((MODEL / 'config.json').read_text())['text_config']
        data = dict(hidden=config['hidden_size'], kh=config['linear_num_key_heads'],
                    vh=config['linear_num_value_heads'], kd=config['linear_key_head_dim'],
                    vd=config['linear_value_head_dim'], conv=config['linear_conv_kernel_dim'],
                    eps=config['rms_norm_eps'], context=2, chunk=1, budget=256 << 20,
                    calls=[dict(x=([0.125 if i % 2 == 0 else -0.125 for i in range(config['hidden_size'])] if nonzero else [0.0] * config['hidden_size']), position=0)])
        process = subprocess.run([str(PROBE), '--model', str(MODEL), '--layer', str(layer)],
                                 input=json.dumps(data), capture_output=True, text=True, timeout=60)
        return process.returncode, json.loads(process.stdout)

    def test_select_linear_layer(self):
        code, result = self.run_layer(4)
        self.assertEqual(code, 0, result)
        self.assertEqual(result['layer'], 4)
        self.assertEqual(result['calls'][0]['length'], 1)

    def test_distinct_layers_use_distinct_weights(self):
        code0, layer0 = self.run_layer(0, nonzero=True)
        code4, layer4 = self.run_layer(4, nonzero=True)
        self.assertEqual((code0, code4), (0, 0))
        self.assertEqual((layer0['layer'], layer4['layer']), (0, 4))
        self.assertNotEqual(layer0['calls'][0]['output'], layer4['calls'][0]['output'])

    def test_reject_full_attention_and_out_of_range(self):
        for layer in (3, 40, -1):
            with self.subTest(layer=layer):
                code, result = self.run_layer(layer)
                self.assertNotEqual(code, 0)
                self.assertIn('layer', result['error'].lower())

if __name__ == '__main__':
    unittest.main()
