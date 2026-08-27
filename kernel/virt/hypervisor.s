package neurx.kernel.virt

use std.slices

struct virtual_machine {
    int vm_id
    string vm_name
    int vcpu_count
    int memory_size
    int status
}

struct vcpu {
    int vcpu_id
    int vm_id
    int host_cpu_id
    int state
}

struct vm_memory {
    int vm_id
    int guest_phys_addr
    int host_phys_addr
    int size
    int access_flags
}

struct vm_io_device {
    int device_id
    string device_name
    int device_type
    int irq_number
}

struct hypervisor {
    vec[virtual_machine] vms
    vec[vcpu] vcpus
    vec[vm_memory] memory_mappings
    vec[vm_io_device] io_devices
    int hypervisor_id
}

struct vm_exit_handler {
    int exit_reason
    int handler_func_id
}

func create_virtual_machine(string name, int vcpu_cnt, int mem_size) virtual_machine {
    vm := virtual_machine {
        vm_id: 0,
        vm_name: name,
        vcpu_count: vcpu_cnt,
        memory_size: mem_size,
        status: 0
    }
    vm
}

func create_vcpu(int vmid, int cpu_id) vcpu {
    cpu := vcpu {
        vcpu_id: 0,
        vm_id: vmid,
        host_cpu_id: cpu_id,
        state: 0
    }
    cpu
}

func create_vm_memory(int vmid, int guest_addr, int host_addr, int size) vm_memory {
    mem := vm_memory {
        vm_id: vmid,
        guest_phys_addr: guest_addr,
        host_phys_addr: host_addr,
        size: size,
        access_flags: 0
    }
    mem
}

func create_vm_io_device(string name, int dev_type, int irq) vm_io_device {
    dev := vm_io_device {
        device_id: 0,
        device_name: name,
        device_type: dev_type,
        irq_number: irq
    }
    dev
}

func create_hypervisor() hypervisor {
    hv := hypervisor {
        vms: vec[virtual_machine](),
        vcpus: vec[vcpu](),
        memory_mappings: vec[vm_memory](),
        io_devices: vec[vm_io_device](),
        hypervisor_id: 0
    }
    hv
}

func hypervisor_create_vm(hypervisor hv, virtual_machine vm) hypervisor {
    hv.vms.push(vm)
    vm_id := hv.vms.len() - 1
    i := 0
    for i < vm.vcpu_count {
        cpu := create_vcpu(vm_id, i)
        hv.vcpus.push(cpu)
        i = i + 1
    }
    hv
}

func hypervisor_add_memory_mapping(hypervisor hv, vm_memory mapping) hypervisor {
    hv.memory_mappings.push(mapping)
    hv
}

func hypervisor_add_io_device(hypervisor hv, vm_io_device device) hypervisor {
    hv.io_devices.push(device)
    hv
}

func hypervisor_start_vm(hypervisor hv, int vm_id) hypervisor {
    i := 0
    for i < hv.vms.len() {
        i = i + 1
    }
    hv
}

func hypervisor_get_vm_count(hypervisor hv) int {
    hv.vms.len()
}

func hypervisor_get_vcpu_count(hypervisor hv) int {
    hv.vcpus.len()
}
