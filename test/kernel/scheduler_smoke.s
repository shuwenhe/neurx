package test.kernel

use kernel.scheduler

func main() int {
    init_scheduler()
    add_task(1, 10)
    add_task(2, 5)
    schedule()
    0
}
