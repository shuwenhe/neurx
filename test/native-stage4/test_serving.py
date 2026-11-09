"""Exercise the native serving command with finite CPU model fixtures."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
COMPILER = Path(os.environ.get('S_NATIVE_COMPILER', ROOT.parent / 's/.bootstrap/native-imports/stage4'))


class NativeServing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='neurx-serving-')
        cls.folder = Path(cls.temporary.name)
        cls.output = cls.folder / 'build'
        result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--compiler', str(COMPILER),
                                 '--commands', 'serve', '--output-dir', str(cls.output)],
                                capture_output=True, text=True, timeout=180)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        cls.model = cls.folder / 'hf'
        shutil.copytree(ROOT / 'test/fixture/hf_tiny', cls.model)
        (cls.model / 'model.safetensors').write_bytes(bytes.fromhex((cls.model / 'model.safetensors.hex').read_text()))
        cls.embedding = cls.folder / 'embedding.safetensors'
        cls.embedding.write_bytes(bytes.fromhex((ROOT / 'test/fixture/embedding.safetensors.hex').read_text()))

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def serve(self, model, prompt, count, route='native'):
        environment = {key: value for key, value in os.environ.items() if not key.startswith('NEURX_')}
        environment.update(NEURX_MODEL=str(model), NEURX_PROMPT=prompt, NEURX_MAX_TOKENS=str(count), NEURX_ROUTE=route)
        return subprocess.run([str(self.output / 'serve')], env=environment, capture_output=True, text=True, timeout=30)

    def test_reference_generates_requested_prefix(self):
        result = self.serve('reference-model', 'industrial', 5)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout, 'indus\n')

    def test_embedding_runs_cpu_prefill_and_decode(self):
        result = self.serve(self.embedding, 'AB', 2)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout, 'token:1\n')

    def test_hf_chat_runs_transformer_and_stops_at_eos(self):
        result = self.serve(self.model, 'Hi', 3, 'openai-chat')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        response = json.loads(result.stdout)
        self.assertEqual(response['object'], 'chat.completion')
        self.assertEqual(response['choices'][0]['message'], {'role': 'assistant', 'content': ''})
        self.assertEqual(response['choices'][0]['finish_reason'], 'stop')
        self.assertEqual(response['usage']['completion_tokens'], 1)


if __name__ == '__main__':
    unittest.main()
