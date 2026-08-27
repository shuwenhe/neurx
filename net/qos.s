package neurx.net.qos

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.spinlock

enum qos_policy {
    fifo,
    priority_queue,
    round_robin,
    weighted_fair_queuing,
    leaky_bucket,
    token_bucket,
}

enum traffic_class {
    tc_best_effort,
    tc_interactive,
    tc_video,
    tc_voice,
    tc_critical,
}

struct qos_class {
    class_id: u32,
    traffic_class: traffic_class,
    priority: u8,
    bandwidth_limit: u64,
    burst_size: u64,
    current_tokens: u64,
    packets_queued: u32,
    bytes_queued: u64,
    policy: qos_policy,
}

struct qos_queue {
    queue_id: u32,
    packets: packet_info[],
    max_packets: u32,
    bytes_total: u64,
    max_bytes: u64,
    drop_count: u64,
}

struct packet_info {
    data: u8[],
    priority: u8,
    timestamp: u64,
    src_ip: u32,
    dst_ip: u32,
}

struct qos_engine {
    classes: qos_class[],
    queues: qos_queue[],
    active_policy: qos_policy,
    lock: spinlock::spinlock[void],
    tick_interval: u32,
}

func new_qos_engine(policy: qos_policy) (*qos_engine, string) {
    engine := *qos_engine{
        classes: qos_class[](),
        queues: qos_queue[](),
        active_policy: policy,
        lock: spinlock::new(),
        tick_interval: 1000,
    } as *qos_engine

return     (engine, "")
}

func (qos_engine* engine) create_qos_class(
    traffic_class: traffic_class,
    priority: u8,
    bandwidth_limit: u64,
) (u32, string) {
    _guard := engine.lock.lock()?

    class_id := len(engine.classes) as u32

    qos_class := qos_class{
        class_id: class_id,
        traffic_class: traffic_class,
        priority: priority,
        bandwidth_limit: bandwidth_limit,
        burst_size: bandwidth_limit * 2,
        current_tokens: bandwidth_limit,
        packets_queued: 0,
        bytes_queued: 0,
        policy: engine.active_policy,
    }

    engine.classes = append(engine.classes, qos_class)

    queue := qos_queue{
        queue_id: class_id,
        packets: packet_info[](),
        max_packets: 1000,
        bytes_total: 0,
        max_bytes: 10000000,
        drop_count: 0,
    }

    engine.queues = append(engine.queues, queue)

return     (class_id, "")
}

func (qos_engine* engine) enqueue_packet(
    class_id: u32,
    packet: *packet_info,
) (void, string) {
    _guard := engine.lock.lock()?

    if (class_id as u32) >= len(engine.queues) as u32 {
        return ((), "invalid class id")
    }

    queue := *engine.queues.get(class_id) as *qos_queue

    if len(queue.packets) as u32 >= queue.max_packets {
        queue.drop_count = queue.drop_count + 1
        return ((), "queue full - packet dropped")
    }

    packet_size := len(packet.data) as u64
    if queue.bytes_total + packet_size > queue.max_bytes {
        queue.drop_count = queue.drop_count + 1
        return ((), "queue memory full - packet dropped")
    }

    queue.packets = append(queue.packets, packet)
    queue.bytes_total = queue.bytes_total + packet_size

    return (), ""
}

func (qos_engine* engine) dequeue_packet(class_id: u32) (option[packet_info), string] {
    _guard := engine.lock.lock()?

    if (class_id as u32) >= len(engine.queues) as u32 {
        return ((), "invalid class id")
    }

    queue := *engine.queues.get(class_id) as *qos_queue

    if len(queue.packets) == 0 {
        return option::none, ""
    }

    match engine.active_policy {
        qos_policy::fifo: {
            packet := queue.packets.get(0)
            queue.packets.remove(0)
            queue.bytes_total = queue.bytes_total - (len(packet.data) as u64)
            (option::some(packet, ""))
        },
        qos_policy::priority_queue: {
            max_priority := 0
            max_idx := 0
            i := 0

            for pkt in queue.packets {
                if pkt.priority > max_priority {
                    max_priority = pkt.priority
                    max_idx = i
                }
                i = i + 1
            }

            packet := queue.packets.get(max_idx)
            queue.packets.remove(max_idx)
            queue.bytes_total = queue.bytes_total - (len(packet.data) as u64)
            (option::some(packet, ""))
        },
        _: (option::none, ""),
    }
}

