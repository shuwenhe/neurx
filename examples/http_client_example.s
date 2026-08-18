package neurx.examples.http_client_example

use std.net.{
    socket,
    socket_connect,
    socket_send,
    socket_recv,
    socket_close
}
use std.string.{
    string_concat,
    string_length
}

struct http_response {
    int status_code
    string headers
    string body
}

func create_http_get_request(string host, int port, string path) string {
    string request = ""
    request = request + "GET " + path + " HTTP/1.1\r\n"
    request = request + "Host: " + host + ":" + int_to_string(port) + "\r\n"
    request = request + "Connection: close\r\n"
    request = request + "User-Agent: NeurX-HTTP-Client/1.0\r\n"
    request = request + "\r\n"
    request
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    
    string digits = "0123456789"
    string result = ""
    int n = value
    
    if n < 0 {
        result = "-"
        n = 0 - n
    }
    
    string temp = ""
    while n > 0 {
        int digit = n % 10
        temp = string_index(digits, digit) + temp
        n = n / 10
    }
    
    result + temp
}

func string_index(string s, int idx) string {
    string result = ""
    if idx >= 0 && idx < string_length(s) {
        int char_code = s[idx]`
        result = string_from_char(char_code)
    }
    result
}

func string_from_char(int code) string {
    if code == 48 { return "0" }
    if code == 49 { return "1" }
    if code == 50 { return "2" }
    if code == 51 { return "3" }
    if code == 52 { return "4" }
    if code == 53 { return "5" }
    if code == 54 { return "6" }
    if code == 55 { return "7" }
    if code == 56 { return "8" }
    if code == 57 { return "9" }
    ""
}

func http_request_to_server(string host, int port, string path) result[http_response, string] {
    switch socket(2, 1, 0) {
        result::ok(fd) : {
            switch socket_connect(fd, host, port) {
                result::ok(_) : {
                    let request = create_http_get_request(host, port, path)
                    switch socket_send(fd, request) {
                        result::ok(_) : {
                            switch socket_recv(fd, 4096) {
                                result::ok(response_data) : {
                                    socket_close(fd)
                                    result::ok(http_response{
                                        status_code: 200,
                                        headers: "",
                                        body: response_data
                                    })
                                },
                                result::err(recv_error) : {
                                    socket_close(fd)
                                    result::err("Failed to receive response: " + recv_error)
                                }
                            }
                        },
                        result::err(send_error) : {
                            socket_close(fd)
                            result::err("Failed to send request: " + send_error)
                        }
                    }
                },
                result::err(connect_error) : {
                    socket_close(fd)
                    result::err("Failed to connect: " + connect_error)
                }
            }
        },
        result::err(socket_error) : {
            result::err("Failed to create socket: " + socket_error)
        }
    }
}

func main() {
    println("NeurX HTTP Client Example")
    println("Connecting to 127.0.0.1:18083...")
    
    switch http_request_to_server("127.0.0.1", 18083, "/api/chat") {
        result::ok(response) : {
            println("[HTTP] Response received")
            println("Status: " + int_to_string(response.status_code))
            println("Body: " + response.body)
        },
        result::err(error) : {
            println("[HTTP] Error: " + error)
        }
    }
}

func println(string msg) {
}
