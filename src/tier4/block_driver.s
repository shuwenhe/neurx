package neurx.tier4.block_driver

const int BLOCK_DEVICE_HDD = 0
const int BLOCK_DEVICE_SSD = 1
const int BLOCK_DEVICE_NVME = 2
const int BLOCK_DEVICE_MMC = 3

struct block_request {
    int req_id
    int op_type         
    int device_id
    int sector          
    int sector_count    
    vec data
    int priority        
    int status          
    int result
}

struct block_device {
    int device_id
    int device_type
    int major           
    int minor           
    int total_sectors
    int sector_size
    vec request_queue   
    int queue_depth
    int pending_count
    int completed_count
}

struct driver_module {
    int module_id
    int type            
    int vendor_id
    int device_id
    int state           
    int ref_count       
}

struct block_manager {
    vec devices         
    vec request_queue   
    int device_counter
    int req_counter
    int scheduler_type  
}

struct driver_manager {
    vec modules
    vec devices
    int module_counter
    int device_counter
}

func block_init(queue_depth int) (block_manager, string) {
    manager := block_manager{
        devices: {},
        request_queue: {},
        device_counter: 0,
        req_counter: 0,
        scheduler_type: 1  
    }
    
    return manager, ""
}

func (manager* block_manager) register_device(device_type int, total_sectors int) (int, string) {
    device := block_device{
        device_id: manager.device_counter,
        device_type: device_type,
        major: 8,  
        minor: manager.device_counter * 16,
        total_sectors: total_sectors,
        sector_size: 4096,
        request_queue: {},
        queue_depth: 32,
        pending_count: 0,
        completed_count: 0
    }
    
    manager.devices = append(manager.devices, device)
    manager.device_counter = manager.device_counter + 1
    
    return device.device_id, ""
}

func (manager* block_manager) submit_request(device_id int, op_type int, sector int, count int, data vec) (int, string) {
    if device_id >= len(manager.devices) {
        return -1, "device not found"
    }
    
    device := manager.devices[device_id]
    
    if device.pending_count >= device.queue_depth {
        return -1, "queue full"
    }
    
    req := block_request{
        req_id: manager.req_counter,
        op_type: op_type,
        device_id: device_id,
        sector: sector,
        sector_count: count,
        data: data,
        priority: 0,
        status: 0,
        result: 0
    }
    
    device.request_queue = append(device.request_queue, req)
    device.pending_count = device.pending_count + 1
    manager.request_queue = append(manager.request_queue, req)
    manager.req_counter = manager.req_counter + 1
    
    manager.devices[device_id] = device
    
    return req.req_id, ""
}

func (manager* block_manager) complete_request(device_id int, req_id int, result int) (int, string) {
    if device_id >= len(manager.devices) {
        return -1, "device not found"
    }
    
    device := manager.devices[device_id]
    
    
    i := 0
    for i < len(device.request_queue) {
        req := device.request_queue[i]
        if req.req_id == req_id {
            req.status = 1  
            req.result = result
            device.request_queue[i] = req
            device.pending_count = device.pending_count - 1
            device.completed_count = device.completed_count + 1
            break
        }
        i = i + 1
    }
    
    manager.devices[device_id] = device
    return result, ""
}

func (manager* block_manager) read_blocks(device_id int, sector int, count int) (vec, string) {
    if device_id >= len(manager.devices) {
        return {}, "device not found"
    }
    
    data := {}
    
    
    i := 0
    for i < count * 16 {  
        data = append(data, (sector + i) & 0xff)
        i = i + 1
    }
    
    return data, ""
}

func (manager* block_manager) write_blocks(device_id int, sector int, data vec) (int, string) {
    if device_id >= len(manager.devices) {
        return -1, "device not found"
    }
    
    count := len(data) / 4096
    if len(data) % 4096 != 0 {
        count = count + 1
    }
    
    return count, ""
}

func (manager* block_manager) flush_cache(device_id int) (int, string) {
    if device_id >= len(manager.devices) {
        return -1, "device not found"
    }
    
    return 0, ""
}

struct block_info {
    int device_id
    int device_type
    int major
    int minor
    int total_sectors
    int pending_requests
    int completed_requests
}

func (manager* block_manager) get_device_info(device_id int) (block_info, string) {
    if device_id >= len(manager.devices) {
        return block_info{}, "device not found"
    }
    
    device := manager.devices[device_id]
    info := block_info{
        device_id: device.device_id,
        device_type: device.device_type,
        major: device.major,
        minor: device.minor,
        total_sectors: device.total_sectors,
        pending_requests: device.pending_count,
        completed_requests: device.completed_count
    }
    
    return info, ""
}

func driver_init() (driver_manager, string) {
    manager := driver_manager{
        modules: {},
        devices: {},
        module_counter: 0,
        device_counter: 0
    }
    
    return manager, ""
}

func (manager* driver_manager) load_module(module_type int, vendor_id int, device_id int) (int, string) {
    module := driver_module{
        module_id: manager.module_counter,
        type: module_type,
        vendor_id: vendor_id,
        device_id: device_id,
        state: 2,  
        ref_count: 0
    }
    
    manager.modules = append(manager.modules, module)
    manager.module_counter = manager.module_counter + 1
    
    return module.module_id, ""
}

func (manager* driver_manager) unload_module(module_id int) (int, string) {
    if module_id >= len(manager.modules) {
        return -1, "module not found"
    }
    
    module := manager.modules[module_id]
    
    if module.ref_count > 0 {
        return -1, "module in use"
    }
    
    module.state = 0  
    manager.modules[module_id] = module
    
    return 0, ""
}

func (manager* driver_manager) register_device(module_id int, device_name int) (int, string) {
    if module_id >= len(manager.modules) {
        return -1, "module not found"
    }
    
    module := manager.modules[module_id]
    module.ref_count = module.ref_count + 1
    manager.modules[module_id] = module
    
    return manager.device_counter, ""
}

func (manager* driver_manager) probe_device(device_id int) (int, string) {
    
    found := 0
    
    i := 0
    for i < len(manager.modules) {
        module := manager.modules[i]
        
        if module.vendor_id == (device_id >> 16) {
            if module.device_id == (device_id & 0xffff) {
                found = 1
                break
            }
        }
        i = i + 1
    }
    
    if found == 1 {
        return module_id, ""
    }
    
    return -1, "device not supported"
}

func (manager* driver_manager) bind_irq_handler(module_id int, irq_num int) (int, string) {
    if module_id >= len(manager.modules) {
        return -1, "module not found"
    }
    
    return 0, ""
}

struct driver_stats {
    int total_modules
    int loaded_modules
    int total_devices
}

func (manager* driver_manager) get_stats() (driver_stats, string) {
    loaded := 0
    i := 0
    for i < len(manager.modules) {
        module := manager.modules[i]
        if module.state == 2 {
            loaded = loaded + 1
        }
        i = i + 1
    }
    
    stats := driver_stats{
        total_modules: len(manager.modules),
        loaded_modules: loaded,
        total_devices: manager.device_counter
    }
    
    return stats, ""
}
