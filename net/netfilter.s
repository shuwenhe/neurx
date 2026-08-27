package neurx.net.netfilter

use std.vec.vec
use std.option.option
use std.result.result
use neurx.kernel.locking.spinlock

enum netfilter_hook_type {
    nf_inet_pre_routing,
    nf_inet_local_in,
    nf_inet_forward,
    nf_inet_local_out,
    nf_inet_post_routing,
}

enum packet_verdict {
    nf_drop,
    nf_accept,
    nf_stolen,
    nf_queue,
    nf_repeat,
}

struct netfilter_hook {
    hook_type: netfilter_hook_type,
    priority: i32,
    hook_fn: &fn(skb: &packet_buffer, hook: netfilter_hook_type) -> packet_verdict,
    module: &string,
    enabled: bool,
}

struct packet_buffer {
    data: vec[u8],
    src_ip: u32,
    dst_ip: u32,
    src_port: u16,
    dst_port: u16,
    protocol: u8,
    flags: u32,
}

struct firewall_rule {
    id: u32,
    src_ip: option[u32],
    dst_ip: option[u32],
    src_port: option[u16],
    dst_port: option[u16],
    protocol: option[u8],
    action: packet_verdict,
    priority: i32,
    enabled: bool,
    packet_count: u64,
}

struct netfilter_engine {
    hooks: vec[netfilter_hook],
    rules: vec[firewall_rule],
    conntrack_table: connection_table,
    lock: spinlock::spinlock[void],
}

struct connection_table {
    entries: vec[connection_entry],
}

struct connection_entry {
    conn_id: u64,
    src_ip: u32,
    dst_ip: u32,
    src_port: u16,
    dst_port: u16,
    protocol: u8,
    state: connection_state,
    packets_in: u64,
    packets_out: u64,
    bytes_in: u64,
    bytes_out: u64,
    timeout: u32,
}

enum connection_state {
    tcp_established,
    tcp_syn_sent,
    tcp_syn_received,
    tcp_fin_wait1,
    tcp_fin_wait2,
    tcp_time_wait,
    tcp_close,
    tcp_close_wait,
    tcp_last_ack,
    tcp_listen,
    tcp_none,
}

func new_netfilter_engine() result[&netfilter_engine, string] {
    let engine := &netfilter_engine{
        hooks: vec[netfilter_hook](),
        rules: vec[firewall_rule](),
        conntrack_table: connection_table{
            entries: vec[connection_entry](),
        },
        lock: spinlock::new(),
    } as &netfilter_engine

    result::ok(engine)
}

func (engine: &mut netfilter_engine) register_hook(
    hook_type: netfilter_hook_type,
    priority: i32,
    hook_fn: &fn(skb: &packet_buffer, hook: netfilter_hook_type) -> packet_verdict,
    module: &string,
) result[void, string] {
    let _guard := engine.lock.lock()?

    let hook := netfilter_hook{
        hook_type: hook_type,
        priority: priority,
        hook_fn: hook_fn,
        module: module,
        enabled: true,
    }

    engine.hooks.push(hook)
    result::ok(())
}

func (engine: &mut netfilter_engine) unregister_hook(module: &string) result[void, string] {
    let _guard := engine.lock.lock()?

    let mut remove_indices := vec[u32]()
    let mut i := 0

    for hook in engine.hooks {
        if hook.module == module {
            remove_indices.push(i)
        }
        i = i + 1
    }

    i = (remove_indices.len() - 1) as u32
    while i >= 0 {
        let idx := remove_indices.get(i) as u32
        engine.hooks.remove(idx)
        if i == 0 {
            break
        }
        i = i - 1
    }

    result::ok(())
}

func (engine: &mut netfilter_engine) add_rule(
    src_ip: option[u32],
    dst_ip: option[u32],
    src_port: option[u16],
    dst_port: option[u16],
    protocol: option[u8],
    action: packet_verdict,
    priority: i32,
) result[u32, string] {
    let _guard := engine.lock.lock()?

    let rule_id := engine.rules.len() as u32

    let rule := firewall_rule{
        id: rule_id,
        src_ip: src_ip,
        dst_ip: dst_ip,
        src_port: src_port,
        dst_port: dst_port,
        protocol: protocol,
        action: action,
        priority: priority,
        enabled: true,
        packet_count: 0,
    }

    engine.rules.push(rule)
    result::ok(rule_id)
}

