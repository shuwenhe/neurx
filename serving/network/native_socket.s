package neurx.serving.network.native_socket
extern func neurx_net_listen(string host, int port, int backlog) int
extern func neurx_net_connect(string host, int port, int timeout_ms) int
extern func neurx_net_accept(int listener_fd) int
extern func neurx_net_local_port(int fd) int
extern func neurx_net_poll(int fd, int events, int timeout_ms) int
extern func neurx_net_read(int fd, int64 buffer, int capacity) int64
extern func neurx_net_write(int fd, int64 buffer, int size) int64
extern func neurx_net_close(int fd) int
extern func neurx_net_monotonic_ms() int64
int NEURX_POLL_READ = 1
int NEURX_POLL_WRITE = 2
int NEURX_POLL_ERROR = 4

