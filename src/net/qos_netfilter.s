package neurx.net
use std.slices
struct qos_class {
    int class_id
    int bandwidth_limit  
    int priority
    int packets_sent
    int bytes_sent
}

struct netfilter_rule {
    int rule_id
    string source_ip
    string dest_ip
    int protocol  
    int source_port
    int dest_port
    int action  
    int counter
}

struct qos_manager {
    qos_class[] qos_classes
    int max_classes
}

func (qos_manager* qm) init(int max_classes) (int, string) {
    qm.qos_classes = {}
    qm.max_classes = max_classes
    return 0, ""
}

func (qos_manager* qm) create_class(int bandwidth_limit, int priority) (qos_class, string) {
    if len(qm.qos_classes) >= qm.max_classes {
        return qos_class{}, "Max classes reached"
    }
    class_id := len(qm.qos_classes)
    qc := qos_class{
        class_id: class_id,
        bandwidth_limit: bandwidth_limit,
        priority: priority,
        packets_sent: 0,
        bytes_sent: 0
    }
    qm.qos_classes = append(qm.qos_classes, qc)
    return qc, ""
}

func (qos_manager* qm) send_packet(int class_id, int size) (int, string) {
    if class_id >= len(qm.qos_classes) {
        return -1, "Invalid class"
    }
    qc := qm.qos_classes[class_id]
    if qc.bytes_sent >= qc.bandwidth_limit * 125 {  
        return -1, "Bandwidth limit exceeded"
    }
    qc.packets_sent = qc.packets_sent + 1
    qc.bytes_sent = qc.bytes_sent + size
    qm.qos_classes[class_id] = qc
    return size, ""
}

func (qos_manager qm) get_class_stats(int class_id) (int, int, int) {
    if class_id >= len(qm.qos_classes) {
        return 0, 0, 0
    }
    qc := qm.qos_classes[class_id]
    return qc.packets_sent, qc.bytes_sent, qc.bandwidth_limit
}

struct netfilter {
    netfilter_rule[] rules
    int rule_counter
}

func (netfilter* nf) init() (int, string) {
    nf.rules = {}
    nf.rule_counter = 0
    return 0, ""
}

func (netfilter* nf) add_rule(string src_ip, string dst_ip, int protocol, int src_port, int dst_port, int action) (netfilter_rule, string) {
    rule := netfilter_rule{
        rule_id: nf.rule_counter,
        source_ip: src_ip,
        dest_ip: dst_ip,
        protocol: protocol,
        source_port: src_port,
        dest_port: dst_port,
        action: action,
        counter: 0
    }
    nf.rules = append(nf.rules, rule)
    nf.rule_counter = nf.rule_counter + 1
    return rule, ""
}

func (netfilter* nf) check_packet(string src_ip, string dst_ip, int protocol, int src_port, int dst_port) (int, string) {
    i := 0
    for i < len(nf.rules) {
        rule := nf.rules[i]
        if rule.source_ip == src_ip && rule.dest_ip == dst_ip && rule.protocol == protocol && rule.source_port == src_port && rule.dest_port == dst_port {
            rule.counter = rule.counter + 1
            nf.rules[i] = rule
            if rule.action == 0 {
                return 0, "ACCEPT"
            } else if rule.action == 1 {
                return 1, "DROP"
            } else {
                return 2, "REJECT"
            }
        }
        i = i + 1
    }
    return 0, "ACCEPT"  
}

func (netfilter nf) get_rule_stats(int rule_id) (int, string) {
    i := 0
    for i < len(nf.rules) {
        rule := nf.rules[i]
        if rule.rule_id == rule_id {
            return rule.counter, ""
        }
        i = i + 1
    }
    return 0, "Rule not found"
}

func (netfilter* nf) delete_rule(int rule_id) (int, string) {
    i := 0
    for i < len(nf.rules) {
        rule := nf.rules[i]
        if rule.rule_id == rule_id {
            rule.action = -1
            nf.rules[i] = rule
            return 0, ""
        }
        i = i + 1
    }
    return -1, "Rule not found"
}
