// net/net.s
// AI OS network layer — analogue of Linux net/socket.c + net/core/ + net/ipv4/
//
// Linux maps:
//   net/socket.c        → sock_create, connect, send, recv (BSD socket API)
//   net/core/skbuff.c   → sk_buff (socket buffer / packet)
//   net/ipv4/tcp.c      → TCP state machine
//   net/ipv4/udp.c      → UDP datagram send/recv
//   net/netlink/        → kernel←→userspace messaging (Netlink)
//
// NeurX maps:
//   Provides a socket-like API for:
//     - Agent ↔ Agent communication (local IPC fast path, remote via TCP)
//     - Agent ↔ Tool server (HTTP/gRPC tool endpoints)
//     - Multi-node distributed training (complements distributed/comm/)
//     - Streaming model output to clients (SSE / WebSocket)
//     - Telemetry & observability export (OTLP over gRPC)
//
//   Protocol types:
//     PROTO_LOCAL   → in-process message (zero-copy, bypasses OS network)
//     PROTO_TCP     → reliable ordered stream (inter-node)
//     PROTO_UDP     → low-latency datagram (P2P collective small messages)
//     PROTO_HTTP    → tool/API calls
//     PROTO_GRPC    → structured RPC (distributed/serving/telemetry)

int PROTO_LOCAL = 0
int PROTO_TCP   = 1
int PROTO_UDP   = 2
int PROTO_HTTP  = 3
int PROTO_GRPC  = 4

// Socket states (mirrors Linux TCP states simplified)
int SOCK_CLOSED      = 0
int SOCK_LISTEN      = 1
int SOCK_CONNECTING  = 2
int SOCK_CONNECTED   = 3
int SOCK_CLOSING     = 4

// Packet types
int PKT_DATA         = 0
int PKT_ACK          = 1
int PKT_SYN          = 2
int PKT_FIN          = 3
int PKT_CONTROL      = 4   // NeurX-specific: agent control messages

struct net_addr {
    string host        // hostname or "local"
    int    port        // 0 for local
    int    pid         // for PROTO_LOCAL: target agent pid
}

struct net_socket {
    int      sock_id
    int      proto          // PROTO_*
    int      state          // SOCK_*
    net_addr local_addr
    net_addr remote_addr
    int      send_buf_bytes
    int      recv_buf_bytes
    int      owner_pid
    bool     nonblocking
}

// sk_buff: network packet buffer (analogue of Linux sk_buff)
struct sk_buff {
    int    pkt_id
    int    sock_id
    int    pkt_type        // PKT_*
    string src_host
    string dst_host
    int    src_port
    int    dst_port
    string payload
    int    payload_len
    int    seq_num
    int    created_at_ms
}

struct net_state {
    []net_socket sockets
    []sk_buff    recv_queue   // inbound packets waiting to be read
    []sk_buff    send_queue   // outbound packets waiting to be sent
    int          next_sock_id
    int          next_pkt_id
}

func new_net_state() -> net_state {
    return net_state{
        sockets:       [],
        recv_queue:    [],
        send_queue:    [],
        next_sock_id:  0,
        next_pkt_id:   0,
    }
}

// socket: create a new socket (sys_socket equivalent)
func net_socket(ns net_state, proto int, owner_pid int) -> (net_state, int) {
    int sid = ns.next_sock_id
    net_socket s = net_socket{
        sock_id:        sid,
        proto:          proto,
        state:          SOCK_CLOSED,
        local_addr:     net_addr{host: "", port: 0, pid: owner_pid},
        remote_addr:    net_addr{host: "", port: 0, pid: -1},
        send_buf_bytes: 131072,   // 128KB default send buffer
        recv_buf_bytes: 131072,
        owner_pid:      owner_pid,
        nonblocking:    true,
    }
    ns.sockets    = append(ns.sockets, s)
    ns.next_sock_id = ns.next_sock_id + 1
    return (ns, sid)
}

// connect: initiate connection (sys_connect equivalent)
func net_connect(ns net_state, sock_id int, remote net_addr) -> net_state {
    int i = 0
    while i < len(ns.sockets) {
        if ns.sockets[i].sock_id == sock_id {
            ns.sockets[i].remote_addr = remote
            if ns.sockets[i].proto == PROTO_LOCAL {
                ns.sockets[i].state = SOCK_CONNECTED  // local: instant
            } else {
                ns.sockets[i].state = SOCK_CONNECTING
            }
        }
        i = i + 1
    }
    return ns
}

// send: enqueue a packet for transmission (sys_sendmsg equivalent)
func net_send(ns net_state, sock_id int, payload string, pkt_type int) -> (net_state, int) {
    // find socket
    int src_port = 0
    string dst_host = ""
    int dst_port = 0
    int i = 0
    while i < len(ns.sockets) {
        if ns.sockets[i].sock_id == sock_id {
            src_port = ns.sockets[i].local_addr.port
            dst_host = ns.sockets[i].remote_addr.host
            dst_port = ns.sockets[i].remote_addr.port
        }
        i = i + 1
    }

    int pkt_id = ns.next_pkt_id
    sk_buff pkt = sk_buff{
        pkt_id:      pkt_id,
        sock_id:     sock_id,
        pkt_type:    pkt_type,
        src_host:    "local",
        dst_host:    dst_host,
        src_port:    src_port,
        dst_port:    dst_port,
        payload:     payload,
        payload_len: len(payload),
        seq_num:     pkt_id,
        created_at_ms: 0,
    }
    ns.send_queue   = append(ns.send_queue, pkt)
    ns.next_pkt_id  = ns.next_pkt_id + 1
    return (ns, pkt_id)
}

// recv: dequeue a received packet for this socket (sys_recvmsg equivalent)
func net_recv(ns net_state, sock_id int) -> (net_state, sk_buff, bool) {
    int i = 0
    while i < len(ns.recv_queue) {
        if ns.recv_queue[i].sock_id == sock_id {
            sk_buff pkt = ns.recv_queue[i]
            []sk_buff remaining = []
            int j = 0
            while j < len(ns.recv_queue) {
                if j != i {
                    remaining = append(remaining, ns.recv_queue[j])
                }
                j = j + 1
            }
            ns.recv_queue = remaining
            return (ns, pkt, true)
        }
        i = i + 1
    }
    return (ns, sk_buff{}, false)
}

// deliver: called by the network driver to deliver an inbound packet
func net_deliver(ns net_state, pkt sk_buff) -> net_state {
    ns.recv_queue = append(ns.recv_queue, pkt)
    return ns
}

// close: teardown socket (sys_close equivalent)
func net_close(ns net_state, sock_id int) -> net_state {
    int i = 0
    while i < len(ns.sockets) {
        if ns.sockets[i].sock_id == sock_id {
            ns.sockets[i].state = SOCK_CLOSING
        }
        i = i + 1
    }
    return ns
}
