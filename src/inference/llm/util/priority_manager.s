package inference


    p0_critical
    p1_high
    p2_normal
    p3_low
    p4_background
}

struct priority_entry {
    string request_id
    priority_level level
    int64 priority_score
    int64 submission_time
    int64 deadline
    float sla_multiplier
}

struct sla_config {
    priority_level priority
    int64 max_latency_ms
    int32 throughput_threshold
    float priority_boost
}

struct priority_queue_stats {
    int32 critical_count
    int32 high_count
    int32 normal_count
    int32 low_count
    int32 background_count
    float avg_wait_time
    int64 total_priority_points
}

struct priority_manager {
    vec[priority_entry] queue
    map[string, priority_level] request_priority_map
    vec[sla_config] sla_configs
    int64 current_time
    bool enable_priority_preemption
    bool enable_sla_enforcement
    int32 max_queue_size
}

func new_priority_manager(int32 max_queue_size) priority_manager {
    configs := vec[sla_config]{}

    p0_config := sla_config {
        priority: priority_level::p0_critical,
        max_latency_ms: 100,
        throughput_threshold: 100,
        priority_boost: 10.0,
    }
    configs.push(p0_config)

    p1_config := sla_config {
        priority: priority_level::p1_high,
        max_latency_ms: 500,
        throughput_threshold: 50,
        priority_boost: 5.0,
    }
    configs.push(p1_config)

    p2_config := sla_config {
        priority: priority_level::p2_normal,
        max_latency_ms: 2000,
        throughput_threshold: 20,
        priority_boost: 1.0,
    }
    configs.push(p2_config)

    p3_config := sla_config {
        priority: priority_level::p3_low,
        max_latency_ms: 5000,
        throughput_threshold: 10,
        priority_boost: 0.5,
    }
    configs.push(p3_config)

    p4_config := sla_config {
        priority: priority_level::p4_background,
        max_latency_ms: 10000,
        throughput_threshold: 5,
        priority_boost: 0.1,
    }
    configs.push(p4_config)

    priority_manager {
        queue: vec[priority_entry]{},
        request_priority_map: map[string, priority_level]{},
        sla_configs: configs,
        current_time: 0,
        enable_priority_preemption: true,
        enable_sla_enforcement: true,
        max_queue_size: max_queue_size,
    }
}

func (priority_manager* pm) add_request(string request_id, priority_level level, int64 deadline) bool {
    if pm.queue.len() >= pm.max_queue_size {
        false
    }

    priority_score := calculate_priority_score(level, 0, deadline)

    entry := priority_entry {
        request_id: request_id,
        level: level,
        priority_score: priority_score,
        submission_time: pm.current_time,
        deadline: deadline,
        sla_multiplier: get_sla_multiplier(pm.sla_configs, level),
    }

    pm.queue.push(entry)
    pm.request_priority_map[request_id] = level

    insert_by_priority(pm.queue, entry)
    true
}

func calculate_priority_score(priority_level level, int64 wait_time, int64 deadline) int64 {
    base_score := 0

    if level == priority_level::p0_critical {
        base_score = 1000
    } else if level == priority_level::p1_high {
        base_score = 800
    } else if level == priority_level::p2_normal {
        base_score = 500
    } else if level == priority_level::p3_low {
        base_score = 300
    } else {
        base_score = 100
    }

    int64(base_score) + (wait_time / 10)
}

func get_sla_multiplier(vec[sla_config] configs, priority_level level) float {
    for config in configs {
        if config.priority == level {
            config.priority_boost
        }
    }

    1.0
}

func insert_by_priority(vec[priority_entry]* queue, priority_entry new_entry) {
    insert_idx := queue.len()

    for i in 0..queue.len() {
        if queue[i].priority_score < new_entry.priority_score {
            insert_idx = i
        }
    }
}

func (priority_manager* pm) get_next_request() priority_entry {
    if pm.queue.len() > 0 {
        result := pm.queue[0]
        pm.queue = priority_entry_vec_remove_at(pm.queue, 0)
        result
    }

    priority_entry {
        request_id: "",
        level: priority_level::p4_background,
        priority_score: 0,
        submission_time: 0,
        deadline: 0,
        sla_multiplier: 0.0,
    }
}

