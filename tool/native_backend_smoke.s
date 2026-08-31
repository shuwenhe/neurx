package main

use neurx.compile.compiler.{compile_options, new_compile_options, compile_module}
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    string module_name = runtime_env_get("NEURX_NATIVE_SMOKE_MODULE", "native_smoke")
    compile_options options = new_compile_options()
    options.backend = "native"
    options.mode = "default"
    options.fullgraph = false
    options.dynamic = false
    options.debug = false
    compile_result result = compile_module(module_name, options)
    if !result.ok {
        println("native compile failed")
        return 1
    }
    string native_ir_dir = runtime_env_get("NEURX_NATIVE_IR_DIR", "./build/native-ir")
    string native_object_dir = runtime_env_get("NEURX_NATIVE_OBJECT_DIR", "./build/native-object")
    string object_path = native_object_dir + "/" + module_name + ".o"
    string executable_path = native_object_dir + "/" + module_name
    string ir_path = native_ir_dir + "/" + module_name + ".native.ir"
    if !runtime_file_exists(ir_path) {
        println("missing native ir: " + ir_path)
        return 2
    }
    if !runtime_file_exists(object_path) {
        println("missing object file: " + object_path)
        return 3
    }
    if !runtime_file_exists(executable_path) {
        println("missing executable: " + executable_path)
        return 4
    }
    println("native backend smoke ok")
    0
}
