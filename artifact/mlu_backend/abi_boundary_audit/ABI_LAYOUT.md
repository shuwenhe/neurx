# Device plugin ABI v1 layout

The contract is `backend/api/device_plugin_abi.h`. The MLU, CUDA, and CANN plugins use that type and return a pointer to a static table from the C-linkage entry `neurx_device_plugin_get_v1(void)`. MLU uses designated fields and the header's version constant. The compiler checks the callback assignments against the header prototypes.

On tested Linux x86-64, the v1 struct is 120 bytes with 8-byte alignment. The ABI test pins every offset. Version and size are unsigned 32-bit fields. Callback arguments and results of type `int` are signed 32-bit values. Data and function pointers are 64-bit on this platform. The entry and callbacks use the platform C calling convention. The S shared exports separately use signed 64-bit arguments and results.

| Offset | Field |
| ---: | --- |
| 0 | `abi_version` |
| 4 | `struct_size` |
| 8 | `backend_name` |
| 16 | `probe` |
| 24 | `create` |
| 32 | `destroy` |
| 40 | `alloc` |
| 48 | `free` |
| 56 | `copy` |
| 64 | `stream_create` |
| 72 | `stream_destroy` |
| 80 | `op_create` |
| 88 | `op_destroy` |
| 96 | `op_launch` |
| 104 | `synchronize` |
| 112 | `last_error` |

The registry loads by backend name and accepts a v1 table with a matching name and at least the known size. It checks the probe and create slots when called. Its loader does not validate every remaining callback, so the MLU test requires all 13 slots. The adapter and tests follow the existing v1 return conventions. A positive handle represents a resource, zero is successful status or unavailable probe as appropriate, and negative values represent failure.
