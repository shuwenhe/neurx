"""Native I/O compatibility exercised through real generated machine code."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
S_ROOT = Path(os.environ.get('S_REPO_ROOT', ROOT.parent / 's'))
COMPILER = Path(os.environ.get('S_NATIVE_COMPILER', S_ROOT / '.bootstrap/native-imports/stage4'))


class NativeIO(unittest.TestCase):
    def test_files_environment_and_captured_process_output(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            source = directory / 'io_test.s'
            source.write_text('''package main
import ("neurx.runtime.io")
func main() int {
    path := neurx.runtime.io.runtime_env_get("NEURX_IO_TEST_PATH", "")
    if path == "" { return 1 }
    neurx.runtime.io.runtime_write_text_file(path, "first")
    neurx.runtime.io.runtime_append_text_file(path, " second")
    if neurx.runtime.io.runtime_read_text_file(path) != "first second" { return 2 }
    if !neurx.runtime.io.runtime_file_exists(path) { return 3 }
    if !neurx.runtime.io.runtime_env_has("NEURX_EMPTY_TEST") { return 4 }
    if neurx.runtime.io.runtime_env_has("NEURX_ABSENT_TEST") { return 5 }
    if neurx.runtime.io.runtime_run_command_output("printf captured") != "captured" { return 6 }
    if neurx.runtime.io.runtime_run_command_output("printf partial; exit 7") != "" { return 7 }
    return 0
}
''')
            assembly = directory / 'io.sasm'
            result = subprocess.run([str(COMPILER), '--compile-unit', str(assembly),
                                     str(ROOT / 'src/runtime/command/command.s'),
                                     str(ROOT / 'src/runtime/io/io.s'), str(source)], capture_output=True, text=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            executable = directory / 'io-test'
            result = subprocess.run([str(COMPILER), '--emit-bin', str(assembly), str(executable)], capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            environment = {k: v for k, v in os.environ.items() if k != 'NEURX_ABSENT_TEST'}
            environment.update(NEURX_IO_TEST_PATH=str(directory / "data ' quoted.txt"), NEURX_EMPTY_TEST='')
            result = subprocess.run([str(executable)], env=environment, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class NativeProtocol(unittest.TestCase):
    def test_json_uses_decimal_numbers_and_escaped_text(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            source = directory / 'protocol_test.s'
            source.write_text('''package main
import ("neurx.serving.protocol.openai_tgi")
func main() int {
    println(openai_error_json("quote\\\"\\nline", "fixture", 429))
    println(tgi_token_sse(65, "A", true))
    return 0
}
''')
            assembly = directory / 'protocol.sasm'
            result = subprocess.run([str(COMPILER), '--compile-unit', str(assembly),
                                     str(ROOT / 'src/serving/protocol/openai_tgi.s'), str(source)],
                                    capture_output=True, text=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            executable = directory / 'protocol'
            result = subprocess.run([str(COMPILER), '--emit-bin', str(assembly), str(executable)], capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            lines = result.stdout.splitlines()
            self.assertEqual(json.loads(lines[0]), {'error': {'message': 'quote"\nline', 'type': 'fixture', 'code': 429}})
            token = json.loads(lines[1].removeprefix('data: '))['token']
            self.assertEqual(token['id'], 65)
            self.assertEqual(token['text'], 'A')
            self.assertTrue(token['special'])
