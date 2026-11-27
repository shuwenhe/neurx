"""Actual GPU sanitizer controls: clean kernel and deliberate device errors."""
import subprocess
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BUILD=ROOT/'artifact/build/qwen35_p0_20261127'
class SanitizerP0(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        BUILD.mkdir(parents=True,exist_ok=True)
        command=['nvcc','-std=c++17','-O2','-lineinfo','-U_FORTIFY_SOURCE','-D_FORTIFY_SOURCE=0',
                 '-arch=sm_89',str(ROOT/'test/native-construction/cuda_sanitizer_minimal.cu'),'-o',str(BUILD/'minimal')]
        p=subprocess.run(command,capture_output=True,text=True,timeout=120)
        (BUILD/'minimal-build-final.log').write_text(' '.join(command)+'\n'+p.stdout+p.stderr)
        if p.returncode:raise AssertionError(p.stdout+p.stderr)

    def run_tool(self,tool,mode=''):
        command=['python3',str(ROOT/'scripts/run_cuda_sanitizer.py'),'--tool',tool,'--',str(BUILD/'minimal')]
        if mode:command.append(mode)
        p=subprocess.run(command,capture_output=True,text=True,timeout=60)
        (BUILD/f'control-{tool}-{mode or "clean"}.log').write_text(p.stdout+p.stderr)
        return p
    def test_memcheck_clean(self):
        p=self.run_tool('memcheck');self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertIn('CUDA_MINIMAL_PASS',p.stdout);self.assertIn('ERROR SUMMARY: 0 errors',p.stdout+p.stderr)
    def test_initcheck_clean(self):
        p=self.run_tool('initcheck');self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertIn('CUDA_MINIMAL_PASS',p.stdout);self.assertIn('ERROR SUMMARY: 0 errors',p.stdout+p.stderr)
    def test_memcheck_detects_out_of_bounds(self):
        p=self.run_tool('memcheck','--oob');self.assertEqual(p.returncode,99,p.stdout+p.stderr)
        self.assertIn('Invalid __global__ write',p.stdout+p.stderr)
    def test_initcheck_detects_uninitialized_read(self):
        p=self.run_tool('initcheck','--uninitialized');self.assertEqual(p.returncode,99,p.stdout+p.stderr)
        self.assertIn('Uninitialized __global__ memory read',p.stdout+p.stderr)
if __name__=='__main__':unittest.main(verbosity=2)
