package neurx.inference.api.http_server

extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_bind(int fd, string host, int port) int
extern "intrinsic" func __sys_listen(int fd, int backlog) int
extern "intrinsic" func __sys_accept(int fd) int
extern "intrinsic" func __sys_recv(int fd, int count) string
extern "intrinsic" func __sys_send(int fd, string data) int
extern "intrinsic" func __sys_close(int fd) int

struct http_request {
    string method
    string path
    []string headers
    string body
}

struct http_response {
    int status_code
    []string headers
    string body
}

func parse_http_request(string raw_request) http_request {
    lines := split_string(raw_request, "\n")

    if len(lines) == 0 {
        return http_request{method: "", path: "", headers: [], body: ""}
    }

    request_line := lines[0]
    parts := split_string(request_line, " ")

    method := ""
    path := "/"

    if len(parts) >= 2 {
        method = parts[0]
        path = parts[1]
    }

    headers := []string{}
    body_start := 0

    for i := 1; i < len(lines); i++ {
        line := lines[i]
        if len(line) == 0 {
            body_start = i + 1
            break
        }
        headers = append(headers, line)
    }

    body := ""
    if body_start < len(lines) {
        body = lines[body_start]
    }

    return http_request{
        method: method,
        path: path,
        headers: headers,
        body: body,
    }
}

func format_http_response(http_response resp) string {
    response := "HTTP/1.1 " + int_to_string(resp.status_code) + " OK\r\n"
    response = response + "Content-Type: application/json\r\n"
    response = response + "Content-Length: " + int_to_string(len(resp.body)) + "\r\n"
    response = response + "Connection: close\r\n"

    for i := 0; i < len(resp.headers); i++ {
        response = response + resp.headers[i] + "\r\n"
    }

    response = response + "\r\n" + resp.body
    return response
}

func int_to_string(int val) string {
    if val == 0 { return "0" }
    string res = ""
    int cur = val
    if cur < 0 { cur = -cur }
    while cur != 0 {
        int d = cur - (cur / 10) * 10
        res = string_at_index("0123456789", d) + res
        cur = cur / 10
    }
    return res
}

func string_at_index(string s, int idx) string {
    if idx < 0 || idx >= len(s) { return "" }
    return string(s[idx : idx+1])
}

func split_string(string s, string sep) []string {
    result := []string{}
    if len(s) == 0 { return result }

    current := ""
    for i := 0; i < len(s); i++ {
        current = current + string(s[i])

        if i+len(sep) <= len(s) && s[i:i+len(sep)] == sep {
            if len(current) > len(sep) {
                result = append(result, current[0:len(current)-len(sep)])
            } else {
                result = append(result, "")
            }
            current = ""
            i = i + len(sep) - 1
        }
    }

    if len(current) > 0 {
        result = append(result, current)
    }

    return result
}

struct http_server {
    int listen_fd
    int port
    string host
    bool running
}

func create_http_server(string host, int port) http_server {
    listen_fd := __sys_socket(2, 1, 0)

    if listen_fd < 0 {
        print("error: failed to create socket\n")
        return http_server{listen_fd: -1, port: port, host: host, running: false}
    }

    bind_result := __sys_bind(listen_fd, host, port)
    if bind_result < 0 {
        print("error: failed to bind socket\n")
        __sys_close(listen_fd)
        return http_server{listen_fd: -1, port: port, host: host, running: false}
    }

    listen_result := __sys_listen(listen_fd, 128)
    if listen_result < 0 {
        print("error: failed to listen\n")
        __sys_close(listen_fd)
        return http_server{listen_fd: -1, port: port, host: host, running: false}
    }

    print("✓ HTTP server listening on " + host + ":" + int_to_string(port) + "\n")

    return http_server{
        listen_fd: listen_fd,
        port: port,
        host: host,
        running: true,
    }
}

func handle_connection(int client_fd, func(http_request) http_response handler) {
    request_data := __sys_recv(client_fd, 4096)

    if len(request_data) == 0 {
        __sys_close(client_fd)
        return
    }

    request := parse_http_request(request_data)
    response := handler(request)

    response_data := format_http_response(response)
    __sys_send(client_fd, response_data)

    __sys_close(client_fd)
}

func server_accept_loop(http_server server, func(http_request) http_response handler) {
    while server.running {
        client_fd := __sys_accept(server.listen_fd)

        if client_fd < 0 {
            print("error: accept failed\n")
            continue
        }

        handle_connection(client_fd, handler)
    }
}

func close_http_server(http_server server) {
    if server.listen_fd >= 0 {
        __sys_close(server.listen_fd)
        print("✓ HTTP server closed\n")
    }
}
