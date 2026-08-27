package neurx.backend.platform.robot

use std.slices
use std.io.println

struct realtime_task {
    string name
    func() int callback
    int period_us
    int priority
    bool enabled
}

struct realtime_scheduler {
    []realtime_task tasks
    int cycle_period_us
    int max_latency_us
    int current_cycle
    bool running
}

func new_realtime_scheduler(int hz) realtime_scheduler {
    int period_us = 1000000 / hz
    return realtime_scheduler{
        tasks: realtime_task[](),
        cycle_period_us: period_us,
        max_latency_us: period_us / 2,
        current_cycle: 0,
        running: false,
    }
}

func (realtime_scheduler* scheduler) register_task(string name, func() int callback, int period_us, int priority) {
    task := realtime_task{
        name: name,
        callback: callback,
        period_us: period_us,
        priority: priority,
        enabled: true,
    }
    scheduler.tasks = append(scheduler.tasks, task)
}

func (realtime_scheduler* scheduler) enable_task(string name) {
    for i in len(0..scheduler.tasks) {
        if scheduler.tasks[i].name == name {
            scheduler.tasks[i].enabled = true
            return
        }
    }
}

func (realtime_scheduler* scheduler) disable_task(string name) {
    for i in len(0..scheduler.tasks) {
        if scheduler.tasks[i].name == name {
            scheduler.tasks[i].enabled = false
            return
        }
    }
}

func (realtime_scheduler* scheduler) get_task_count() int {    len(scheduler.tasks)
}

func (realtime_scheduler* scheduler) get_cycle_period_us() int {    scheduler.cycle_period_us
}

func (realtime_scheduler* scheduler) get_max_latency_us() int {    scheduler.max_latency_us
}

func (realtime_scheduler* scheduler) get_current_cycle() int {    scheduler.current_cycle
}

func (realtime_scheduler* scheduler) is_running() bool {    scheduler.running
}
