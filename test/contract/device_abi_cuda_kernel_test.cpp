#include "../../backend/api/device_abi.h"

#include <iostream>
#include <string>

bool linear_test(int context, int stream, const std::string& dtype) {
  const int element_bytes = dtype == "float32" ? 4 : 2;
  int input = neurx_device_alloc(context, 4 * 8 * element_bytes, "device");
  int weight = neurx_device_alloc(context, 8 * 16 * element_bytes, "device");
  int output = neurx_device_alloc(context, 4 * 16 * element_bytes, "device");
  std::string descriptor = "v1;op=linear;dtype=" + dtype + ";input=8;output=16;bias=0;lowering=cublaslt_matmul";
  int operation = neurx_device_op_create(context, descriptor.c_str());
  std::string binding = "buffer.input=" + std::to_string(input) + ";buffer.weight=" +
      std::to_string(weight) + ";buffer.bias=0;buffer.output=" + std::to_string(output) + ";rows=4";
  bool pass = input > 0 && weight > 0 && output > 0 && operation > 0 &&
      neurx_device_op_launch(context, operation, stream, binding.c_str()) == 0 &&
      neurx_device_synchronize(context, stream) == 0;
  neurx_device_op_destroy(context, operation); neurx_device_free(context, output);
  neurx_device_free(context, weight); neurx_device_free(context, input);
  return pass;
}

int main() {
  int context = neurx_device_create("cuda", 0, "{}");
  if (context <= 0) { std::cerr << neurx_device_last_error(0) << '\n'; return 1; }
  int left = neurx_device_alloc(context, 1024 * sizeof(float), "device");
  int right = neurx_device_alloc(context, 1024 * sizeof(float), "device");
  int output = neurx_device_alloc(context, 1024 * sizeof(float), "device");
  int stream = neurx_device_stream_create(context, 0);
  int operation = neurx_device_op_create(
      context, "v1;op=residual_add;dtype=float32;elements=1024;lowering=cuda_kernel");
  std::string binding = "buffer.left=" + std::to_string(left) +
      ";buffer.right=" + std::to_string(right) +
      ";buffer.output=" + std::to_string(output) + ";elements=1024";
  int launch = neurx_device_op_launch(context, operation, stream, binding.c_str());
  int synchronize = launch == 0 ? neurx_device_synchronize(context, stream) : -1;
  bool pass = left > 0 && right > 0 && output > 0 && stream > 0 && operation > 0 &&
      launch == 0 && synchronize == 0 && linear_test(context, stream, "fp16") &&
      linear_test(context, stream, "bf16");
  if (!pass) std::cerr << "FAIL: " << neurx_device_last_error(context) << '\n';
  neurx_device_op_destroy(context, operation);
  neurx_device_stream_destroy(context, stream);
  neurx_device_free(context, output);
  neurx_device_free(context, right);
  neurx_device_free(context, left);
  neurx_device_destroy(context);
  if (!pass) return 1;
  std::cout << "PASS: CUDA FP32 Kernel and FP16/BF16 cuBLASLt descriptor execution\n";
  return 0;
}
