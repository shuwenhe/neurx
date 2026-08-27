package neurx.test

use neurx.integration.os_features_tier2_integration


func main() {
    osfi2 := new_os_features_tier2_integration()
    
    
    
    
    sem, sem_err := osfi2.create_semaphore(5)
    if sem_err == "" {
        print("✓ 信号量创建成功: sem_id = ")
        print_int(sem.sem_id)
    }
    
    wait_result, wait_err := osfi2.wait_semaphore(0, 100)
    if wait_err == "" {
        print("✓ 信号量 P 操作成功")
    }
    
    sig_result, sig_err := osfi2.signal_semaphore(0)
    if sig_err == "" {
        print("✓ 信号量 V 操作成功")
    }
    
    
    
    
    mq, mq_err := osfi2.create_message_queue(10)
    if mq_err == "" {
        print("✓ 消息队列创建成功: queue_id = ")
        print_int(mq.queue_id)
    }
    
    msg_id, send_err := osfi2.send_message(0, 200, "Hello IPC", 1)
    if send_err == "" {
        print("✓ 消息发送成功: msg_id = ")
        print_int(msg_id)
    }
    
    
    
    
    shm, shm_err := osfi2.create_shared_memory(4096)
    if shm_err == "" {
        print("✓ 共享内存创建成功: shmid = ")
        print_int(shm.shmid)
    }
    
    attach_result, attach_err := osfi2.attach_shared_memory(0)
    if attach_err == "" {
        print("✓ 共享内存挂载成功")
    }
    
    
    
    
    reg_result, reg_err := osfi2.register_signal_pid(300)
    if reg_err == "" {
        print("✓ 信号处理器注册成功: pid = 300")
    }
    
    handler_result, handler_err := osfi2.set_signal_handler(15, 1)  
    if handler_err == "" {
        print("✓ 信号处理器设置成功")
    }
    
    signal_result, signal_err := osfi2.send_signal(100, 300, 15)
    if signal_err == "" || signal_err == "SIGNAL_BLOCKED" {
        print("✓ 信号发送成功: result = ")
        print_str(signal_err)
    }
    
    
    
    
    irq_result, irq_err := osfi2.register_irq(5, 10)
    if irq_err == "" {
        print("✓ 中断处理器注册成功: irq = 5")
    }
    
    handle_result, handle_err := osfi2.handle_interrupt(5)
    if handle_err == "" {
        print("✓ 中断处理成功")
    }
    
    
    
    
    timer_result, timer_err := osfi2.create_timer(400, 1000, 500)
    if timer_err == "" {
        print("✓ 定时器创建成功: timer_id = ")
        print_int(timer_result.timer_id)
    }
    
    
    
    
    wq, wq_err := osfi2.create_workqueue(4)
    if wq_err == "" {
        print("✓ 工作队列创建成功: queue_id = ")
        print_int(wq.queue_id)
    }
    
    work_id, work_err := osfi2.queue_work(0, 5)
    if work_err == "" {
        print("✓ 工作项队列成功: work_id = ")
        print_int(work_id)
    }
    
    
    
    
    swap_dev, swap_err := osfi2.create_swap_device(1024)  
    if swap_err == "" {
        print("✓ Swap 设备创建成功: device_id = ")
        print_int(swap_dev.device_id)
    }
    
    swap_out_result, swap_out_err := osfi2.swap_out_page(1000, 0)
    if swap_out_err == "" {
        print("✓ Swap Out 成功: offset = ")
        print_int(swap_out_result)
    }
    
    
    
    
    local_result, local_err := osfi2.allocate_local(0, 512)
    if local_err == "" {
        print("✓ NUMA 本地分配成功: node = ")
        print_int(local_result)
    }
    
    migrate_result, migrate_err := osfi2.migrate_page(0, 1)
    if migrate_err == "" {
        print("✓ 页面迁移成功")
    }
    
    
    
    
    oom_reg, oom_reg_err := osfi2.register_process_memory(500, 1024)
    if oom_reg_err == "" {
        print("✓ 进程内存注册成功: pid = 500")
    }
    
    oom_check, oom_check_err := osfi2.check_oom(3000)  
    if oom_check_err == "" || oom_check_err != "No OOM" {
        print("✓ OOM 检查完成")
    }
    
    
    
    
    vm_u, fs_u, tasks, swap_u, timers, killed := osfi2.get_system_stats_tier2()
    print("✓ 系统统计 (Tier 2):")
    print("  虚拟内存已用: ")
    print_int(vm_u)
    print("  文件系统已用: ")
    print_int(fs_u)
    print("  运行任务: ")
    print_int(tasks)
    print("  Swap 已用: ")
    print_int(swap_u)
    print(" MB")
    print("  活跃定时器: ")
    print_int(timers)
    print("  OOM 杀死: ")
    print_int(killed)
    print(" 个进程")
}


func print(string s) {
    
}

func print_int(int n) {
    
}

func print_str(string s) {
    
}