func (qos_engine* engine) update_bandwidth_limit(
    class_id: u32,
    new_limit: u64,
) (void, string) {
    _guard := engine.lock.lock()?

    if (class_id as u32) >= len(engine.classes) as u32 {
        return ((), "invalid class id")
    }

    qos_class := *engine.classes.get(class_id) as *qos_class
    qos_class.bandwidth_limit = new_limit
    qos_class.burst_size = new_limit * 2

    return (), ""
}

func (qos_engine* engine) token_bucket_refill() (void, string) {
    _guard := engine.lock.lock()?

    for class in engine.classes {
        tokens_to_add := class.bandwidth_limit / 1000
        new_tokens := class.current_tokens + tokens_to_add

        if new_tokens > class.burst_size {
            class.current_tokens = class.burst_size
        } else {
            class.current_tokens = new_tokens
        }
    }

    return (), ""
}

func (qos_engine* engine) check_bandwidth_available(
    class_id: u32,
    bytes_needed: u64,
) (bool, string) {
    _guard := engine.lock.lock()?

    if (class_id as u32) >= len(engine.classes) as u32 {
        return ((), "invalid class id")
    }

    qos_class := *engine.classes.get(class_id) as *qos_class

return     (qos_class.current_tokens >= bytes_needed, "")
}

func (qos_engine* engine) consume_tokens(
    class_id: u32,
    bytes_used: u64,
) (void, string) {
    _guard := engine.lock.lock()?

    if (class_id as u32) >= len(engine.classes) as u32 {
        return ((), "invalid class id")
    }

    qos_class := *engine.classes.get(class_id) as *qos_class

    if qos_class.current_tokens < bytes_used {
        return ((), "insufficient tokens")
    }

    qos_class.current_tokens = qos_class.current_tokens - bytes_used

    return (), ""
}

struct qos_statistics {
    total_classes: u32,
    total_packets_queued: u64,
    total_packets_dropped: u64,
    total_bytes_queued: u64,
    avg_queue_depth: f32,
    class_utilization: class_stats[],
}

struct class_stats {
    class_id: u32,
    packets_queued: u32,
    bytes_queued: u64,
    drop_rate: f32,
}

func (qos_engine* engine) get_statistics() (qos_statistics, string) {
    _guard := engine.lock.lock()?

    total_packets := 0
    total_dropped := 0
    total_bytes := 0
    class_stats_vec := class_stats[]()

    for queue in engine.queues {
        total_packets = total_packets + (len(queue.packets) as u64)
        total_dropped = total_dropped + queue.drop_count
        total_bytes = total_bytes + queue.bytes_total

        stats := class_stats{
            class_id: queue.queue_id,
            packets_queued: len(queue.packets) as u32,
            bytes_queued: queue.bytes_total,
            drop_rate: 0.0,
        }

        class_stats_vec = append(class_stats_vec, stats)
    }

    avg_depth := if len(engine.queues) > 0 {
        (total_packets as f32) / (len(engine.queues) as f32)
    } else {
        0.0
    }

    qos_stats := qos_statistics{
        total_classes: len(engine.classes) as u32,
        total_packets_queued: total_packets,
        total_packets_dropped: total_dropped,
        total_bytes_queued: total_bytes,
        avg_queue_depth: avg_depth,
        class_utilization: class_stats_vec,
    }

return     (qos_stats, "")
}

func (qos_engine* engine) set_policy(policy: qos_policy) (void, string) {
    _guard := engine.lock.lock()?

    engine.active_policy = policy

    for class in engine.classes {
        class.policy = policy
    }

    return (), ""
}

func (qos_engine* engine) prioritize_class(
    class_id: u32,
    new_priority: u8,
) (void, string) {
    _guard := engine.lock.lock()?

    if (class_id as u32) >= len(engine.classes) as u32 {
        return ((), "invalid class id")
    }

    qos_class := *engine.classes.get(class_id) as *qos_class
    qos_class.priority = new_priority

    return (), ""
}
