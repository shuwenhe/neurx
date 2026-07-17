#pragma once

#include "../../inference/runtime/backends/backend_adapter.h"

#include <cstdint>

// Stable boundary between the generic executor and operators compiled with the
// exact CANN toolkit installed in the target image.
extern "C" {

uint32_t neurx_cann_operator_abi_version();
neurx::inference::AdapterStatus neurx_cann_prefill(
    const neurx::inference::DeviceBatch& batch);
neurx::inference::AdapterStatus neurx_cann_decode(
    const neurx::inference::DeviceBatch& batch);

}
