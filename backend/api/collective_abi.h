#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

#define NEURX_COLLECTIVE_ABI_VERSION 1
#define NEURX_COLLECTIVE_UNIQUE_ID_HEX_CAPACITY 257

enum neurx_collective_dtype {
  NEURX_COLLECTIVE_FLOAT32 = 0,
  NEURX_COLLECTIVE_FLOAT16 = 1,
  NEURX_COLLECTIVE_BFLOAT16 = 2,
  NEURX_COLLECTIVE_INT32 = 3,
  NEURX_COLLECTIVE_INT64 = 4
};

enum neurx_collective_reduce_op {
  NEURX_COLLECTIVE_SUM = 0,
  NEURX_COLLECTIVE_PRODUCT = 1,
  NEURX_COLLECTIVE_MAX = 2,
  NEURX_COLLECTIVE_MIN = 3,
  NEURX_COLLECTIVE_AVERAGE = 4
};

int neurx_collective_probe(const char* backend);
int neurx_collective_get_unique_id(const char* backend, char* output_hex,
                                   int output_capacity);
int neurx_collective_init_rank(const char* backend, int rank, int world_size,
                               int device_id, const char* unique_id_hex);
int neurx_collective_destroy(int communicator);
int neurx_collective_all_reduce(int communicator, uint64_t send_buffer,
                                uint64_t receive_buffer, int64_t count,
                                int dtype, int operation, uint64_t stream);
int neurx_collective_all_gather(int communicator, uint64_t send_buffer,
                                uint64_t receive_buffer, int64_t send_count,
                                int dtype, uint64_t stream);
int neurx_collective_reduce_scatter(int communicator, uint64_t send_buffer,
                                    uint64_t receive_buffer, int64_t receive_count,
                                    int dtype, int operation, uint64_t stream);
int neurx_collective_send(int communicator, uint64_t send_buffer, int64_t count,
                          int dtype, int peer, uint64_t stream);
int neurx_collective_recv(int communicator, uint64_t receive_buffer, int64_t count,
                          int dtype, int peer, uint64_t stream);
int neurx_collective_synchronize(int communicator, uint64_t stream);
int neurx_collective_async_error(int communicator);
const char* neurx_collective_last_error(int communicator);

#ifdef __cplusplus
}
#endif
