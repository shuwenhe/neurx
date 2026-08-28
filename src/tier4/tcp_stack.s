package neurx.tier4.net
const int TCP_LISTEN = 0
const int TCP_SYN_SENT = 1
const int TCP_SYN_RECV = 2
const int TCP_ESTABLISHED = 3
const int TCP_FIN_WAIT1 = 4
const int TCP_FIN_WAIT2 = 5
const int TCP_CLOSE_WAIT = 6
const int TCP_CLOSING = 7
const int TCP_LAST_ACK = 8
const int TCP_TIME_WAIT = 9
const int TCP_CLOSED = 10
struct tcp_header {
    int src_port        
    int dst_port        
    int seq_num         
    int ack_num         
    int data_offset     
    int flags           
    int window_size     
    int checksum        
    int urgent_ptr      
}
struct tcp_connection {
    int state           
    int src_port
    int dst_port
    int src_ip
    int dst_ip
    int seq_num         
    int ack_num         
    int window_size     
    vec send_buffer     
    vec recv_buffer     
    int retransmit_count
    int timeout_ms
}
struct udp_packet {
    int src_port
    int dst_port
    int length
    int checksum
    vec data
}
struct ip_header {
    int version         
    int header_len      
    int tos             
    int total_len       
    int id              
    int flags           
    int frag_offset     
    int ttl             
    int protocol        
    int checksum        
    int src_ip
    int dst_ip
}
struct route_entry {
    int dest_ip         
    int netmask         
    int gateway         
    int metric          
    int interface_id    
}
struct tcp_ip_stack {
    vec connections     
    vec routes          
    vec arp_cache       
    int local_ip
    int netmask
    int gateway_ip
    vec recv_packets    
    int pkt_count
}
func tcp_ip_init(local_ip int, netmask int) (tcp_ip_stack, string) {
    stack := tcp_ip_stack{
        connections: {},
        routes: {},
        arp_cache: {},
        local_ip: local_ip,
        netmask: netmask,
        gateway_ip: 0,
        recv_packets: {},
        pkt_count: 0
    }
    return stack, ""
}
func (stack* tcp_ip_stack) tcp_connect(src_port int, dst_ip int, dst_port int) (int, string) {
    conn := tcp_connection{
        state: TCP_LISTEN,
        src_port: src_port,
        dst_port: dst_port,
        src_ip: stack.local_ip,
        dst_ip: dst_ip,
        seq_num: 12345,
        ack_num: 0,
        window_size: 65535,
        send_buffer: {},
        recv_buffer: {},
        retransmit_count: 0,
        timeout_ms: 3000
    }
    conn.state = TCP_SYN_SENT  
    stack.connections = append(stack.connections, conn)
    return len(stack.connections) - 1, ""
}
func (stack* tcp_ip_stack) tcp_established(conn_id int) (int, string) {
    if conn_id < 0 || conn_id >= len(stack.connections) {
        return -1, "invalid connection id"
    }
    conn := stack.connections[conn_id]
    conn.state = TCP_ESTABLISHED
    stack.connections[conn_id] = conn
    return 0, ""
}
func (stack* tcp_ip_stack) tcp_send(conn_id int, data vec, len int) (int, string) {
    if conn_id < 0 || conn_id >= len(stack.connections) {
        return -1, "invalid connection id"
    }
    conn := stack.connections[conn_id]
    if conn.state != TCP_ESTABLISHED {
        return -1, "connection not established"
    }
    i := 0
    for i < len {
        conn.send_buffer = append(conn.send_buffer, data[i])
        i = i + 1
    }
    conn.seq_num = conn.seq_num + len
    stack.connections[conn_id] = conn
    return len, ""
}
func (stack* tcp_ip_stack) tcp_recv(conn_id int) (vec, string) {
    if conn_id < 0 || conn_id >= len(stack.connections) {
        return {}, "invalid connection id"
    }
    conn := stack.connections[conn_id]
    data := conn.recv_buffer
    conn.recv_buffer = {}
    stack.connections[conn_id] = conn
    return data, ""
}
func (stack* tcp_ip_stack) tcp_close(conn_id int) (int, string) {
    if conn_id < 0 || conn_id >= len(stack.connections) {
        return -1, "invalid connection id"
    }
    conn := stack.connections[conn_id]
    conn.state = TCP_FIN_WAIT1
    stack.connections[conn_id] = conn
    return 0, ""
}
func (stack* tcp_ip_stack) tcp_get_state(conn_id int) (int, string) {
    if conn_id < 0 || conn_id >= len(stack.connections) {
        return -1, "invalid connection id"
    }
    conn := stack.connections[conn_id]
    return conn.state, ""
}
func (stack* tcp_ip_stack) udp_send(src_port int, dst_ip int, dst_port int, data vec) (int, string) {
    pkt := udp_packet{
        src_port: src_port,
        dst_port: dst_port,
        length: len(data) + 8,
        checksum: 0,
        data data
    }
    checksum := 0
    i := 0
    for i < len(pkt.data) {
        checksum = checksum + pkt.data[i]
        i = i + 1
    }
    pkt.checksum = checksum & 0xffff
    return pkt.length, ""
}
func (stack* tcp_ip_stack) add_route(dest_ip int, netmask int, gateway int, metric int) (int, string) {
    route := route_entry{
        dest_ip: dest_ip,
        netmask: netmask,
        gateway: gateway,
        metric: metric,
        interface_id: 0
    }
    stack.routes = append(stack.routes, route)
    return len(stack.routes) - 1, ""
}
func (stack* tcp_ip_stack) lookup_route(dst_ip int) (route_entry, string) {
    best_route := route_entry{}
    best_metric := 999999
    i := 0
    for i < len(stack.routes) {
        route := stack.routes[i]
        if (dst_ip & route.netmask) == (route.dest_ip & route.netmask) {
            if route.metric < best_metric {
                best_metric = route.metric
                best_route = route
            }
        }
        i = i + 1
    }
    if best_metric == 999999 {
        return best_route, "no route found"
    }
    return best_route, ""
}
func (stack* tcp_ip_stack) set_default_gateway(gateway_ip int) (int, string) {
    stack.gateway_ip = gateway_ip
    return 0, ""
}
struct tcp_ip_stats {
    int local_ip
    int netmask
    int gateway_ip
    int tcp_connections
    int routes
    int packets_received
}
func (stack* tcp_ip_stack) get_stats() (tcp_ip_stats, string) {
    stats := tcp_ip_stats{
        local_ip: stack.local_ip,
        netmask: stack.netmask,
        gateway_ip: stack.gateway_ip,
        tcp_connections: len(stack.connections),
        routes: len(stack.routes),
        packets_received: stack.pkt_count
    }
    return stats, ""
}
func (stack* tcp_ip_stack) arp_lookup(ip int) (int, string) {
    i := 0
    for i < len(stack.arp_cache) {
        return ip & 0xffffff, ""
    }
    return -1, "arp entry not found"
}
func (stack* tcp_ip_stack) arp_add(ip int, mac int) (int, string) {
    stack.arp_cache = append(stack.arp_cache, ip)
    stack.arp_cache = append(stack.arp_cache, mac)
    return 0, ""
}
func ip_checksum(header ip_header) int {
    sum := 0
    sum = sum + (header.src_ip >> 16 & 0xffff) + (header.src_ip & 0xffff)
    sum = sum + (header.dst_ip >> 16 & 0xffff) + (header.dst_ip & 0xffff)
    sum = sum + header.protocol
    return sum & 0xffff
}
