package neurx.net.socket

enum socket_type {
    sock_stream,
    sock_dgram,
    sock_raw
}

enum socket_state {
    ss_unconnected,
    ss_connecting,
    ss_connected,
    ss_disconnecting
}

struct socket {
    int sock_fd            // Socket file descriptor
    socket_type type       // Socket type (TCP/UDP/RAW)
    socket_state state     // Connection state
    int family             // Address family (AF_INET, etc)
    int local_port         // Local port number
    int remote_port        // Remote port number
    int backlog            // Listen backlog
}

struct inet_sock {
    socket base_socket     // Base socket structure
    int saddr              // Source IP address
    int daddr              // Destination IP address
    int sport              // Source port
    int dport              // Destination port
}

struct socket_manager {
    int total_sockets      // Total sockets created
    int active_sockets     // Currently active sockets
    int total_connects     // Total connection attempts
    int total_disconnects  // Total disconnections
    int socket_errors      // Error count
}

func create_socket(socket_type sock_type, int family) socket {
    socket {
        sock_fd: 0,
        type: sock_type,
        state: ss_unconnected,
        family: family,
        local_port: 0,
        remote_port: 0,
        backlog: 0
    }
}

func create_inet_sock(int saddr, int sport) inet_sock {
    inet_sock {
        base_socket: create_socket(sock_stream, 2),
        saddr: saddr,
        daddr: 0,
        sport: sport,
        dport: 0
    }
}

func create_socket_manager() socket_manager {
    socket_manager {
        total_sockets: 0,
        active_sockets: 0,
        total_connects: 0,
        total_disconnects: 0,
        socket_errors: 0
    }
}

func socket_create(mgr: &socket_manager, socket_type sock_type) (socket_manager, socket) {
    mgr_local := mgr.*
    
    mgr_local.total_sockets = mgr_local.total_sockets + 1
    mgr_local.active_sockets = mgr_local.active_sockets + 1
    
    mgr.* = mgr_local
    
    sock := create_socket(sock_type, 2)
    (mgr_local, sock)
}

func socket_bind(sock: &socket, int port) socket {
    sock_local := sock.*
    sock_local.local_port = port
    
    sock.* = sock_local
    sock_local
}

func socket_connect(sock: &socket, int remote_addr, int remote_port) socket {
    sock_local := sock.*
    
    sock_local.remote_port = remote_port
    sock_local.state = ss_connecting
    sock_local.state = ss_connected
    
    sock.* = sock_local
    sock_local
}

func socket_listen(sock: &socket, int backlog) socket {
    sock_local := sock.*
    
    sock_local.state = ss_unconnected
    sock_local.backlog = backlog
    
    sock.* = sock_local
    sock_local
}

func socket_close(mgr: &socket_manager, sock: &socket) socket_manager {
    mgr_local := mgr.*
    sock_local := sock.*
    
    mgr_local.active_sockets = mgr_local.active_sockets - 1
    mgr_local.total_disconnects = mgr_local.total_disconnects + 1
    
    sock_local.state = ss_disconnecting
    
    sock.* = sock_local
    mgr.* = mgr_local
    mgr_local
}

func print_socket_manager_info(socket_manager mgr) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║          NeurX Socket Manager - Status Report              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Socket Configuration:")
    print("   • Total Sockets Created: ")
    print(mgr.total_sockets)
    print("   • Active Sockets: ")
    print(mgr.active_sockets)
    print("")
    print("📈 Socket Statistics:")
    print("   • Total Connections: ")
    print(mgr.total_connects)
    print("   • Total Disconnections: ")
    print(mgr.total_disconnects)
    print("   • Socket Errors: ")
    print(mgr.socket_errors)
    print("")
    print("✅ Socket layer operational!")
    print("")
}
