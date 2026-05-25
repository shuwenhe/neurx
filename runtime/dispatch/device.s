// runtime/dispatch/device.s
// Device discovery and operator routing — analogue of Linux drivers/base/core.c
// + the kernel's bus/device model
//
// Linux maps:
//   drivers/base/core.c   → device_register(), device_unregister()
//   drivers/base/bus.c    → bus_type, driver_register()
//   kernel/resource.c     → request_resource() (claim I/O regions)
//
// NeurX maps:
//   Discovers available compute devices (CPUs, GPUs, NPUs) and routes
//   AI operators (matmul, attention, conv) to the best device.
//   Equivalent of Linux's bus→device→driver binding model.

int DEV_CPU  = 0
int DEV_GPU  = 1   // CUDA / ROCm
int DEV_NPU  = 2   // Ascend CANN, Apple ANE, Qualcomm HTP
int DEV_FPGA = 3

struct device_info {
    int    dev_id
    int    dev_type         // DEV_*
    string name             // "cpu:0", "cuda:0", "cann:0"
    int    total_mem_mb
    int    free_mem_mb
    int    compute_tflops   // INT8 TOPS * 1000 as int
    bool   available
    string driver           // "cuda", "cann", "mps", "cpu"
}

struct dispatch_state {
    []device_info devices
    int           next_dev_id
    string        default_cpu    // "cpu:0"
    string        default_gpu    // "cuda:0" or ""
}

func new_dispatch_state() -> dispatch_state {
    return dispatch_state{
        devices:     [],
        next_dev_id: 0,
        default_cpu: "cpu:0",
        default_gpu: "",
    }
}

// register_device: called by arch/ drivers on init (like device_register)
func register_device(ds dispatch_state, dev_type int, name string,
                     total_mem_mb int, compute_tflops int, driver string) -> dispatch_state {
    device_info d = device_info{
        dev_id:          ds.next_dev_id,
        dev_type:        dev_type,
        name:            name,
        total_mem_mb:    total_mem_mb,
        free_mem_mb:     total_mem_mb,
        compute_tflops:  compute_tflops,
        available:       true,
        driver:          driver,
    }
    ds.devices = append(ds.devices, d)
    ds.next_dev_id = ds.next_dev_id + 1
    if dev_type == DEV_GPU && ds.default_gpu == "" {
        ds.default_gpu = name
    }
    return ds
}

// pick_device: route an operator to the best device
// op_type: "matmul" | "attention" | "conv" | "elementwise" | "control"
// tensor_size_mb: size of the operand
func pick_device(ds dispatch_state, op_type string, tensor_size_mb int) -> (device_info, bool) {
    // control flow always on CPU
    if op_type == "control" || op_type == "scalar" {
        int i = 0
        while i < len(ds.devices) {
            if ds.devices[i].dev_type == DEV_CPU && ds.devices[i].available {
                return (ds.devices[i], true)
            }
            i = i + 1
        }
    }

    // large compute → prefer GPU/NPU
    if tensor_size_mb > 1 {
        // prefer NPU for inference ops
        if op_type == "attention" || op_type == "matmul" {
            int i = 0
            while i < len(ds.devices) {
                if (ds.devices[i].dev_type == DEV_GPU || ds.devices[i].dev_type == DEV_NPU) &&
                    ds.devices[i].available &&
                    ds.devices[i].free_mem_mb >= tensor_size_mb {
                    return (ds.devices[i], true)
                }
                i = i + 1
            }
        }
    }

    // fallback: first available CPU
    int i = 0
    while i < len(ds.devices) {
        if ds.devices[i].dev_type == DEV_CPU && ds.devices[i].available {
            return (ds.devices[i], true)
        }
        i = i + 1
    }
    return (device_info{}, false)
}

// update_free_mem: called after alloc/free on a device
func update_device_mem(ds dispatch_state, name string, delta_mb int) -> dispatch_state {
    int i = 0
    while i < len(ds.devices) {
        if ds.devices[i].name == name {
            ds.devices[i].free_mem_mb = ds.devices[i].free_mem_mb + delta_mb
        }
        i = i + 1
    }
    return ds
}
