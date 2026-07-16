#include "../serving/native/serving_socket.h"

#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  int listener = neurx_net_listen("127.0.0.1", 0, 8);
  if (listener < 0) fprintf(stderr, "neurx_net_listen failed: %s (%d)\n", strerror(-listener), listener);
  assert(listener >= 0);
  int port = neurx_net_local_port(listener);
  assert(port > 0);
  int client = neurx_net_connect("127.0.0.1", port, 1000);
  assert(client >= 0);
  assert(neurx_net_poll(listener, NEURX_POLL_READ, 1000) & NEURX_POLL_READ);
  int server = neurx_net_accept(listener);
  assert(server >= 0);

  const char request[] = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
  assert(neurx_net_write(client, request, sizeof(request) - 1) == (long long)sizeof(request) - 1);
  assert(neurx_net_poll(server, NEURX_POLL_READ, 1000) & NEURX_POLL_READ);
  char buffer[256] = {0};
  long long read_bytes = neurx_net_read(server, buffer, sizeof(buffer));
  assert(read_bytes == (long long)sizeof(request) - 1 && memcmp(buffer, request, sizeof(request) - 1) == 0);

  const char response[] = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK";
  assert(neurx_net_write(server, response, sizeof(response) - 1) == (long long)sizeof(response) - 1);
  assert(neurx_net_poll(client, NEURX_POLL_READ, 1000) & NEURX_POLL_READ);
  memset(buffer, 0, sizeof(buffer));
  read_bytes = neurx_net_read(client, buffer, sizeof(buffer));
  assert(read_bytes == (long long)sizeof(response) - 1 && memcmp(buffer, response, sizeof(response) - 1) == 0);

  assert(neurx_net_close(server) == 0);
  assert(neurx_net_close(client) == 0);
  assert(neurx_net_close(listener) == 0);
  printf("serving-native-socket PASS port=%d request_bytes=%zu response_bytes=%zu\n",
         port, sizeof(request) - 1, sizeof(response) - 1);
  return 0;
}
