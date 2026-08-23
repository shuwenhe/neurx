#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
int neurx_net_listen(const char* host, int port, int backlog);
int neurx_net_connect(const char* host, int port, int timeout_ms);
int neurx_net_accept(int listener_fd);
int neurx_net_local_port(int fd);
int neurx_net_poll(int fd, int events, int timeout_ms);
long long neurx_net_read(int fd, void* buffer, size_t capacity);
long long neurx_net_write(int fd, const void* buffer, size_t size);
int neurx_net_close(int fd);
int64_t neurx_net_monotonic_ms(void);
enum { NEURX_POLL_READ = 1, NEURX_POLL_WRITE = 2, NEURX_POLL_ERROR = 4 };
#ifdef __cplusplus
}
#endif
