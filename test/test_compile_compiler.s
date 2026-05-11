package neurx.test_compile_compiler

use neurx.compile.compiler.{compile_options, compiled_module_state, compile_result, new_compile_options, compile_module, compiled_module_execute, compiled_module_state_dict, compiled_module_load_state_dict}

func main() int {
    compile_options options = new_compile_options()
    compile_result out = compile_module("demo", options)
    if !out.ok {
        println("compile_module default failed")
        return 1
    }
    if out.state.module_name != "demo" {
        println("module_name mismatch")
        return 1
    }

    compile_options bad = options
    bad.backend = "bad"
    compile_result fail = compile_module("demo", bad)
    if fail.ok {
        println("bad backend should fail")
        return 1
    }

    compiled_module_state executed = compiled_module_execute(out.state)
    if !executed.executed {
        println("execute flag not set")
        return 1
    }

    compiled_module_state snapshot = compiled_module_state_dict(executed)
    compiled_module_state restored = compiled_module_load_state_dict(out.state, snapshot)
    if !restored.executed {
        println("state_dict restore failed")
        return 1
    }

    println("compile compiler test passed")
    0
}