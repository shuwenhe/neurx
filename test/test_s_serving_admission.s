package neurx.test_serving_admission

use neurx.serving.serve

func main() int {
    admission_control_state a = new_admission_control_state_with_policy(2, 128, "srpt")
    if !admission_can_enqueue(a, 0, 10) {
        println("admission_can_enqueue failed")
        1
    }
    a = admission_on_enqueue(a, 10, true)
    if a.admitted != 1 {
        println("admission_on_enqueue increment failed")
        1
    }
    a = admission_on_enqueue(a, 20, false)
    if a.rejected != 1 {
        println("admission_on_enqueue rejected failed")
        1
    }
    if !admission_should_preempt(a, 10, 5) {
        println("admission_should_preempt logic failed")
        1
    }
    println("serving admission test passed")
    0
}
