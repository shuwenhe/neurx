#include "../../backend/api/collective_abi.h"
#include <cstring>
#include <iostream>

int main() {
  if (neurx_collective_probe("invalid") != 0 ||
      std::strstr(neurx_collective_last_error(0), "unsupported") == nullptr) {
    std::cerr << "FAIL: unsupported backend must fail explicitly\n";
    return 1;
  }
  if (neurx_collective_probe("hccl") != 0 ||
      std::strstr(neurx_collective_last_error(0), "not implemented") == nullptr) {
    std::cerr << "FAIL: incomplete HCCL adapter must not report success\n";
    return 1;
  }
  int available = neurx_collective_probe("nccl");
  if (available == 0) {
    std::cout << "PASS: NCCL absence reported without simulated success: "
              << neurx_collective_last_error(0) << '\n';
    return 0;
  }
  char unique_id[NEURX_COLLECTIVE_UNIQUE_ID_HEX_CAPACITY]{};
  if (neurx_collective_get_unique_id("nccl", unique_id, sizeof(unique_id)) != 0 ||
      std::strlen(unique_id) != 256) {
    std::cerr << "FAIL: real NCCL unique id: " << neurx_collective_last_error(0) << '\n';
    return 1;
  }
  std::cout << "PASS: real NCCL library loaded and unique id generated\n";
  return 0;
}
