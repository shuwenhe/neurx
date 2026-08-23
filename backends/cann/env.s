package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    string ascend_home = runtime_env_get("ASCEND_HOME_PATH", "/usr/local/Ascend/ascend-toolkit/latest")
    if !runtime_file_exists(ascend_home) {
        println("Ascend toolkit not found: " + ascend_home)
        println("Set ASCEND_HOME_PATH before using backends/cann/env.s")
        return 1
    }
    println("export ASCEND_HOME_PATH=\"" + ascend_home + "\"")
    println("export PATH=\"" + ascend_home + "/bin:${PATH}\"")
    println("export PATH=\"" + ascend_home + "/compiler/ccec_compiler/bin:${PATH}\"")
    println("export LD_LIBRARY_PATH=\"" + ascend_home + "/lib64:${LD_LIBRARY_PATH}\"")
    println("export LD_LIBRARY_PATH=\"" + ascend_home + "/runtime/lib64:${LD_LIBRARY_PATH}\"")
    println("export LD_LIBRARY_PATH=\"" + ascend_home + "/compiler/lib64:${LD_LIBRARY_PATH}\"")
    println("export ASCEND_OPP_PATH=\"${ASCEND_OPP_PATH:-" + ascend_home + "/opp}\"")
    println("export ASCEND_AICPU_PATH=\"${ASCEND_AICPU_PATH:-" + ascend_home + "}\"")
    println("export ASCEND_SLOG_PRINT_TO_STDOUT=\"${ASCEND_SLOG_PRINT_TO_STDOUT:-0}\"")
    0
}
