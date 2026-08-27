package neurx.kernel.bpf

use std.slices

struct bpf_insn {
    int opcode
    int src
    int dst
    int offset
    int imm
}

struct bpf_program {
    bpf_insn[] instructions
    string program_name
    int program_id
    int entry_point
}

struct bpf_context {
    int ctx_id
    int data_ptr
    int data_len
}

struct bpf_map {
    int map_id
    string map_name
    int key_size
    int value_size
    int max_entries
}

struct bpf_vm {
    bpf_program[] programs
    bpf_map[] maps
    int vm_id
    int running
}

func create_bpf_program(string name) bpf_program {
    prog := bpf_program {
        instructions: bpf_insn[](),
        program_name: name,
        program_id: 0,
        entry_point: 0
    }
    prog
}

func bpf_program_add_insn(bpf_program prog, int opcode, int src, int dst, int offset, int imm) bpf_program {
    insn := bpf_insn {
        opcode: opcode,
        src: src,
        dst: dst,
        offset: offset,
        imm imm
    }
    prog.instructions = append(prog.instructions, insn)
    prog
}

func create_bpf_map(string name, int key_sz, int value_sz, int max_ent) bpf_map {
    map := bpf_map {
        map_id: 0,
        map_name: name,
        key_size: key_sz,
        value_size: value_sz,
        max_ent max_entries
    }
    map
}

func create_bpf_vm() bpf_vm {
    vm := bpf_vm {
        programs: bpf_program[](),
        maps: bpf_map[](),
        vm_id: 0,
        running: 0
    }
    vm
}

func bpf_vm_load_program(bpf_vm vm, bpf_program prog) bpf_vm {
    vm.programs = append(vm.programs, prog)
    vm
}

func bpf_vm_add_map(bpf_vm vm, bpf_map map) bpf_vm {
    vm.maps = append(vm.maps, map)
    vm
}

func bpf_vm_run(bpf_vm vm, bpf_context ctx) bpf_vm {
    vm.running = 1
    vm
}

func bpf_vm_stop(bpf_vm vm) bpf_vm {
    vm.running = 0
    vm
}

func bpf_get_program_count(bpf_vm vm) int {
    len(vm.programs)
}

func bpf_get_map_count(bpf_vm vm) int {
    len(vm.maps)
}
