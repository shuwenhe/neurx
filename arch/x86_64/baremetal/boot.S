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

    /* Identity-map the first 4 GiB with 2 MiB pages, including local APIC. */
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

/* Called from generated S code; RDI contains a tagged integer (n * 2 + 1). */
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

/* Build a conservative IDT. Interrupts are acknowledged and ignored until a
 * device registers a handler; fatal exceptions stop in a deterministic loop. */
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
    /* Mask the legacy PIC; interrupt routing is owned by APIC. */
    mov $0x21, %dx
    mov $0xff, %al
    out %al, %dx
    mov $0xa1, %dx
    out %al, %dx
    mov $3, %rax
    ret

interrupt_ignore:
    iretq

/* Enable the local APIC and install vector 0xf0 as the spurious vector. */
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

/* Sum Multiboot2 type-1 memory-map entries and return MiB as an S integer. */
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

/* Establish the x86-64 syscall entry. Ring-3 launch is deliberately separate. */
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
    /* Minimal getpid-compatible syscall. Unsupported calls return -ENOSYS. */
    cmp $39, %rax
    jne 12f
    mov $1, %rax
    sysretq
12:
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

/* The standalone S object uses this helper for tagged integer addition. */
.global s_value_add
.type s_value_add, @function
s_value_add:
    lea -1(%rdi,%rsi), %rax
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
gdt64:
    .quad 0
    .quad 0x00af9a000000ffff
    .quad 0x00af92000000ffff
    .quad 0
    .quad 0x00aff2000000ffff
    .quad 0x00affa000000ffff
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
boot_stack: .skip 65536
boot_stack_top:
multiboot_magic: .skip 4
multiboot_info: .skip 4

.section .note.GNU-stack,"",@progbits
