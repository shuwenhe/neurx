#pragma once

#include "../../inference/runtime/backends/backend_adapter.h"

#include <cstdint>

extern "C" {

struct neurx_cann_operator_status {
  int32_t code;
  const char* message;
};

uint32_t neurx_cann_operator_abi_version();
neurx_cann_operator_status neurx_cann_prefill(
    const neurx::inference::device_batch& batch);
neurx_cann_operator_status neurx_cann_decode(
    const neurx::inference::device_batch& batch);

}
