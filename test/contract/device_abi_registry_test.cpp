#include "../../backend/api/device_abi.h"

#include <cstdlib>
#include <iostream>

int main(int argc, char** argv) {
  const char* backend = argc > 1 ? argv[1] : "cann";
  int available = neurx_device_probe(backend);
  if (available < 0) {
    std::cerr << "FAIL: probe contract: " << neurx_device_last_error(0) << '\n';
    return 1;
  }
  if (available == 0) {
    std::cout << "SKIP: " << backend << " plugin loaded; no device available\n";
    return 0;
  }
  int context = neurx_device_create(backend, 0, "{}");
  int host = neurx_device_alloc(context, 64, "host");
  int device = neurx_device_alloc(context, 64, "device");
  int stream = neurx_device_stream_create(context, 0);
  if (context <= 0 || host <= 0 || device <= 0 || stream <= 0 ||
      neurx_device_copy(context, device, host, 64, 1) != 0 ||
      neurx_device_synchronize(context, stream) != 0 ||
      neurx_device_stream_destroy(context, stream) != 0 ||
      neurx_device_free(context, device) != 0 ||
      neurx_device_free(context, host) != 0 ||
      neurx_device_destroy(context) != 0) {
    std::cerr << "FAIL: Device ABI lifecycle: " << neurx_device_last_error(context) << '\n';
    return 1;
  }
  std::cout << "PASS: " << backend << " Device ABI lifecycle\n";
  return 0;
}
