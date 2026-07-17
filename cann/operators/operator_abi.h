#pragma once

#include "../../inference/runtime/backends/backend_adapter.h"

#include <cstdint>

// Stable boundary between the generic executor and operators compiled with the
// exact CANN toolkit installed in the target image.
extern "C" {

struct NeurxCannOperatorStatus {
  int32_t code;
  const char* message;
};

uint32_t neurx_cann_operator_abi_version();
NeurxCannOperatorStatus neurx_cann_prefill(
    const neurx::inference::DeviceBatch& batch);
NeurxCannOperatorStatus neurx_cann_decode(
    const neurx::inference::DeviceBatch& batch);

}
