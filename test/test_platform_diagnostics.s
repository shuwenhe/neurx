package neurx.test_platform_diagnostics

use neurx.platform.diagnostics.{runtime_info_state, check_result, runtime_info, doctor, format_doctor_report}

func main() int {
    runtime_info_state info = runtime_info()
    if info.default_device == "" {
        println("runtime_info default_device missing")
        return 1
    }

    []check_result checks = doctor(false, false)
    if len(checks) < 5 {
        println("doctor check count too small")
        return 1
    }

    string report = format_doctor_report(checks)
    if len(report) == 0 {
        println("doctor report empty")
        return 1
    }

    println("platform diagnostics test passed")
    0
}