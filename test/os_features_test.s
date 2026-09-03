package neurx.test

use neurx.integration.os_features

func main() {
    osfi := new_os_features_integration()
    
    addr, err := osfi.allocate_memory(1024 * 1024)  
    if err == "" {
        print("✓ 虚拟内存分配成功: address = ")
        print_int(addr)
    }
    
    hp_addr, hp_err := osfi.allocate_huge_page(2097152)  
    if hp_err == "" {
        print("✓ Huge Pages 分配成功: address = ")
        print_int(hp_addr)
    }
    
    inode, fs_err := osfi.create_file("test.txt")
    if fs_err == "" {
        print("✓ 文件创建成功: inode = ")
        print_int(inode)
    }
    
    class_sz, qos_err := osfi.send_packet(0, 1024)
    if qos_err == "" {
        print("✓ QoS 数据包发送成功: size = ")
        print_int(class_sz)
    }
    
    fw_action, fw_msg := osfi.check_firewall("192.168.1.1", "10.0.0.1", 0, 80, 443)
    if fw_msg == "ACCEPT" {
        print("✓ 防火墙规则检查: ")
        print_str(fw_msg)
    }
    
    freq, freq_err := osfi.update_cpu_freq(80)
    if freq_err == "" {
        print("✓ CPU 频率更新成功: frequency = ")
        print_int(freq)
        print(" MHz")
    }
    
    compact_sz, compact_err := osfi.compact_memory(3)  
    if compact_err == "" {
        print("✓ 内存压缩成功: pages = ")
        print_int(compact_sz)
    }
    
    io_req, io_err := osfi.submit_io_request(1024, 4096, 0)  
    if io_err == "" {
        print("✓ I/O 请求提交成功: request_id = ")
        print_int(io_req)
    }
    
    task_id, sched_err := osfi.schedule_task()
    if sched_err == "" {
        print("✓ 任务调度成功: task_id = ")
        print_int(task_id)
    }
    
    vm_used, fs_used, run_tasks := osfi.get_system_stats()
    print("✓ 系统统计:")
    print("  虚拟内存已用: ")
    print_int(vm_used)
    print(" 页面")
    print("  文件系统已用: ")
    print_int(fs_used)
    print(" 块")
    print("  运行任务: ")
    print_int(run_tasks)
    print(" 个")
}

func print(string s) {
    
}

func print_int(int n) {
    
}

func print_str(string s) {
    
}