func priority_entry_vec_remove_at(vec[priority_entry] v, int32 idx) vec[priority_entry] {
    result := vec[priority_entry]{}
    for i in 0..v.len() {
        if i != idx {
            result.push(v[i])
        }
    }
    result
}

func (priority_manager* pm) update_request_priority(string request_id, priority_level new_level) bool {
    if !(request_id in pm.request_priority_map) {
        false
    }

    for i in 0..pm.queue.len() {
        if pm.queue[i].request_id == request_id {
            old_level := pm.queue[i].level
            pm.queue[i].level = new_level
            pm.queue[i].priority_score = calculate_priority_score(new_level, pm.current_time - pm.queue[i].submission_time, pm.queue[i].deadline)

            if old_level != new_level {
                pm.request_priority_map[request_id] = new_level
            }

            true
        }
    }

    false
}

func (priority_manager* pm) remove_request(string request_id) bool {
    idx := -1
    for i in 0..pm.queue.len() {
        if pm.queue[i].request_id == request_id {
            idx = i
        }
    }

    if idx >= 0 {
        pm.queue = priority_entry_vec_remove_at(pm.queue, idx)
        delete(pm.request_priority_map, request_id)
        true
    } else {
        false
    }
}

func (priority_manager* pm) get_queue_stats() priority_queue_stats {
    critical_cnt := 0
    high_cnt := 0
    normal_cnt := 0
    low_cnt := 0
    bg_cnt := 0
    total_priority := 0

    for entry in pm.queue {
        if entry.level == priority_level::p0_critical {
            critical_cnt = critical_cnt + 1
        } else if entry.level == priority_level::p1_high {
            high_cnt = high_cnt + 1
        } else if entry.level == priority_level::p2_normal {
            normal_cnt = normal_cnt + 1
        } else if entry.level == priority_level::p3_low {
            low_cnt = low_cnt + 1
        } else {
            bg_cnt = bg_cnt + 1
        }

        total_priority = total_priority + entry.priority_score
    }

    avg_wait := 0.0
    if pm.queue.len() > 0 {
        total_wait := 0
        for entry in pm.queue {
            total_wait = total_wait + (pm.current_time - entry.submission_time)
        }
        avg_wait = float(total_wait) / float(pm.queue.len())
    }

    priority_queue_stats {
        critical_count: critical_cnt,
        high_count: high_cnt,
        normal_count: normal_cnt,
        low_count: low_cnt,
        background_count: bg_cnt,
        avg_wait_time: avg_wait,
        total_priority_points: int64(total_priority),
    }
}

func (priority_manager* pm) check_sla_violations() vec[string] {
    violations := vec[string]{}

    for entry in pm.queue {
        wait_time := pm.current_time - entry.submission_time

        for config in pm.sla_configs {
            if config.priority == entry.level {
                if wait_time > config.max_latency_ms {
                    violations.push(entry.request_id)
                }
            }
        }
    }

    violations
}

func (priority_manager* pm) boost_aging_requests() {
    for i in 0..pm.queue.len() {
        wait_time := pm.current_time - pm.queue[i].submission_time

        if wait_time > 1000 {
            old_priority := pm.queue[i].level

            if old_priority != priority_level::p0_critical {
                new_level := old_priority
                if old_priority == priority_level::p4_background {
                    new_level = priority_level::p3_low
                } else if old_priority == priority_level::p3_low {
                    new_level = priority_level::p2_normal
                } else if old_priority == priority_level::p2_normal {
                    new_level = priority_level::p1_high
                }

                pm.queue[i].level = new_level
                pm.queue[i].priority_score = calculate_priority_score(new_level, wait_time, pm.queue[i].deadline)
            }
        }
    }
}

func (priority_manager* pm) get_queue_size() int32 {
    pm.queue.len()
}

func (priority_manager* pm) is_queue_full() bool {
    pm.queue.len() >= pm.max_queue_size
}

func (priority_manager* pm) clear_queue() {
    pm.queue = vec[priority_entry]{}
    pm.request_priority_map = map[string, priority_level]{}
}

func (priority_manager* pm) update_current_time(int64 time_ms) {
    pm.current_time = time_ms
}
