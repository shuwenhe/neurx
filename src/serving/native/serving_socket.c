#include "serving_socket.h"
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
static int set_nonblocking(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) return -errno;
  return 0;
}
static int make_address(const char* host, int port, struct sockaddr_in* address) {
  if (!address || port < 0 || port > 65535) return -EINVAL;
  memset(address, 0, sizeof(*address));
  address->sin_family = AF_INET;
  address->sin_port = htons((uint16_t)port);
  if (!host || host[0] == '\0' || strcmp(host, "0.0.0.0") == 0) {
    address->sin_addr.s_addr = htonl(INADDR_ANY);
    return 0;
  }
  return inet_pton(AF_INET, host, &address->sin_addr) == 1 ? 0 : -EINVAL;
}
int neurx_net_listen(const char* host, int port, int backlog) {
  struct sockaddr_in address;
  int status = make_address(host, port, &address);
  if (status < 0) return status;
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) return -errno;
  int enabled = 1;
  if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled)) < 0 ||
      set_nonblocking(fd) < 0 || bind(fd, (struct sockaddr*)&address, sizeof(address)) < 0 ||
      listen(fd, backlog > 0 ? backlog : 128) < 0) {
    status = -errno;
    close(fd);
    return status;
  }
  return fd;
}
int neurx_net_connect(const char* host, int port, int timeout_ms) {
  struct sockaddr_in address;
  int status = make_address(host, port, &address);
  if (status < 0) return status;
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) return -errno;
  if (set_nonblocking(fd) < 0) { status = -errno; close(fd); return status; }
  if (connect(fd, (struct sockaddr*)&address, sizeof(address)) == 0) return fd;
  if (errno != EINPROGRESS) { status = -errno; close(fd); return status; }
  status = neurx_net_poll(fd, NEURX_POLL_WRITE, timeout_ms);
  if (status <= 0) { close(fd); return status == 0 ? -ETIMEDOUT : status; }
  int socket_error = 0;
  socklen_t length = sizeof(socket_error);
  if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &socket_error, &length) < 0 || socket_error != 0) {
    status = socket_error ? -socket_error : -errno;
    close(fd);
    return status;
  }
  return fd;
}
int neurx_net_accept(int listener_fd) {
  int fd = accept(listener_fd, NULL, NULL);
  if (fd < 0) return -errno;
  int status = set_nonblocking(fd);
  if (status < 0) { close(fd); return status; }
  int enabled = 1;
  setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &enabled, sizeof(enabled));
  return fd;
}
int neurx_net_local_port(int fd) {
  struct sockaddr_in address;
  socklen_t length = sizeof(address);
  if (getsockname(fd, (struct sockaddr*)&address, &length) < 0) return -errno;
  return ntohs(address.sin_port);
}
int neurx_net_poll(int fd, int events, int timeout_ms) {
  struct pollfd item = {.fd = fd, .events = 0, .revents = 0};
  if (events & NEURX_POLL_READ) item.events |= POLLIN;
  if (events & NEURX_POLL_WRITE) item.events |= POLLOUT;
  int result;
  do { result = poll(&item, 1, timeout_ms); } while (result < 0 && errno == EINTR);
  if (result < 0) return -errno;
  if (result == 0) return 0;
  int ready = 0;
  if (item.revents & POLLIN) ready |= NEURX_POLL_READ;
  if (item.revents & POLLOUT) ready |= NEURX_POLL_WRITE;
  if (item.revents & (POLLERR | POLLHUP | POLLNVAL)) ready |= NEURX_POLL_ERROR;
  return ready;
}
long long neurx_net_read(int fd, void* buffer, size_t capacity) {
  ssize_t result;
  do { result = read(fd, buffer, capacity); } while (result < 0 && errno == EINTR);
  return result < 0 ? -errno : (long long)result;
}
long long neurx_net_write(int fd, const void* buffer, size_t size) {
  ssize_t result;
#ifdef MSG_NOSIGNAL
  do { result = send(fd, buffer, size, MSG_NOSIGNAL); } while (result < 0 && errno == EINTR);
#else
  do { result = write(fd, buffer, size); } while (result < 0 && errno == EINTR);
#endif
  return result < 0 ? -errno : (long long)result;
}
int neurx_net_close(int fd) { return close(fd) == 0 ? 0 : -errno; }
int64_t neurx_net_monotonic_ms(void) {
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return -1;
  return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}
