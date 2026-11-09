"""Check native cluster source semantics and command configuration contracts."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
S_ROOT = Path(os.environ.get('S_REPO_ROOT', ROOT.parent / 's'))
EXTENDED = S_ROOT / '.bootstrap/neurx-extension/compiler-final'
COMPILER = Path(os.environ.get('S_NATIVE_COMPILER', EXTENDED if EXTENDED.is_file() else S_ROOT / '.bootstrap/native-imports/stage4'))


class NativeCluster(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.output = Path(cls.temporary.name)
        result = subprocess.run(['python3', str(ROOT / 'tool/build_native.py'), '--compiler', str(COMPILER),
                                 '--s-root', str(S_ROOT), '--commands', 'worker', 'controller',
                                 '--output-dir', str(cls.output)], capture_output=True, text=True, timeout=120)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    def test_worker_rejects_missing_configuration(self):
        result = subprocess.run([str(self.output / 'worker')], env={}, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('must be valid', result.stdout)

    def test_worker_preserves_rank_and_child_exit(self):
        child = self.output / "worker ' fixture"
        child.write_text('#!/bin/sh\n[ "$WORLD_SIZE:$RANK:$LOCAL_RANK:$MASTER_ADDR" = "1:0:0:127.0.0.1" ] || exit 99\nprintf child-ran\nexit 23\n')
        child.chmod(0o755)
        environment = {k: v for k, v in os.environ.items() if not k.startswith('NEURX_')}
        environment.update(NEURX_WORKER_BIN=str(child), MASTER_ADDR='127.0.0.1', WORLD_SIZE='1',
                           RANK='0', LOCAL_RANK='0', NEURX_HEARTBEAT_DIR=str(self.output / 'heartbeat'))
        result = subprocess.run([str(self.output / 'worker')], env=environment, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertIn('child-ran', result.stdout)

    def test_collection_builders_do_not_insert_default_entries(self):
        source = self.output / 'collections.s'
        source.write_text('''package main
import ("neurx.deployment.cluster_orchestration"; "neurx.distributed.cluster.parallel_plan")
func main() int {
    local := cluster_discover_local_fallback()
    if len(local) != 1 || local[0].node_name != "localhost" { return 1 }
    node := cluster_parse_node_record("node-x|127.0.0.1|2|H100|16|64|healthy|0.25")
    if node.node_name != "node-x" || node.ip_address != "127.0.0.1" || node.gpu_count != 2 { return 2 }
    topology := cluster_parallel_normalize(2, 1, 1, 2)
    stages := cluster_parallel_build_stages(topology, 8)
    ranks := cluster_parallel_build_ranks(topology)
    if len(stages) != 1 || len(ranks) != 2 { return 3 }
    if ranks[0].global_rank != 0 || ranks[1].global_rank != 1 { return 4 }
    return 0
}
''')
        sources = (self.output / 'worker.sources').read_text().splitlines()[1:]
        assembly = self.output / 'collections.sasm'
        result = subprocess.run([str(COMPILER), '--compile-unit', str(assembly), str(source), *sources], capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        executable = self.output / 'collections'
        result = subprocess.run([str(COMPILER), '--emit-bin', str(assembly), str(executable)], capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
