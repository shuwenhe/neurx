"""Exercise the native serving command with finite CPU model fixtures."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
S_ROOT = Path(os.environ.get('S_REPO_ROOT', ROOT.parent / 's'))
EXTENDED = S_ROOT / '.bootstrap/neurx-extension/compiler-final'
COMPILER = Path(os.environ.get('S_NATIVE_COMPILER', EXTENDED if EXTENDED.is_file() else S_ROOT / '.bootstrap/native-imports/stage4'))


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

    def test_hf_forward_returns_updated_cache_for_next_token(self):
        probe = self.folder / 'cache_probe.s'
        probe.write_text('''package main
import ("neurx.backends.cpu.transformer_decode"; "neurx.models.loaders.hf_transformer")
func main() int {
    model := load_hf_model("MODEL_PATH")
    if !model.valid { return 1 }
    if model.config.rms_epsilon < 0.000009 || model.config.rms_epsilon > 0.000011 { return 12 }
    keys := make(float[], 8)
    values := make(float[], 8)
    first := hf_forward_token(model, 1, keys, values, 4, 0)
    if !first.ok { return 2 }
    if first.cache.length != 1 || len(first.cache.keys) != 8 { return 3 }
    if first.cache.values[1] < 1.0 { return 4 }
    second := hf_forward_token(model, 2, first.cache.keys, first.cache.values, 4, 1)
    if !second.ok { return 5 }
    if second.cache.length != 2 { return 6 }
    if second.cache.values[1] != first.cache.values[1] { return 7 }
    if second.cache.values[2] < 0.9 || second.cache.values[3] < 0.9 { return 8 }
    if second.hidden[1] <= second.hidden[0] { return 9 }
    model.lm_head = make(float[], 14)
    model.lm_head[0] = 1.0
    model.lm_head[3] = 1.0
    generated := hf_generate(model, int[]{1, 2}, 2)
    if !generated.ok || len(generated.token_ids) != 2 { return 10 }
    if generated.token_ids[0] != 1 || generated.token_ids[1] != 1 { return 11 }
    return 0
}
'''.replace('MODEL_PATH', str(self.model)))
        sources = (self.output / 'serve.sources').read_text().splitlines()
        sources = [source for source in sources if Path(source) != ROOT / 'cmd/serve/main.s']
        assembly = self.folder / 'cache_probe.sasm'
        result = subprocess.run([str(COMPILER), '--compile-unit', str(assembly), str(probe), *sources],
                                capture_output=True, text=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        executable = self.folder / 'cache_probe'
        result = subprocess.run([str(COMPILER), '--emit-bin', str(assembly), str(executable)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

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
