package neurx.mm

use std.slices


struct swap_page {
    int page_id
    int physical_address
    int swap_offset
    int flags  
}


struct swap_device {
    int device_id
    int size  
    int used_space  
    int free_space  
    swap_page[] swap_pages
}


struct swap_manager {
    swap_device[] swap_devices
    int total_swap_space
    int used_swap_space
    int swap_operations
}


func (swap_manager* swm) init(int total_swap_mb) (int, string) {
    swm.swap_devices = swap_device[]{}
    swm.total_swap_space = total_swap_mb
    swm.used_swap_space = 0
    swm.swap_operations = 0
    return 0, ""
}


func (swap_manager* swm) create_swap_device(int size_mb) (swap_device, string) {
    if swm.used_swap_space + size_mb > swm.total_swap_space {
        return swap_device{}, "Not enough swap space"
    }
    
    device := swap_device{
        device_id: len(swm.swap_devices),
        size: size_mb,
        used_space: 0,
        free_space: size_mb,
        swap_pages: swap_page[]{}
    }
    
    swm.swap_devices = append(swm.swap_devices, device)
    swm.used_swap_space = swm.used_swap_space + size_mb
    
    return device, ""
}


func (swap_manager* swm) swap_out_page(int page_id, int device_id) (int, string) {
    if device_id >= len(swm.swap_devices) {
        return -1, "Invalid device"
    }
    
    device := swm.swap_devices[device_id]
    
    if device.free_space <= 0 {
        return -1, "Swap device full"
    }
    
    swap_pg := swap_page{
        page_id: page_id,
        physical_address: 0,
        swap_offset: device.used_space,
        flags: 1  
    }
    
    device.swap_pages = append(device.swap_pages, swap_pg)
    device.used_space = device.used_space + 1
    device.free_space = device.free_space - 1
    
    swm.swap_devices[device_id] = device
    swm.swap_operations = swm.swap_operations + 1
    
    return swap_pg.swap_offset, ""
}


func (swap_manager* swm) swap_in_page(int page_id, int device_id) (int, string) {
    if device_id >= len(swm.swap_devices) {
        return -1, "Invalid device"
    }
    
    device := swm.swap_devices[device_id]
    
    i := 0
    for i < len(device.swap_pages) {
        pg := device.swap_pages[i]
        if pg.page_id == page_id {
            pg.flags = 0  
            device.used_space = device.used_space - 1
            device.free_space = device.free_space + 1
            
            
            j := i
            for j < len(device.swap_pages) - 1 {
                device.swap_pages[j] = device.swap_pages[j + 1]
                j = j + 1
            }
            
            swm.swap_devices[device_id] = device
            swm.swap_operations = swm.swap_operations + 1
            
            return pg.physical_address, ""
        }
        i = i + 1
    }
    
    return -1, "Page not found in swap"
}


func (swap_manager swm) get_swap_stats() (int, int, int) {
    return swm.total_swap_space, swm.used_swap_space, swm.swap_operations
}


struct numa_node {
    int node_id
    int total_memory  
    int free_memory   
    int cpu_count
    int distance_to_other_nodes  
}


struct numa_manager {
    vec nodes
    int num_nodes
}


func (numa_manager* nm) init(int num_nodes) (int, string) {
    nm.nodes = numa_node[]{}
    nm.num_nodes = num_nodes
    
    i := 0
    for i < num_nodes {
        node := numa_node{
            node_id: i,
            total_memory: 4096,  
            free_memory: 4096,
            cpu_count: 4,
            distance_to_other_nodes: 10
        }
        nm.nodes = append(nm.nodes, node)
        i = i + 1
    }
    
    return 0, ""
}


func (numa_manager* nm) allocate_local(int node_id, int size_mb) (int, string) {
    if node_id >= nm.num_nodes {
        return -1, "Invalid node"
    }
    
    node := nm.nodes[node_id]
    
    if node.free_memory < size_mb {
        return -1, "Not enough memory on node"
    }
    
    node.free_memory = node.free_memory - size_mb
    nm.nodes[node_id] = node
    
    return node_id, ""
}


func (numa_manager* nm) migrate_page(int from_node, int to_node) (int, string) {
    if from_node >= nm.num_nodes || to_node >= nm.num_nodes {
        return -1, "Invalid node"
    }
    
    from := nm.nodes[from_node]
    to := nm.nodes[to_node]
    
    if to.free_memory <= 0 {
        return -1, "Target node memory full"
    }
    
    from.free_memory = from.free_memory + 1
    to.free_memory = to.free_memory - 1
    
    nm.nodes[from_node] = from
    nm.nodes[to_node] = to
    
    return 0, ""
}


func (numa_manager nm) get_node_stats(int node_id) (int, int, int) {
    if node_id >= nm.num_nodes {
        return 0, 0, 0
    }
    
    node := nm.nodes[node_id]
    return node.total_memory, node.free_memory, node.cpu_count
}


struct oom_victim {
    int pid
    int memory_usage  
    int priority
    int oom_score
}


struct oom_manager {
    vec processes
    int memory_threshold  
    int killed_processes
}


func (oom_manager* om) init(int memory_threshold_mb) (int, string) {
    om.processes = process[]{}"
    om.memory_threshold = memory_threshold_mb
    om.killed_processes = 0
    return 0, ""
}


func (oom_manager* om) register_process(int pid, int memory_usage) (int, string) {
    victim := oom_victim{
        pid: pid,
        memory_usage: memory_usage,
        priority: 0,
        oom_score: 0
    }
    
    om.processes = append(om.processes, victim)
    return 0, ""
}


func (oom_manager* om) calculate_oom_score(int pid) (int, string) {
    i := 0
    for i < len(om.processes) {
        proc := om.processes[i]
        if proc.pid == pid {
            score := proc.memory_usage * 100 / om.memory_threshold
            proc.oom_score = score
            om.processes[i] = proc
            return score, ""
        }
        i = i + 1
    }
    
    return -1, "Process not found"
}


func (oom_manager* om) check_and_kill_victim(int total_memory_used) (int, string) {
    if total_memory_used < om.memory_threshold {
        return -1, "No OOM"
    }
    
    
    max_victim := -1
    max_score := 0
    
    i := 0
    for i < len(om.processes) {
        proc := om.processes[i]
        if proc.oom_score > max_score {
            max_score = proc.oom_score
            max_victim = i
        }
        i = i + 1
    }
    
    if max_victim >= 0 {
        victim := om.processes[max_victim]
        om.killed_processes = om.killed_processes + 1
        
        
        i := max_victim
        for i < len(om.processes) - 1 {
            om.processes[i] = om.processes[i + 1]
            i = i + 1
        }
        
        return victim.pid, ""
    }
    
    return -1, "No victim found"
}


func (oom_manager om) get_oom_stats() (int, int) {
    return len(om.processes), om.killed_processes
}
