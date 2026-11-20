#include "../../api/device_plugin_abi.h"

#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>

// S shared-library exports currently use int64_t for S int and cannot
// export a C function-pointer table or callbacks with C pointer arguments.
extern int64_t neurx_mlu_probe(void);
extern int64_t neurx_mlu_unavailable(void);
extern int64_t neurx_mlu_classify_loader(int64_t observation);
extern const char* s_abi_last_error(void);

// The hosted S interpreter resets a process-wide scheduler on entry.
static pthread_mutex_t s_mutex = PTHREAD_MUTEX_INITIALIZER;

static int call_status(int64_t (*call)(void), int expected) {
  if (pthread_mutex_lock(&s_mutex) != 0) return -1;
  int64_t status = call();
  int result = status == expected && !*s_abi_last_error() ? expected : -1;
  pthread_mutex_unlock(&s_mutex);
  return result;
}

static int probe(void) { return call_status(neurx_mlu_probe, 0); }

static int reject_handle(int handle) {
  (void)handle;
  return call_status(neurx_mlu_unavailable, -1);
}

static int reject_pair(int context, int resource) {
  (void)resource;
  return reject_handle(context);
}

static int reject_text(int handle, const char* text) {
  (void)text;
  return reject_handle(handle);
}

static int reject_alloc(int context, int bytes, const char* kind) {
  (void)bytes;
  return reject_text(context, kind);
}

static int reject_copy(int context, int destination, int source, int bytes,
                       int direction) {
  (void)destination;
  (void)source;
  (void)bytes;
  (void)direction;
  return reject_handle(context);
}

static int reject_launch(int context, int operation, int stream,
                         const char* bindings) {
  (void)operation;
  (void)stream;
  return reject_text(context, bindings);
}

// POSIX transport only. The loader handle stays in C with its original type.
static int64_t observe_cnrt_loader(void) {
  void* library = dlopen("libcnrt.so", RTLD_NOW | RTLD_LOCAL);
  if (!library) return 0;
  return dlclose(library) == 0 ? 1 : 2;
}

static const char* last_error(int context) {
  (void)context;
  int64_t observation = observe_cnrt_loader();
  if (pthread_mutex_lock(&s_mutex) != 0)
    return "MLU unavailable: S boundary lock failed";
  int64_t status = neurx_mlu_classify_loader(observation);
  if (*s_abi_last_error()) status = -1;
  pthread_mutex_unlock(&s_mutex);

  switch (status) {
    case 0: return "MLU unavailable: could not load libcnrt.so (CNRT)";
    case 1: return "MLU unavailable: CNRT library is loadable; device execution is unvalidated";
    case 2: return "MLU unavailable: CNRT loader could not release its library reference";
    default: return "MLU unavailable: S runtime classification failed";
  }
}

#ifdef NEURX_ENABLE_CNRT_DIAGNOSTIC
#include <cnrt.h>

extern int64_t neurx_mlu_classify_cnrt(int64_t observation, int64_t count);

// Optional diagnostic entry, outside Device ABI v1. Call from a dedicated
// diagnostic process. Native pointers and CNRT output arguments stay in C.
int neurx_mlu_cnrt_diagnose(unsigned int* count, uint32_t* cnrt_status) {
  if (!count || !cnrt_status) return -1;
  *count = 0;
  *cnrt_status = 0;

  int64_t observation = 0;
  void* library = dlopen("libcnrt.so", RTLD_NOW | RTLD_LOCAL);
  if (library) {
    // POSIX permits converting a dlsym result to its matching function type.
    __typeof__(&cnrtGetDeviceCount) get_count =
        (__typeof__(&cnrtGetDeviceCount))dlsym(library, "cnrtGetDeviceCount");
    observation = 3;
    if (get_count && dlsym(library, "cnrtSetDevice")) {
      unsigned int detected = 0;
      cnrtRet_t result = get_count(&detected);
      *cnrt_status = (uint32_t)result;
      observation = 4;
      if (result == cnrtSuccess) {
        *count = detected;
        observation = 5;
      }
    }
    if (dlclose(library) != 0) observation = 2;
  }

  if (pthread_mutex_lock(&s_mutex) != 0) return -1;
  int64_t status = neurx_mlu_classify_cnrt(observation, *count);
  if (*s_abi_last_error()) status = -1;
  pthread_mutex_unlock(&s_mutex);
  return status >= 0 && status <= 6 ? (int)status : -1;
}
#endif

static const neurx_device_plugin_v1 plugin = {
    .abi_version = NEURX_DEVICE_PLUGIN_ABI_VERSION,
    .struct_size = sizeof(neurx_device_plugin_v1),
    .backend_name = "mlu",
    .probe = probe,
    .create = reject_text,
    .destroy = reject_handle,
    .alloc = reject_alloc,
    .free = reject_pair,
    .copy = reject_copy,
    .stream_create = reject_pair,
    .stream_destroy = reject_pair,
    .op_create = reject_text,
    .op_destroy = reject_pair,
    .op_launch = reject_launch,
    .synchronize = reject_pair,
    .last_error = last_error,
};

const neurx_device_plugin_v1* neurx_device_plugin_get_v1(void) {
  return &plugin;
}
