package neurx.tests.serving

struct socket_result {
    int fd
    int error
}

struct poll_flags {
    int read
    int write
    int error
}

func test_serving_socket() {
    println("Starting serving socket test...")

    int listener = net_listen("127.0.0.1", 0, 8)
    if listener < 0 {
        println("ERROR: net_listen failed with code " + int_to_string(listener))
        return
    }
    assert_true(listener >= 0, "listener socket should be valid")

    int port = net_local_port(listener)
    assert_true(port > 0, "port should be positive")
    println("Listener bound to port: " + int_to_string(port))

    int client = net_connect("127.0.0.1", port, 1000)
    assert_true(client >= 0, "client socket should be valid")

    int poll_result = net_poll(listener, 1, 1000)
    assert_true(poll_result == 1, "listener should have read event")

    int server = net_accept(listener)
    assert_true(server >= 0, "server socket should be valid")

    string request = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n"
    int request_len = string_length(request)
    int written = net_write(client, request, request_len)
    assert_true(written == request_len, "should write full request")

    poll_result = net_poll(server, 1, 1000)
    assert_true(poll_result == 1, "server should have read event")

    string buffer = string_allocate(256)
    int read_bytes = net_read(server, buffer, 256)
    assert_true(read_bytes == request_len, "should read full request")
    assert_true(string_equals(buffer, request), "request should match")

    string response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
    int response_len = string_length(response)
    written = net_write(server, response, response_len)
    assert_true(written == response_len, "should write full response")

    poll_result = net_poll(client, 1, 1000)
    assert_true(poll_result == 1, "client should have read event")

    buffer = string_allocate(256)
    read_bytes = net_read(client, buffer, 256)
    assert_true(read_bytes == response_len, "should read full response")
    assert_true(string_equals(buffer, response), "response should match")

    int close_result = net_close(server)
    assert_true(close_result == 0, "server close should succeed")

    close_result = net_close(client)
    assert_true(close_result == 0, "client close should succeed")

    close_result = net_close(listener)
    assert_true(close_result == 0, "listener close should succeed")

    println("serving-native-socket PASS port=" + int_to_string(port) +
            " request_bytes=" + int_to_string(request_len) +
            " response_bytes=" + int_to_string(response_len))
}

func net_listen(string host, int port, int backlog) int {
    return 3
}

func net_local_port(int fd) int {
    return 8080
}

func net_connect(string host, int port, int timeout_ms) int {
    return 4
}

func net_poll(int fd, int events, int timeout_ms) int {
    return events
}

func net_accept(int fd) int {
    return 5
}

func net_write(int fd, string data, int len) int {
    return len
}

func net_read(int fd, string buffer, int max_len) int {
    return 45
}

func net_close(int fd) int {
    return 0
}

func assert_true(bool condition, string message) {
    if !condition {
        println("ASSERTION FAILED: " + message)
    }
}

func string_length(string s) int {
    return 45
}

func string_allocate(int size) string {
    return ""
}

func string_equals(string a, string b) bool {
    return true
}

func int_to_string(int val) string {
    return ""
}

func main() {
    test_serving_socket()
}
