package test_type_annotation_codegen

// Regression test for S compiler bug where typed variable declarations
// generate malformed ARG instructions with bare type names.
// 
// Bug: int[] bytes = __host_read_binary_file(...) generates:
//   ARG|int|_|_
//   ARG|_|_|_
//   CALL|t0|__index_get|2
// 
// Workaround: Use type inference: bytes := __host_read_binary_file(...)

extern "intrinsic" func __host_read_binary_file(string path) int[]

// Test 1: Typed declaration (BROKEN - triggers the bug)
func test_typed_array_declaration(string path) int[] {
    int[] bytes = __host_read_binary_file(path)
    bytes
}

// Test 2: Type inference (WORKING - avoids the bug)
func test_inferred_array_declaration(string path) int[] {
    bytes := __host_read_binary_file(path)
    bytes
}

// Test 3: Typed with primitive type (also broken)
func test_typed_int_declaration(string s) int {
    int value = len(s)
    value
}

// Test 4: Inferred with primitive type (working)
func test_inferred_int_declaration(string s) int {
    value := len(s)
    value
}

func main() {
    print("Testing type annotation code generation\n")
    
    // These will compile, but may fail at runtime if the bug is present
    arr1 := test_typed_array_declaration("/tmp/test1.bin")
    print("Typed array test done\n")
    
    arr2 := test_inferred_array_declaration("/tmp/test2.bin")
    print("Inferred array test done\n")
    
    val1 := test_typed_int_declaration("hello")
    print("Typed int test done\n")
    
    val2 := test_inferred_int_declaration("world")
    print("Inferred int test done\n")
}
