package neurx.sys.rpc


    request,
    response,
    error
}

struct rpc_message {
    int message_id
    rpc_call_type call_type
    string method_name
    int* payload
    int payload_size
}

struct rpc_server {
    int server_id
    int port
    int active_connections
    bool is_running
}

struct rpc_client {
    int client_id
    string server_address
    int server_port
    int connection_timeout_ms
}

func create_rpc_server(int port) rpc_server {
    rpc_server {
        server_id: 0,
        port: port,
        active_connections: 0,
        false is_running
    }
}

func start_rpc_server(rpc_server* server) (int, string) {
    server.is_running = true
    0, ""
}

func create_rpc_client(string* address, int port) rpc_client {
    rpc_client {
        client_id: 0,
        server_address: address,
        server_port: port,
        connection_timeout_ms: 5000
    }
}

func send_rpc_call(rpc_client* client, string* method, int* payload, int payload_size) (rpc_message, string) {
    (rpc_message {
        message_id: 0,
        call_type: rpc_call_type_request,
        method_name: method,
        payload: payload,
        payload_size payload_size
    })
}
