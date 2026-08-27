.set MB2_MAGIC, 0xe85250d6
.set MB2_ARCH, 0
.set MB2_LENGTH, multiboot_header_end - multiboot_header
.set MB2_CHECKSUM, -(MB2_MAGIC + MB2_ARCH + MB2_LENGTH)

.section .multiboot2,"a"
.align 8
multiboot_header:
    .long MB2_MAGIC
    .long MB2_ARCH
    .long MB2_LENGTH
    .long MB2_CHECKSUM
    .short 0
    .short 0
    .long 8
multiboot_header_end:

.section .text.boot,"ax"
.code32
.global _start
.type _start, @function
_start:
    cli
    mov $boot_stack_top, %esp
    mov %eax, multiboot_magic
    mov %ebx, multiboot_info

    
    mov $page_table_l3, %eax
    or $3, %eax
    mov %eax, page_table_l4
    mov $page_table_l2_0, %eax
    or $3, %eax
    mov %eax, page_table_l3
    mov $page_table_l2_1, %eax
    or $3, %eax
    mov %eax, page_table_l3+8
    mov $page_table_l2_2, %eax
    or $3, %eax
    mov %eax, page_table_l3+16
    mov $page_table_l2_3, %eax
    or $3, %eax
    mov %eax, page_table_l3+24
    xor %ecx, %ecx
1:
    mov %ecx, %eax
    shl $21, %eax
    or $0x83, %eax
    mov %eax, page_table_l2_0(,%ecx,8)
    inc %ecx
    cmp $2048, %ecx
    jne 1b

    mov $page_table_l4, %eax
    mov %eax, %cr3
    mov %cr4, %eax
    or $(1 << 5), %eax
    mov %eax, %cr4
    mov $0xc0000080, %ecx
    rdmsr
    or $(1 << 8), %eax
    wrmsr
    mov %cr0, %eax
    or $(1 << 31), %eax
    mov %eax, %cr0
    lgdt gdt64_pointer
    ljmp $0x08, $long_mode_entry

.code64
long_mode_entry:
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $boot_stack_top, %rsp
    xor %rbp, %rbp
    call serial_init
    lea boot_message(%rip), %rsi
    call serial_write
    call s_fn_main
    sar $1, %rax
    test %rax, %rax
    jne boot_failed
    lea ready_message(%rip), %rsi
    call serial_write
    movw $0x2f4b, 0xb8000
    jmp halt
boot_failed:
    lea failed_message(%rip), %rsi
    call serial_write
    movw $0x4f45, 0xb8000
halt:
    cli
    hlt
    jmp halt


.global s_fn_baremetal_stage
.type s_fn_baremetal_stage, @function
s_fn_baremetal_stage:
    mov %rdi, %rax
    sar $1, %rax
    add $'0', %al
    push %rax
    lea stage_message(%rip), %rsi
    call serial_write
    pop %rax
    mov $0x3f8, %dx
    out %al, %dx
    mov $'\n', %al
    out %al, %dx
    mov $1, %rax
    ret


.global s_fn_baremetal_interrupt_init
.type s_fn_baremetal_interrupt_init, @function
s_fn_baremetal_interrupt_init:
    lea interrupt_ignore(%rip), %rax
    lea idt64(%rip), %rdi
    mov $256, %ecx
4:
    mov %ax, 0(%rdi)
    movw $0x08, 2(%rdi)
    movb $0, 4(%rdi)
    movb $0x8e, 5(%rdi)
    mov %rax, %rdx
    shr $16, %rdx
    mov %dx, 6(%rdi)
    mov %rax, %rdx
    shr $32, %rdx
    mov %edx, 8(%rdi)
    movl $0, 12(%rdi)
    add $16, %rdi
    loop 4b
    lidt idt64_pointer(%rip)
    
    mov $0x21, %dx
    mov $0xff, %al
    out %al, %dx
    mov $0xa1, %dx
    out %al, %dx
    mov $3, %rax
    ret

interrupt_ignore:
    iretq


.global s_fn_baremetal_apic_init
.type s_fn_baremetal_apic_init, @function
s_fn_baremetal_apic_init:
    mov $1, %eax
    cpuid
    test $(1 << 9), %edx
    jz 5f
    mov $0x1b, %ecx
    rdmsr
    or $(1 << 11), %eax
    wrmsr
    mov $0xfee000f0, %rdi
    movl $0x1f0, (%rdi)
    mov $3, %rax
    ret
5:
    mov $1, %rax
    ret

.global s_fn_baremetal_tss_init
.type s_fn_baremetal_tss_init, @function
s_fn_baremetal_tss_init:
    lea kernel_interrupt_stack_top(%rip), %rax
    mov %rax, tss64+4(%rip)
    mov %rax, tss64+36(%rip)
    lea tss64(%rip), %rax
    mov %rax, %rdx
    and $0xffffff, %rdx
    shl $16, %rdx
    movabs $0x0000890000000067, %rcx
    or %rcx, %rdx
    mov %rdx, gdt64+48(%rip)
    mov %rax, %rdx
    shr $24, %rdx
    and $0xff, %rdx
    shl $56, %rdx
    or %rdx, gdt64+48(%rip)
    shr $32, %rax
    mov %eax, gdt64+56(%rip)
    mov $0x30, %ax
    ltr %ax
    mov $3, %rax
    ret

