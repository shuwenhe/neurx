use std.conv.int_to_string
use std.result.result

package neurx.inference.api.http_server
use src.net.{listen_tcp, tcp_listener, tcp_conn}
use src.net.http.{http_request, http_response, parse_http_request, format_http_response}

struct http_server {
    int listen_fd
    int port
    string host
    bool running
}

func listener_from_server(http_server server) tcp_listener {
    tcp_listener {
        fd: server.listen_fd,
        host: server.host,
        port: server.port,
    }
}

func conn_from_fd(int client_fd) tcp_conn {
    tcp_conn {
        fd: client_fd,
        remote_ip: "",
        remote_port: 0,
        read_timeout_ms: 0,
        write_timeout_ms: 0,
    }
}

func write_client_data(int client_fd, string data) int {
    tcp_conn conn = conn_from_fd(client_fd)
    switch conn.write(data) {
        (n, "") : n,
        (0, _) : -1,
    }
}

func close_client_connection(int client_fd) int {
    tcp_conn conn = conn_from_fd(client_fd)
    switch conn.close() {
        (_, "") : 0,
        (0, _) : -1,
    }
}

func create_http_server(string host, int port) http_server {
    let listener_res = listen_tcp(host, port)
    let listener = switch listener_res {
        (value, "") : value,
        (0, err) : {
            print("error: failed to listen: " + err.message + "\n")
            return http_server{listen_fd: -1, port: port, host: host, running: false}
        },
    }
    print("✓ HTTP server listening on " + listener.host + ":" + int_to_string(listener.port) + "\n")
    return http_server{
        listen_fd: listener.fd,
        port: listener.port,
        host: listener.host,
        running: true,
    }
}

func handle_connection(int client_fd, func(http_request) http_response handler) {
    tcp_conn conn = conn_from_fd(client_fd)
    string request_data = switch conn.read(4096) {
        (data, "") : data,
        (0, err) : {
            print("error: failed to read request: " + err.message + "\n")
            conn.close()
            return
        },
    }
    if len(request_data) == 0 {
        conn.close()
        return
    }
    request := parse_http_request(request_data)
    response := handler(request)
    response_data := format_http_response(response)
    switch conn.write(response_data) {
        (_, "") : (),
        (0, err) : {
            print("error: failed to write response: " + err.message + "\n")
        },
    }
    conn.close()
}

func server_accept_loop(http_server server, func(http_request) http_response handler) {
    tcp_listener listener = listener_from_server(server)
    while server.running {
        let conn_res = listener.accept()
        switch conn_res {
            (conn, "") : {
                handle_connection(conn.fd, handler)
            },
            (0, err) : {
                print("error: accept failed: " + err.message + "\n")
            },
        }
    }
}

func close_http_server(http_server server) {
    if server.listen_fd >= 0 {
        listener_from_server(server).close()
        print("✓ HTTP server closed\n")
    }
}
