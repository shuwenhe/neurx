# NeurX AI 操作系统 - 完整实现计划

## 项目目标
参考 Linux 内核结构，用 S 语言在 NeurX 中实现完整的 AI 操作系统，支持：
- 高性能推理和训练
- 应用程序执行
- 多租户隔离
- GPU/硬件加速

---

## 🏗️ 核心体系结构

```
NeurX AI OS
├── 系统调用层 (syscall interface)
├── 虚拟内存系统 (VM + paging)
├── 进程管理 (fork/execve/wait)
├── 信号处理 (signals)
├── 文件系统 (tmpfs + ext-simple)
├── 网络栈 (TCP/IP complete)
├── 异常处理 (CPU exceptions)
├── 设备驱动 (char/block devices)
├── I/O 子系统 (io_uring)
└── 硬件抽象 (10+ backend platforms)
```

---

## 📋 实现阶段

### **阶段 1: 系统调用接口** (Priority P0)
**目标**: 建立用户/内核空间通信通道

#### 文件结构
```
kernel/
├── syscall/
│   ├── syscall_table.s         # 系统调用表 (300+ 调用)
│   ├── syscall_handler.s       # syscall 处理器
│   ├── syscall_entry.s         # 用户态入口点
│   ├── syscall_exit.s          # 返回用户态
│   └── syscall_numbers.s       # 调用号定义
```

#### 关键系统调用
```
文件操作:  open, close, read, write, stat, lseek, ioctl
进程:      fork, execve, exit, wait, waitpid, kill, getpid
内存:      mmap, munmap, brk, sbrk
信号:      signal, sigaction, sigprocmask
网络:      socket, connect, bind, listen, accept, send, recv
其他:      time, sleep, getuid, setuid, chdir, getcwd
```

#### 实现细节 (参考 Linux kernel/entry/)
- 用户态 -> 内核态 transition (TrapFrame)
- 参数传递 (寄存器/栈)
- 返回值处理
- 错误码 (errno)

---

### **阶段 2: 虚拟内存系统** (Priority P0)
**目标**: 支持进程隔离和内存保护

#### 文件结构
```
mm/
├── vm_core.s               # VM 核心结构
├── page_table.s            # 页表管理
├── tlb.s                   # TLB (Translation Lookaside Buffer)
├── vma.s                   # VMA (Virtual Memory Area)
├── page_fault.s            # 缺页异常处理
├── swap.s                  # Swap 交换机制
├── page_cache.s            # 页缓存
└── mmu.s                   # MMU 抽象
```

#### 关键结构 (参考 Linux mm/)
```
page_table: 4 级页表 (x86-64)
- PGD (页全局目录)
- PUD (页上级目录) 
- PMD (页中间目录)
- PTE (页表项)

vma: 虚拟内存区域
- 起始地址、大小
- 权限 (rwx)
- 标志 (MAP_SHARED, MAP_PRIVATE)
- backing file

page_cache: 内存页缓存
- 页哈希表
- LRU 链表
- dirty 页面跟踪
```

#### 实现步骤
1. 基本页表管理 (alloc/free)
2. VMA 管理 (分配、合并)
3. 缺页处理 (on-demand allocation)
4. 页面写回 (writeback)
5. Swap 机制 (overflow handling)

---

### **阶段 3: 进程生命周期** (Priority P0)
**目标**: 完整的进程创建、运行、退出

#### 文件结构
```
kernel/process/
├── fork.s                  # fork 系统调用
├── execve.s                # execve 程序加载
├── exit.s                  # exit 进程退出
├── wait.s                  # wait/waitpid
├── task_struct.s           # 任务结构扩展
├── mm_struct.s             # 内存上下文
├── fs_struct.s             # 文件系统上下文
└── signal_struct.s         # 信号处理上下文
```

#### fork() 实现逻辑
```
1. 复制父进程的 task_struct
2. 复制 mm_struct (页表)
3. 复制文件描述符表
4. 复制信号处理器
5. 分配新 PID
6. 将子进程加入调度器
7. 返回: 父进程得 child_pid, 子进程得 0
```

#### execve() 实现逻辑
```
1. 验证文件可执行性
2. 清空旧 mm_struct
3. 解析 ELF 头
4. 加载代码段、数据段
5. 设置堆栈 (argc, argv, envp)
6. 重置信号处理器
7. 跳转到入口点
```

