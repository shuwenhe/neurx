import importlib.util
from pathlib import Path
import subprocess
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('normalize_arrays',ROOT/'tool/normalize_s_arrays.py')
migration=importlib.util.module_from_spec(spec);spec.loader.exec_module(migration)
class ArraySyntax(unittest.TestCase):
    def test_fields_parameters_returns_and_constructors(self):
        old='struct R { []float values; []int ids }\nfunc f([]float x) []float { []float y = make([]float, 2); return []float{1.0, 2.0} }'
        new='struct R { float[] values; int[] ids }\nfunc f(float[] x) float[] { float[] y = make(float[], 2); return float[]{1.0, 2.0} }'
        self.assertEqual(migration.normalize(old),new)
    def test_dimensions_maps_generics_and_pointer_elements(self):
        old='[][]float a; []float[] b; [2][3]int c; []map[string][]float d; []pkg.Pair[string, int] e; []*Node f; [][2]interface{} g'
        new='float[][] a; float[][] b; int[3][2] c; (map[string]float[])[] d; pkg.Pair[string, int][] e; Node*[] f; interface{}[2][] g'
        self.assertEqual(migration.normalize(old),new)
    def test_does_not_change_literals_comments_or_indexing(self):
        text='string x = "[]float"; string raw = `[]int`; // []float\n/* []string */\nint[] xs = int[]{1,2}; x = xs[0]; x = xs[i] * factor; xs[1]\nnext()\n'
        self.assertEqual(migration.normalize(text),text)
    def test_existing_postfix_types_remain_unchanged(self):
        text='float[][] x; int[256] tokens; pkg.Node*[] nodes; interface{}[] items; make(float[][], n); map[string]float[] y'
        self.assertEqual(migration.normalize(text),text)
    def test_comments_inside_type_are_preserved(self):
        self.assertEqual(migration.normalize('[] /* retained */ float values'), ' /* retained */ float[] values')
        self.assertEqual(migration.normalize('[/* retained */]int values'), 'int[/* retained */] values')
    def test_old_mangled_make_preserves_rank(self):
        self.assertEqual(migration.normalize('[]float[] x = floatmake([][], rows); []int[][] y = intmake([][][], n)'), 'float[][] x = make(float[][], rows); int[][][] y = make(int[][][], n)')
    def test_recovers_after_unterminated_regular_string(self):
        self.assertEqual(migration.normalize('string url = "https:\n[]float data'), 'string url = "https:\nfloat[] data')
        self.assertEqual(migration.normalize('string code = `\n[]float data\n`'), 'string code = `\n[]float data\n`')
    def test_repairs_split_declared_type_and_function_signature(self):
        self.assertEqual(migration.normalize('struct tracepoint {}\ntracepo[]int points'), 'struct tracepoint {}\ntracepoint[] points')
        self.assertEqual(migration.normalize('func dot[]float x) []float { return x }'), 'func dot(float[] x) float[] { return x }')
    def test_pointer_to_array_keeps_pointer_and_array_separate(self):
        self.assertEqual(migration.normalize('struct R { *[]float values }'), 'struct R { *float[] values }')
    def test_array_after_newline_and_mangled_parameter_map(self):
        self.assertEqual(migration.normalize('new string\n[][]float x'), 'new string\nfloat[][] x')
        self.assertEqual(migration.normalize('get_betas() . [2]f64'), 'get_betas() . f64[2]')
        self.assertEqual(migration.normalize('func f(vector[] float) float { return 0.0 }'), 'func f(float[] vector) float { return 0.0 }')
        self.assertEqual(migration.normalize('bundles map[string[]float64]'), 'bundles (map[string]float64)[]')
        self.assertEqual(migration.normalize('return[] string []string{0 cap}'), 'return string[] string[]{0 cap}')
        self.assertEqual(migration.normalize('string[] patterns = if[] intent'), 'string[] patterns = if intent')
    def test_canonical_generic_map_arrays_do_not_consume_field_names(self):
        self.assertEqual(migration.normalize('map[string,float][] attrs'), 'map[string,float][] attrs')
        self.assertEqual(migration.normalize('[]map[string,float] attrs'), 'map[string,float][] attrs')
    def test_project_has_no_legacy_array_types(self):
        result=subprocess.run(['git','ls-files','-z','--cached','--others','--exclude-standard','--','*.s'],cwd=ROOT,capture_output=True,check=True)
        failures=[]
        for name in set(result.stdout.decode().split('\0')):
            if not name or name.startswith(('artifact/','artifacts/')):continue
            p=ROOT/name
            if not p.is_file() or p.is_symlink():continue
            source=p.read_text()
            if migration.normalize(source)!=source:failures.append(name)
        self.assertEqual(len(failures),0, str(len(failures))+' files still use noncanonical arrays: '+', '.join(sorted(failures)[:12]))
if __name__=='__main__':unittest.main()