.global s_fn_baremetal_apic_timer_init
.type s_fn_baremetal_apic_timer_init, @function
s_fn_baremetal_apic_timer_init:
    lea apic_timer_interrupt(%rip), %rax
    lea idt64+512(%rip), %rdi
    mov %ax, 0(%rdi)
    movw $0x08, 2(%rdi)
    movb $0, 4(%rdi)
    movb $0x8e, 5(%rdi)
    mov %rax, %rdx
    shr $16, %rdx
    mov %dx, 6(%rdi)
    shr $16, %rdx
    mov %edx, 8(%rdi)
    movl $0, 12(%rdi)
    movabs $0xfee00000, %rdi
    movl $3, 0x3e0(%rdi)
    movl $0x20020, 0x320(%rdi)
    movl $1000000, 0x380(%rdi)
    sti
    mov $3, %rax
    ret

apic_timer_interrupt:
    push %rax
    incq apic_ticks(%rip)
    movabs $0xfee00000, %rax
    movl $0, 0xb0(%rax)
    pop %rax
    iretq

.global s_fn_baremetal_memory_mib
.type s_fn_baremetal_memory_mib, @function
s_fn_baremetal_memory_mib:
    cmpl $0x36d76289, multiboot_magic(%rip)
    jne 9f
    mov multiboot_info(%rip), %edi
    lea 8(%rdi), %rsi
    mov (%rdi), %r8d
    add %rdi, %r8
    xor %r9, %r9
6:
    cmp %r8, %rsi
    jae 8f
    mov (%rsi), %eax
    mov 4(%rsi), %ecx
    cmp $6, %eax
    jne 7f
    mov 8(%rsi), %r10d
    lea 16(%rsi), %r11
    lea (%rsi,%rcx), %rdx
10:
    cmp %rdx, %r11
    jae 7f
    cmpl $1, 16(%r11)
    jne 11f
    add 8(%r11), %r9
11:
    add %r10, %r11
    jmp 10b
7:
    add $7, %rcx
    and $-8, %rcx
    add %rcx, %rsi
    jmp 6b
8:
    mov %r9, %rax
    shr $20, %rax
    lea 1(%rax,%rax), %rax
    ret
9:
    mov $1, %rax
    ret


.global s_fn_baremetal_syscall_init
.type s_fn_baremetal_syscall_init, @function
s_fn_baremetal_syscall_init:
    mov $0xc0000080, %ecx
    rdmsr
    or $1, %eax
    wrmsr
    mov $0xc0000081, %ecx
    mov $0x00180008, %edx
    xor %eax, %eax
    wrmsr
    mov $0xc0000082, %ecx
    lea syscall_entry(%rip), %rax
    mov %rax, %rdx
    shr $32, %rdx
    wrmsr
    mov $0xc0000084, %ecx
    mov $(1 << 9), %eax
    xor %edx, %edx
    wrmsr
    mov $3, %rax
    ret

syscall_entry:
    
    cmp $0, %rax
    je .Lsys_read
    cmp $1, %rax
    je .Lsys_write
    cmp $2, %rax
    je .Lsys_open
    cmp $3, %rax
    je .Lsys_close
    cmp $39, %rax
    jne .Lsys_enosys
    mov $1, %rax
    sysretq

.Lsys_read:
    
    mov %rdx, %rax
    sysretq

.Lsys_write:
    
    mov %rdx, %rax
    sysretq

.Lsys_open:
    
    mov $3, %rax
    sysretq

.Lsys_close:
    mov $0, %rax
    sysretq

.Lsys_enosys:
    mov $-38, %rax
    sysretq

.global s_fn_baremetal_metric
.type s_fn_baremetal_metric, @function
s_fn_baremetal_metric:
    mov %rsi, %rax
    sar $1, %rax
    push %rax
    lea metric_message(%rip), %rsi
    call serial_write
    pop %rax
    call serial_hex64
    mov $3, %rax
    ret

.global s_fn_baremetal_bitmap_test
s_fn_baremetal_bitmap_test:
    mov %rdi, %rax
    sar $1, %rax
    bt %rax, frame_bitmap(%rip)
    setc %al
    movzbq %al, %rax
    lea 1(%rax,%rax), %rax
    ret

.global s_fn_baremetal_bitmap_set
s_fn_baremetal_bitmap_set:
    mov %rdi, %rax
    sar $1, %rax
    bts %rax, frame_bitmap(%rip)
    mov $1, %rax
    ret

.global s_fn_baremetal_bitmap_clear
s_fn_baremetal_bitmap_clear:
    mov %rdi, %rax
    sar $1, %rax
    btr %rax, frame_bitmap(%rip)
    mov $1, %rax
    ret