---

### **阶段 4: 信号处理** (Priority P1)
**目标**: 进程间异步通信

#### 文件结构
```
kernel/signal/
├── signal.s                # 信号处理核心
├── sigaction.s             # sigaction 系统调用
├── sigprocmask.s           # 信号掩码
├── signal_deliver.s        # 信号传递
├── signal_handlers.s       # 默认处理器
└── siginfo.s               # 信号信息
```

#### 关键信号
```
SIGTERM (15):    进程终止
SIGKILL (9):     强制杀死
SIGSTOP (19):    暂停进程
SIGCONT (18):    继续进程
SIGCHLD (17):    子进程退出
SIGSEGV (11):    段错误
SIGFPE  (8):     浮点异常
SIGINT  (2):     中断 (Ctrl+C)
```

#### 信号处理流程
```
1. 信号触发 (来自 OS 或其他进程)
2. 将信号加入 pending 队列
3. 进程返回用户态时检查 pending
4. 调用已注册的处理器
5. 恢复进程执行
```

---

### **阶段 5: 文件系统** (Priority P1)
**目标**: 数据持久化和设备访问

#### 文件结构
```
fs/
├── vfs_core.s              # VFS 改进版
├── tmpfs.s                 # 内存文件系统
├── ext_simple.s            # 简化的 ext4
├── file_ops.s              # 文件操作
├── inode_ops.s             # inode 操作
├── dentry_ops.s            # dentry 操作
├── namei.s                 # 路径名解析 (参考 Linux)
└── mount.s                 # 挂载系统
```

#### tmpfs 实现 (快速实现)
```
特点: 内存中, 快速, 临时
结构:
- inode 树
- 内存页面存储
- 简单的权限系统

支持操作:
- 创建/删除文件
- 读/写文件
- 目录操作
- 符号链接
```

#### ext_simple 实现
```
特点: 磁盘持久化, 简化版
结构:
- Superblock (文件系统元数据)
- Inode 表
- Block bitmap
- Inode bitmap
- Data blocks

支持操作:
- 基本的读/写
- 目录
- 软链接
```

---

### **阶段 6: 网络栈完整性** (Priority P2)
**目标**: 完整的网络通信

#### 文件结构
```
net/
├── tcp/
│   ├── tcp_core_enhanced.s # 改进的 TCP
│   ├── tcp_states.s        # 状态机细化
│   ├── tcp_timer.s         # 超时管理
│   └── congestion.s        # 拥塞控制
├── udp/
│   ├── udp_core.s          # UDP 实现
│   └── udp_socket.s        # UDP socket
├── ipv4/
│   ├── ip_forward.s        # IP 转发
│   ├── routing.s           # 路由表
│   ├── icmp.s              # ICMP (ping)
│   └── arp.s               # ARP 协议
└── common/
    ├── netfilter.s         # 包过滤
    └── packet_queue.s      # 包队列
```

#### TCP 状态机完整化
```
当前: CLOSED → LISTEN → ESTABLISHED → CLOSED
改进:
- LISTEN 状态优化
- TIME_WAIT 处理
- FIN_WAIT 状态
- CLOSE_WAIT 状态
- RST 处理
```

---

### **阶段 7: 异常处理** (Priority P2)
**目标**: CPU 异常捕获和处理

#### 文件结构
```
kernel/exceptions/
├── idt.s                   # IDT (Interrupt Descriptor Table)
├── exception_handlers.s    # 异常处理器
├── page_fault.s            # 缺页异常
├── divide_by_zero.s        # 除零异常
├── segmentation_fault.s    # 段错误
├── invalid_opcode.s        # 非法指令
└── hardware_interrupt.s    # 硬件中断
```

#### 关键异常 (参考 Linux arch/x86/)
```
0x0:  Division by zero
0x1:  Debug
0x3:  Breakpoint
0x4:  Overflow
0x5:  Bound range exceeded
0x6:  Invalid opcode
0xE:  Page fault ← 最重要
0x11: Alignment check
0x13: General protection fault
```

---

### **阶段 8: 设备驱动层** (Priority P2)
**目标**: 字符/块设备支持

