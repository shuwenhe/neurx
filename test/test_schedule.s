package neurx.test_schedule

use neurx.schedule.{Op, run}

func main() int32 {
    let op = Op { name: "add" }
    run(op)
    println("调度器执行完成")
    0
}
