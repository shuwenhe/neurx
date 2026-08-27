package neurx.test

use neurx.integration.os_features

// 测试所有操作系统功能
func main() {
    osfi := new_os_features_integration()
    
    // 测试 1: 虚拟内存分配
    addr, err := osfi.allocate_memory(1024 * 1024)  // 1MB
    if err == "" {
        print("✓ 虚拟内存分配成功: address = ")
        print_int(addr)
    }
    
    // 测试 2: Huge Pages 分配
    hp_addr, hp_err := osfi.allocate_huge_page(2097152)  // 2MB Huge Page
    if hp_err == "" {
        print("✓ Huge Pages 分配成功: address = ")
        print_int(hp_addr)
    }
    
    // 测试 3: 文件创建
    inode, fs_err := osfi.create_file("test.txt")
    if fs_err == "" {
        print("✓ 文件创建成功: inode = ")
        print_int(inode)
    }
    
    // 测试 4: QoS 数据包发送
    class_sz, qos_err := osfi.send_packet(0, 1024)
    if qos_err == "" {
        print("✓ QoS 数据包发送成功: size = ")
        print_int(class_sz)
    }
    
    // 测试 5: 防火墙检查
    fw_action, fw_msg := osfi.check_firewall("192.168.1.1", "10.0.0.1", 0, 80, 443)
    if fw_msg == "ACCEPT" {
        print("✓ 防火墙规则检查: ")
        print_str(fw_msg)
    }
    
    // 测试 6: CPU 频率更新 (80% 负载)
    freq, freq_err := osfi.update_cpu_freq(80)
    if freq_err == "" {
        print("✓ CPU 频率更新成功: frequency = ")
        print_int(freq)
        print(" MHz")
    }
    
    // 测试 7: 内存压缩
    compact_sz, compact_err := osfi.compact_memory(3)  // 8 页
    if compact_err == "" {
        print("✓ 内存压缩成功: pages = ")
        print_int(compact_sz)
    }
    
    // 测试 8: I/O 请求提交
    io_req, io_err := osfi.submit_io_request(1024, 4096, 0)  // 读请求
    if io_err == "" {
        print("✓ I/O 请求提交成功: request_id = ")
        print_int(io_req)
    }
    
    // 测试 9: 任务调度
    task_id, sched_err := osfi.schedule_task()
    if sched_err == "" {
        print("✓ 任务调度成功: task_id = ")
        print_int(task_id)
    }
    
    // 测试 10: 系统统计
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

// 辅助函数
func print(string s) {
    // 打印字符串
}

func print_int(int n) {
    // 打印整数
}

func print_str(string s) {
    // 打印字符串
}
