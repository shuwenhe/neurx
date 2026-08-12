int DEV_CPU  = 0
int DEV_GPU  = 1
int DEV_NPU  = 2
int DEV_FPGA = 3
struct device_info {
    int    dev_id
    int    dev_type
    string name
    int    total_mem_mb
    int    free_mem_mb
    int    compute_tflops
    bool   available
    string driver
}


struct dispatch_state {
    []device_info devices
    int           next_dev_id
    string        default_cpu
    string        default_gpu
}


struct device_pick_result {
    device_info device
    bool ok
}


struct register_device_params {
    int dev_type
    string name
    int total_mem_mb
    int compute_tflops
    string driver
}


func new_dispatch_state() dispatch_state {
    return dispatch_state{
        devices:     [],
        next_dev_id: 0,
        default_cpu: "cpu:0",
        default_gpu: "",
    }
}


func register_device(ds dispatch_state, params register_device_params) dispatch_state {
    device_info d = device_info{
        dev_id:          ds.next_dev_id,
        dev_type:        params.dev_type,
        name:            params.name,
        total_mem_mb:    params.total_mem_mb,
        free_mem_mb:     params.total_mem_mb,
        compute_tflops:  params.compute_tflops,
        available:       true,
        driver:          params.driver,
    }
    ds.devices = append(ds.devices, d)
    ds.next_dev_id = ds.next_dev_id + 1
    if params.dev_type == DEV_GPU && ds.default_gpu == "" {
        ds.default_gpu = params.name
    }
    return ds
}


func pick_device(ds dispatch_state, op_type string, tensor_size_mb int) device_pick_result {
    if op_type == "control" || op_type == "scalar" {
        int i = 0
        while i < len(ds.devices) {
            if ds.devices[i].dev_type == DEV_CPU && ds.devices[i].available {
                device_pick_result result = device_pick_result{
                    device: ds.devices[i],
                    ok: true,
                }
                return result
            }
            i = i + 1
        }
    }
    if tensor_size_mb > 1 {
        if op_type == "attention" || op_type == "matmul" {
            int i = 0
            while i < len(ds.devices) {
                if ((ds.devices[i].dev_type == DEV_GPU || ds.devices[i].dev_type == DEV_NPU) &&
                    ds.devices[i].available &&
                    ds.devices[i].free_mem_mb >= tensor_size_mb) {
                    device_pick_result result = device_pick_result{
                        device: ds.devices[i],
                        ok: true,
                    }
                    return result
                }
                i = i + 1
            }
        }
    }
    int i = 0
    while i < len(ds.devices) {
        if ds.devices[i].dev_type == DEV_CPU && ds.devices[i].available {
            device_pick_result result = device_pick_result{
                device: ds.devices[i],
                ok: true,
            }
            return result
        }
        i = i + 1
    }
    device_info empty_device = device_info{
        dev_id: 0,
        dev_type: 0,
        name: "",
        total_mem_mb: 0,
        free_mem_mb: 0,
        compute_tflops: 0,
        available: false,
        driver: "",
    }
    device_pick_result failed = device_pick_result{
        device: empty_device,
        ok: false,
    }
    return failed
}


func update_device_mem(ds dispatch_state, name string, delta_mb int) dispatch_state {
    int i = 0
    while i < len(ds.devices) {
        if ds.devices[i].name == name {
            ds.devices[i].free_mem_mb = ds.devices[i].free_mem_mb + delta_mb
        }
        i = i + 1
    }
    return ds
}

