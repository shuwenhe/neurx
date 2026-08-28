package neurx.integration

use neurx.mm.vm_subsystem
use neurx.mm.huge_pages
use neurx.fs.ext4
use neurx.net.qos_netfilter
use neurx.driver.cpufreq
use neurx.mm.compaction_io
use neurx.kernel.cpu_scheduling

struct os_features_integration {
    vm_manager vm_manager
    huge_pages_pool huge_pages_pool
    ext4_fs ext4_fs
    qos_manager qos_manager
    netfilter netfilter
    cpufreq_driver cpufreq_driver
    memory_compactor memory_compactor
    io_scheduler io_scheduler
    page_cache page_cache
    cpu_scheduler cpu_scheduler
}

func new_os_features_integration() os_features_integration {
    osfi := os_features_integration{}
    
    
    osfi.vm_manager.init(4 * 1024 * 1024 * 1024)
    
    
    osfi.huge_pages_pool.init(1000, 100)
    
    
    osfi.ext4_fs.init(100 * 1024 * 1024 * 1024)
    
    
    osfi.qos_manager.init(10)
    
    
    osfi.netfilter.init()
    
    
    osfi.cpufreq_driver.init(0)
    osfi.cpufreq_driver.create_ondemand_governor(800, 2400)
    osfi.cpufreq_driver.set_governor(0)
    
    
    osfi.memory_compactor.init(4 * 1024 * 1024 * 1024)
    
    
    osfi.io_scheduler.init(64)
    
    
    osfi.page_cache.init(1024 * 1024 * 1024)
    
    
    osfi.cpu_scheduler.init(8)
    
    return osfi
}

func (osfi* os) allocate_memory(int size) (int, string) {
    area, err := osfi.vm_manager.allocate_area(size)
    if err != "" {
        return 0, err
    }
    return area.vm_start, ""
}

func (osfi* os) allocate_huge_page(int size) (int, string) {
    if size == 2097152 {
        hp, err := osfi.huge_pages_pool.allocate_2mb()
        if err != "" {
            return 0, err
        }
        return hp.base_address, ""
    } else if size == 1073741824 {
        hp, err := osfi.huge_pages_pool.allocate_1gb()
        if err != "" {
            return 0, err
        }
        return hp.base_address, ""
    }
    return 0, "Invalid huge page size"
}

func (osfi* os) create_file(string filename) (int, string) {
    inode, err := osfi.ext4_fs.create_file(filename, 33188)
    if err != "" {
        return 0, err
    }
    return inode.inode_num, ""
}

func (osfi* os) send_packet(int class_id, int size) (int, string) {
    return osfi.qos_manager.send_packet(class_id, size)
}

func (osfi* os) check_firewall(string src_ip, string dst_ip, int protocol, int src_port, int dst_port) (int, string) {
    return osfi.netfilter.check_packet(src_ip, dst_ip, protocol, src_port, dst_port)
}

func (osfi* os) update_cpu_freq(int cpu_load) (int, string) {
    return osfi.cpufreq_driver.update_frequency(cpu_load)
}

func (osfi* os) compact_memory(int order) (int, string) {
    return osfi.memory_compactor.compact_memory(order)
}

func (osfi* os) submit_io_request(int sector, int size, int io_type) (int, string) {
    req, err := osfi.io_scheduler.submit_request(sector, size, io_type, 0)
    if err != "" {
        return 0, err
    }
    return req.request_id, ""
}

func (osfi* os) schedule_task() (int, string) {
    t, err := osfi.cpu_scheduler.schedule()
    if err != "" {
        return 0, err
    }
    return t.task_id, ""
}

func (osfi os) get_system_stats() (int, int, int) {
    vm_used := osfi.vm_manager.total_pages - osfi.vm_manager.free_pages
    fs_used, fs_free, _ := osfi.ext4_fs.get_stats()
    run_tasks, _ := osfi.cpu_scheduler.get_stats()
    
    return vm_used, fs_used, run_tasks
}
