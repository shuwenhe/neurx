package neurx.net.tcp

enum tcp_state {
    tcp_established,
    tcp_syn_sent,
    tcp_syn_recv,
    tcp_fin_wait1,
    tcp_fin_wait2,
    tcp_close_wait,
    tcp_closing,
    tcp_time_wait,
    tcp_closed
}

struct tcp_sock {
    int sock_id            // Socket ID
    tcp_state state        // TCP connection state
    int snd_nxt            // Send next sequence number
    int rcv_nxt            // Receive next sequence number
    int snd_una            // Send unacknowledged
    int cwnd               // Congestion window
    int ssthresh           // Slow start threshold
    int rtt                // Round-trip time
    int rto                // Retransmission timeout
}

struct tcp_stack {
    int total_connections  // Total TCP connections
    int active_connections // Active connections
    int packets_sent       // Packets sent
    int packets_received   // Packets received
    int retransmissions    // Retransmission count
    int connection_errors  // Connection errors
}

func create_tcp_sock(int sock_id) tcp_sock {
    tcp_sock {
        sock_id: sock_id,
        state: tcp_closed,
        snd_nxt: 0,
        rcv_nxt: 0,
        snd_una: 0,
        cwnd: 65536,
        ssthresh: 65536,
        rtt: 0,
        rto: 0
    }
}

func create_tcp_stack() tcp_stack {
    tcp_stack {
        total_connections: 0,
        active_connections: 0,
        packets_sent: 0,
        packets_received: 0,
        retransmissions: 0,
        connection_errors: 0
    }
}

func tcp_connect(stack: *tcp_stack, sock: *tcp_sock) (tcp_stack, tcp_sock) {
    stack_local := stack.*
    sock_local := sock.*
    
    stack_local.total_connections = stack_local.total_connections + 1
    stack_local.active_connections = stack_local.active_connections + 1
    
    sock_local.state = tcp_syn_sent
    sock_local.snd_nxt = 1000
    
    stack.* = stack_local
    sock.* = sock_local
    
    (stack_local, sock_local)
}

func tcp_send(stack: *tcp_stack, sock: *tcp_sock, int data_len) (tcp_stack, tcp_sock, int) {
    stack_local := stack.*
    sock_local := sock.*
    
    bytes_sent := data_len
    stack_local.packets_sent = stack_local.packets_sent + 1
    
    sock_local.snd_nxt = sock_local.snd_nxt + data_len
    sock_local.cwnd = sock_local.cwnd - data_len
    
    stack.* = stack_local
    sock.* = sock_local
    
    (stack_local, sock_local, bytes_sent)
}

func tcp_receive(stack: *tcp_stack, sock: *tcp_sock, int data_len) (tcp_stack, tcp_sock, int) {
    stack_local := stack.*
    sock_local := sock.*
    
    bytes_recv := data_len
    stack_local.packets_received = stack_local.packets_received + 1
    
    sock_local.rcv_nxt = sock_local.rcv_nxt + data_len
    
    stack.* = stack_local
    sock.* = sock_local
    
    (stack_local, sock_local, bytes_recv)
}

func tcp_close(stack: *tcp_stack, sock: *tcp_sock) (tcp_stack, tcp_sock) {
    stack_local := stack.*
    sock_local := sock.*
    
    stack_local.active_connections = stack_local.active_connections - 1
    
    sock_local.state = tcp_closed
    
    stack.* = stack_local
    sock.* = sock_local
    
    (stack_local, sock_local)
}

func tcp_handle_retransmit(stack: *tcp_stack) tcp_stack {
    stack_local := stack.*
    stack_local.retransmissions = stack_local.retransmissions + 1
    
    stack.* = stack_local
    stack_local
}

func print_tcp_stack_info(tcp_stack stack) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║             NeurX TCP/IP Stack - Status Report             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 TCP Connection Configuration:")
    print("   • Total Connections: ")
    print(stack.total_connections)
    print("   • Active Connections: ")
    print(stack.active_connections)
    print("")
    print("📈 TCP Statistics:")
    print("   • Packets Sent: ")
    print(stack.packets_sent)
    print("   • Packets Received: ")
    print(stack.packets_received)
    print("   • Retransmissions: ")
    print(stack.retransmissions)
    print("   • Connection Errors: ")
    print(stack.connection_errors)
    print("")
    print("✅ TCP/IP stack operational!")
    print("")
}