func (engine: &mut netfilter_engine) delete_rule(rule_id: u32) result[void, string] {
    let _guard := engine.lock.lock()?

    let mut found := false
    let mut remove_idx := option::none as option[u32]
    let mut i := 0

    for rule in engine.rules {
        if rule.id == rule_id {
            found = true
            remove_idx = option::some(i)
            break
        }
        i = i + 1
    }

    if !found {
        return result::err("rule not found")
    }

    switch remove_idx {
        option::some(idx): {
            engine.rules.remove(idx)
            result::ok(())
        },
        option::none: result::err("failed to delete rule"),
    }
}

func (engine: &mut netfilter_engine) process_packet(
    skb: &packet_buffer,
    hook_type: netfilter_hook_type,
) result[packet_verdict, string] {
    let _guard := engine.lock.lock()?

    for hook in engine.hooks {
        if hook.enabled {
            let verdict := (hook.hook_fn)(skb, hook_type)
            switch verdict {
                packet_verdict::nf_drop: return result::ok(packet_verdict::nf_drop),
                packet_verdict::nf_accept: continue,
                packet_verdict::nf_queue: return result::ok(packet_verdict::nf_queue),
                _: continue,
            }
        }
    }

    for rule in engine.rules {
        if !rule.enabled {
            continue
        }

        if match_rule(skb, &rule) {
            rule.packet_count = rule.packet_count + 1
            return result::ok(rule.action)
        }
    }

    result::ok(packet_verdict::nf_accept)
}

func match_rule(skb: &packet_buffer, rule: &firewall_rule) bool {
    switch rule.src_ip {
        option::some(ip): {
            if skb.src_ip != ip {
                return false
            }
        },
        option::none: {},
    }

    switch rule.dst_ip {
        option::some(ip): {
            if skb.dst_ip != ip {
                return false
            }
        },
        option::none: {},
    }

    switch rule.protocol {
        option::some(proto): {
            if skb.protocol != proto {
                return false
            }
        },
        option::none: {},
    }

    true
}

func (engine: &mut netfilter_engine) track_connection(
    src_ip: u32,
    dst_ip: u32,
    src_port: u16,
    dst_port: u16,
    protocol: u8,
) result[u64, string] {
    let _guard := engine.lock.lock()?

    let conn_id := (engine.conntrack_table.entries.len() as u64) + 1

    let entry := connection_entry{
        conn_id: conn_id,
        src_ip: src_ip,
        dst_ip: dst_ip,
        src_port: src_port,
        dst_port: dst_port,
        protocol: protocol,
        state: connection_state::tcp_established,
        packets_in: 0,
        packets_out: 0,
        bytes_in: 0,
        bytes_out: 0,
        timeout: 3600,
    }

    engine.conntrack_table.entries.push(entry)
    result::ok(conn_id)
}

func (engine: &mut netfilter_engine) update_connection_state(
    conn_id: u64,
    new_state: connection_state,
) result[void, string] {
    let _guard := engine.lock.lock()?

    for entry in engine.conntrack_table.entries {
        if entry.conn_id == conn_id {
            entry.state = new_state
            return result::ok(())
        }
    }

    result::err("connection not found")
}

func (engine: &mut netfilter_engine) update_connection_stats(
    conn_id: u64,
    bytes: u64,
    is_incoming: bool,
) result[void, string] {
    let _guard := engine.lock.lock()?

    for entry in engine.conntrack_table.entries {
        if entry.conn_id == conn_id {
            if is_incoming {
                entry.bytes_in = entry.bytes_in + bytes
                entry.packets_in = entry.packets_in + 1
            } else {
                entry.bytes_out = entry.bytes_out + bytes
                entry.packets_out = entry.packets_out + 1
            }
            return result::ok(())
        }
    }

    result::err("connection not found")
}

struct netfilter_statistics {
    total_rules: u32,
    enabled_rules: u32,
    total_packets_processed: u64,
    packets_accepted: u64,
    packets_dropped: u64,
    active_connections: u32,
}

func (engine: &mut netfilter_engine) get_statistics() result[netfilter_statistics, string] {
    let _guard := engine.lock.lock()?

    let mut enabled_count := 0
    let mut accepted := 0
    let mut dropped := 0

    for rule in engine.rules {
        if rule.enabled {
            enabled_count = enabled_count + 1
        }
    }

    let stats := netfilter_statistics{
        total_rules: engine.rules.len() as u32,
        enabled_rules: enabled_count,
        total_packets_processed: 0,
        packets_accepted: accepted,
        packets_dropped: dropped,
        active_connections: engine.conntrack_table.entries.len() as u32,
    }

    result::ok(stats)
}
