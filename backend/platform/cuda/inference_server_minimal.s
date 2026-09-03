package neurx.backends.cuda.inference_server

extern "intrinsic" func __host_read_binary_file_range(string path, int offset, int size) []int
extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_bind(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_listen(int sockfd, int backlog) int
extern "intrinsic" func __sys_accept(int sockfd) int
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_close(int fd) int
extern "libc:neurx_s_cuda_device_count" func neurx_s_cuda_device_count() int

func int_to_string(int value) string {
    if value == 0 { return "0"}
    string result = ""
    int v = value
    if v < 0 {
        result = "-"
        v = 0 - v
    }
    for v > 0 {
        int digit = v % 10
        v = v / 10
        if digit == 0 { result = "0" + result}
        else if digit == 1 { result = "1" + result}
        else if digit == 2 { result = "2" + result}
        else if digit == 3 { result = "3" + result}
        else if digit == 4 { result = "4" + result}
        else if digit == 5 { result = "5" + result}
        else if digit == 6 { result = "6" + result}
        else if digit == 7 { result = "7" + result}
        else if digit == 8 { result = "8" + result}
        else { result = "9" + result}
    }
    return result
}

func tokenize_text(string text) []int {
    return __host_read_binary_file_range("", 0, 0)
}

func test_func(int x) int {
    return x
}