#### 文件结构
```
drivers/
├── char_dev.s             # 字符设备层
├── block_dev_enhanced.s   # 块设备层改进
├── device_manager.s       # 设备管理器
├── tty/
│   ├── console.s          # 控制台
│   ├── serial.s           # 串行端口
│   └── terminal.s         # 终端模拟
└── device_nodes.s         # /dev 节点管理
```

---

## 📁 文件组织 (参考 Linux)

```
neurx/
├── kernel/
│   ├── entry/              # 入口点 (arch-specific)
│   ├── syscall/            # ← NEW: 系统调用
│   ├── signal/             # ← NEW: 信号
│   ├── exception/          # ← NEW: 异常处理
│   ├── process/            # ← ENHANCE: 进程扩展
│   └── sched/              # 任务调度
│
├── mm/                      # ← NEW: 虚拟内存
│   ├── vm_core.s
│   ├── page_table.s
│   ├── page_fault.s
│   └── swap.s
│
├── fs/                      # ← ENHANCE: 文件系统
│   ├── vfs_core.s
│   ├── tmpfs.s
│   ├── ext_simple.s
│   └── namei.s
│
├── net/                     # ← ENHANCE: 网络
│   ├── tcp/
│   ├── udp/
│   ├── ipv4/
│   └── common/
│
├── drivers/                 # ← ENHANCE: 设备
│   ├── char_dev.s
│   ├── block_dev_enhanced.s
│   └── tty/
│
└── init/                    # ← ENHANCE: 启动
    ├── main.s
    ├── syscall_init.s
    ├── vm_init.s
    └── fs_init.s
```

---

## 🔄 实现顺序

### **第 1 周**: 系统调用框架
- [ ] 系统调用表设计
- [ ] 系统调用处理器
- [ ] 基础 8 个系统调用
- [ ] 测试框架

### **第 2 周**: 虚拟内存
- [ ] 页表数据结构
- [ ] MMU 抽象
- [ ] 缺页处理
- [ ] mmap/munmap

### **第 3 周**: 进程生命周期
- [ ] fork 实现
- [ ] execve 实现
- [ ] wait 实现
- [ ] 进程表管理

### **第 4 周**: 信号 + 文件系统
- [ ] 信号框架
- [ ] tmpfs 完整实现
- [ ] 基本文件操作
- [ ] 路径名解析

### **第 5 周**: 网络 + 异常
- [ ] TCP/UDP 完整实现
- [ ] 异常处理器
- [ ] 中断处理
- [ ] 集成测试

---

## 🧪 测试计划

### 单元测试
```
test/
├── syscall/
├── vm/
├── process/
├── signal/
├── filesystem/
├── network/
└── exceptions/
```

### 集成测试
```
测试场景:
1. 启动 shell 程序
2. fork 创建子进程
3. 加载并执行 ELF 二进制
4. 多进程并发
5. 网络通信
6. 文件 I/O
```

### 性能基准
```
指标:
- 系统调用开销 (< 1μs)
- fork 延迟 (< 10ms)
- 页表查询 (< 100ns)
- 网络吞吐 (> 1Gbps)
```

---

## 📊 关键数据结构

### syscall_table
```
[300+ entries]
num -> (handler_func, arg_count, name)
```

### task_struct 扩展
```
mm_struct:      页表、VMA、堆栈
fs_struct:      根目录、工作目录、文件表
signal_struct:  信号处理器、掩码、待处理
files_struct:   文件描述符数组 (max 1024)
```

### vma (Virtual Memory Area)
```
start, end:     地址范围
prot:           PROT_READ/WRITE/EXEC
flags:          MAP_SHARED/PRIVATE
file:           关联的文件
offset:         文件偏移
```

---

## 🎯 里程碑

- **M1**: 系统调用框架 + 基础 10 个调用 (2 周)
- **M2**: 虚拟内存 + fork/execve (3 周)
- **M3**: 文件系统 + 信号 (2 周)
- **M4**: 网络完整 + 异常处理 (2 周)
- **M5**: 集成测试 + 性能优化 (1 周)

**总计**: ~10 周到达 MVP (Minimal Viable Product)

---

## 📚 参考资源

- Linux 内核: kernel/ 目录
- 书籍: "Understanding the Linux Kernel" (针对具体组件)
- Architecture-specific: arch/x86/entry/ (中断/异常处理)
