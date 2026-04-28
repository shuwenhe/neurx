package neurx.test_schedule

use neurx.schedule.{op, run}

func main() int {
    let op_item = op { name: "add" }
    run(op_item)
    println("调度器执行完成")
    0
}