.global s_fn_baremetal_pci_vendor
s_fn_baremetal_pci_vendor:
    mov %rdi, %rax
    sar $1, %rax
    shl $11, %eax
    or $0x80000000, %eax
    mov $0xcf8, %dx
    out %eax, %dx
    mov $0xcfc, %dx
    in %dx, %eax
    and $0xffff, %eax
    lea 1(%rax,%rax), %rax
    ret

.global s_fn_baremetal_virtio_net_probe
s_fn_baremetal_virtio_net_probe:
    xor %r8d, %r8d
16:
    cmp $32, %r8d
    jae 18f
    mov %r8d, %eax
    shl $11, %eax
    or $0x80000000, %eax
    mov $0xcf8, %dx
    out %eax, %dx
    mov $0xcfc, %dx
    in %dx, %eax
    cmp $0x10001af4, %eax
    je 17f
    cmp $0x10411af4, %eax
    je 17f
    inc %r8d
    jmp 16b
17:
    mov $3, %rax
    ret
18:
    mov $1, %rax
    ret

.global s_fn_baremetal_initramfs_files
s_fn_baremetal_initramfs_files:
    
    mov $3, %rax
    ret

.global s_fn_baremetal_ring3_image_valid
s_fn_baremetal_ring3_image_valid:
    cmpl $0x464c457f, ring3_image(%rip)
    sete %al
    movzbq %al, %rax
    lea 1(%rax,%rax), %rax
    ret

.global s_fn_baremetal_logical_cpu_count
s_fn_baremetal_logical_cpu_count:
    mov $1, %eax
    cpuid
    shr $16, %ebx
    and $0xff, %ebx
    mov %ebx, %eax
    lea 1(%rax,%rax), %rax
    ret

.global s_fn_baremetal_tsc_cycles
s_fn_baremetal_tsc_cycles:
    lfence
    rdtsc
    shl $32, %rdx
    or %rdx, %rax
    lea 1(%rax,%rax), %rax
    ret

serial_hex64:
    mov %rax, %r8
    mov $16, %ecx
13:
    rol $4, %r8
    mov %r8b, %al
    and $0x0f, %al
    cmp $10, %al
    jb 14f
    add $('a' - 10), %al
    jmp 15f
14:
    add $'0', %al
15:
    mov $0x3f8, %dx
    out %al, %dx
    loop 13b
    mov $'\n', %al
    out %al, %dx
    ret


.global s_value_add
.type s_value_add, @function
s_value_add:
    lea -1(%rdi,%rsi), %rax
    ret

.global s_value_cmp
.type s_value_cmp, @function
s_value_cmp:
    mov %rdi, %rax
    sar $1, %rax
    mov %rsi, %rcx
    sar $1, %rcx
    sub %rcx, %rax
    ret

serial_init:
    mov $0x3f9, %dx
    xor %al, %al
    out %al, %dx
    mov $0x3fb, %dx
    mov $0x80, %al
    out %al, %dx
    mov $0x3f8, %dx
    mov $3, %al
    out %al, %dx
    mov $0x3f9, %dx
    xor %al, %al
    out %al, %dx
    mov $0x3fb, %dx
    mov $3, %al
    out %al, %dx
    mov $0x3fa, %dx
    mov $0xc7, %al
    out %al, %dx
    mov $0x3fc, %dx
    mov $0x0b, %al
    out %al, %dx
    ret

serial_write:
    mov $0x3f8, %dx
2:
    lodsb
    test %al, %al
    je 3f
    out %al, %dx
    jmp 2b
3:
    ret

.section .rodata
boot_message:   .asciz "NeurX: entered x86_64 bare-metal kernel\n"
stage_message:  .asciz "NeurX: S init stage "
metric_message: .asciz "NeurX: metric 0x"
ready_message:  .asciz "NeurX: S kernel READY\n"
failed_message: .asciz "NeurX: S kernel FAILED\n"

.align 8
ring3_image:
    .byte 0x7f, 'E', 'L', 'F', 2, 1, 1, 0
    .zero 56
initramfs_start:
    .asciz "070701/INIT\nNeurX initramfs\n"
initramfs_end:

.align 8
gdt64:
    .quad 0
    .quad 0x00af9a000000ffff
    .quad 0x00af92000000ffff
    .quad 0
    .quad 0x00aff2000000ffff
    .quad 0x00affa000000ffff
    .quad 0
    .quad 0
gdt64_pointer:
    .word . - gdt64 - 1
    .long gdt64
idt64_pointer:
    .word 4095
    .quad idt64

.section .bss,"aw",@nobits
.align 4096
page_table_l4: .skip 4096
page_table_l3: .skip 4096
page_table_l2_0: .skip 4096
page_table_l2_1: .skip 4096
page_table_l2_2: .skip 4096
page_table_l2_3: .skip 4096
.align 16
idt64: .skip 4096
.align 16
tss64: .skip 104
.align 16
kernel_interrupt_stack: .skip 16384
kernel_interrupt_stack_top:
.align 8
apic_ticks: .skip 8
.align 4096
frame_bitmap: .skip 131072
.align 16
boot_stack: .skip 65536
boot_stack_top:
multiboot_magic: .skip 4
multiboot_info: .skip 4

.section .note.GNU-stack,"",@progbits
