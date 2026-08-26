package neurx.kernel.perf

use std.vec.vec

struct perf_event {
    int event_id
    string event_name
    int cpu_id
    int count
    int sample_period
}

struct perf_counter {
    vec[perf_event] events
    int enabled
    int timestamp
}

struct perf_stat {
    int cycles
    int instructions
    int cache_misses
    int branch_misses
    int context_switches
}

func create_perf_counter() perf_counter {
    counter := perf_counter {
        events: vec[perf_event](),
        enabled: 0,
        timestamp: 0
    }
    counter
}

func perf_add_event(perf_counter counter, string event_name, int cpu_id) perf_counter {
    event := perf_event {
        event_id: 0,
        event_name: event_name,
        cpu_id: cpu_id,
        count: 0,
        sample_period: 0
    }
    counter.events.push(event)
    counter
}

func perf_enable(perf_counter counter) perf_counter {
    counter.enabled = 1
    counter
}

func perf_disable(perf_counter counter) perf_counter {
    counter.enabled = 0
    counter
}

func perf_get_cycles(perf_counter counter) int {
    0
}

func perf_get_instructions(perf_counter counter) int {
    0
}

func perf_get_cache_misses(perf_counter counter) int {
    0
}

func create_perf_stat() perf_stat {
    stat := perf_stat {
        cycles: 0,
        instructions: 0,
        cache_misses: 0,
        branch_misses: 0,
        context_switches: 0
    }
    stat
}
