# Callback mapping

Signatures below use `int` and `const char*` from the v1 header. Resource arguments are ignored by the unavailable foundation. Text parameters are borrowed, never read, copied, forwarded, or retained. Null text and invalid handles therefore follow the same rejection path as valid inputs.

| v1 C signature | S export |
| --- | --- |
| `int probe(void)` | `int64_t neurx_mlu_probe(void)` |
| `int create(int device_id, const char* options)` | `int64_t neurx_mlu_unavailable(void)` |
| `int destroy(int context)` | Same rejection export |
| `int alloc(int context, int bytes, const char* memory_kind)` | Same rejection export |
| `int free(int context, int buffer)` | Same rejection export |
| `int copy(int context, int destination, int source, int bytes, int direction)` | Same rejection export |
| `int stream_create(int context, int priority)` | Same rejection export |
| `int stream_destroy(int context, int stream)` | Same rejection export |
| `int op_create(int context, const char* descriptor)` | Same rejection export |
| `int op_destroy(int context, int operation)` | Same rejection export |
| `int op_launch(int context, int operation, int stream, const char* bindings)` | Same rejection export |
| `int synchronize(int context, int stream)` | Same rejection export |
| `const char* last_error(int context)` | `int64_t neurx_mlu_classify_loader(int64_t observation)` |

Probe accepts only the expected S zero result with a clear exporter error and otherwise returns `-1`. Rejections return `-1` including on S execution failure. No ABI resource values cross into S or are created. The error callback ignores the supplied context and passes a scalar loader observation to S. The adapter maps the S result to a NUL-terminated static ASCII diagnostic. No returned storage is owned by the caller. Diagnostic and backend-name pointers remain usable while the plugin is loaded. The registry copies a failed creation diagnostic into its own thread-local C++ string.
