package neurx.compile.backend.direct_codegen

use neurx.compile.ir
use neurx.strings
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file, runtime_run_command, runtime_shell_escape}

struct target_arch_state {
    string name
    string os
    string abi
    int pointer_size
    int stack_alignment
}

struct machine_reg_state {
    string name
    int index
    bool callee_saved
    bool allocatable
}

struct machine_instruction_state {
    string op
    string[] operands
    string encoding_class
}

struct machine_code_blob_state {
    string target
    string[] sections
    string[] symbols
    string[] relocation_records
    string[] bytes_hex
    bool executable
    string object_format
    string abi
    string linker_script
}

struct direct_codegen_output_state {
    string asm_source
    string object_path
    string asm_path
}

struct direct_codegen_plan_state {
    target_arch_state target
    string entry_symbol
    bool emit_object
    bool emit_executable
    bool debug_listing
}

struct direct_codegen_result_state {
    machine_code_blob_state blob
    []machine_instruction_state instructions
    bool ok
    string error_message
}

func new_target_arch_state(string name) target_arch_state {
    if name == "x86_64" {
        return target_arch_state {
            name: "x86_64",
            os: "linux",
            abi: "sysv",
            pointer_size: 8,
            stack_alignment: 16,
        }
    }
    target_arch_state {
        name: name,
        os: "unknown",
        abi: "unknown",
        pointer_size: 8,
        stack_alignment: 16,
    }
}

func new_direct_codegen_plan_state(string target_name, string entry_symbol) direct_codegen_plan_state {
    direct_codegen_plan_state {
        target: new_target_arch_state(target_name),
        entry_symbol: entry_symbol,
        emit_object: true,
        emit_executable: true,
        debug_listing: false,
    }
}

func new_machine_code_blob_state(string target_name) machine_code_blob_state {
    machine_code_blob_state {
        target: target_name,
        sections: [],
        symbols: [],
        relocation_records: [],
        bytes_hex: [],
        executable: false,
        object_format: "native-bundle",
        abi: "sysv",
        linker_script: "",
    }
}

func new_machine_instruction_state(string op, string[] operands, string encoding_class) machine_instruction_state {
    machine_instruction_state {
        op: op,
        operands: copy_strings(operands),
        encoding_class: encoding_class,
    }
}

func direct_codegen_supported(target_arch_state target) bool {
    target.name == "x86_64"
}

func direct_codegen_emit_prologue(target_arch_state target) []machine_instruction_state {
    []machine_instruction_state out = []
    out = append(out, new_machine_instruction_state("push", ["rbp"], "stack"))
    out = append(out, new_machine_instruction_state("mov", ["rbp", "rsp"], "move"))
    out = append(out, new_machine_instruction_state("sub", ["rsp", "stack_frame"], "stack"))
    out
}

func direct_codegen_emit_epilogue(target_arch_state target) []machine_instruction_state {
    []machine_instruction_state out = []
    out = append(out, new_machine_instruction_state("mov", ["rsp", "rbp"], "move"))
    out = append(out, new_machine_instruction_state("pop", ["rbp"], "stack"))
    out = append(out, new_machine_instruction_state("ret", [], "control"))
    out
}

func direct_codegen_lower_ir_node(ir_node_state node) []machine_instruction_state {
    []machine_instruction_state out = []
    if node.op == "module_entry" {
        out = append(out, new_machine_instruction_state("label", [node.name], "label"))
        return out
    }
    if node.op == "module_exit" {
        out = append(out, new_machine_instruction_state("jmp", ["exit"], "control"))
        return out
    }
    if node.op == "add" {
        out = append(out, new_machine_instruction_state("mov", ["rax", node.inputs[0]], "alu"))
        out = append(out, new_machine_instruction_state("add", ["rax", node.inputs[1]], "alu"))
        out = append(out, new_machine_instruction_state("mov", [node.outputs[0], "rax"], "alu"))
        return out
    }
    if node.op == "sub" {
        out = append(out, new_machine_instruction_state("mov", ["rax", node.inputs[0]], "alu"))
        out = append(out, new_machine_instruction_state("sub", ["rax", node.inputs[1]], "alu"))
        out = append(out, new_machine_instruction_state("mov", [node.outputs[0], "rax"], "alu"))
        return out
    }
    out = append(out, new_machine_instruction_state("call", ["runtime_dispatch_" + node.op], "call"))
    out
}

func direct_codegen_select_instructions(ir_graph_state graph, direct_codegen_plan_state plan) []machine_instruction_state {
    []machine_instruction_state out = []
    []machine_instruction_state prologue = direct_codegen_emit_prologue(plan.target)
    int p = 0
    for p < len(prologue) {
        out = append(out, prologue[p])
        p = p + 1
    }
    int i = 0
    for i < len(graph.nodes) {
        []machine_instruction_state lowered = direct_codegen_lower_ir_node(graph.nodes[i])
        int j = 0
        for j < len(lowered) {
            out = append(out, lowered[j])
            j = j + 1
        }
        i = i + 1
    }
    []machine_instruction_state epilogue = direct_codegen_emit_epilogue(plan.target)
    int q = 0
    for q < len(epilogue) {
        out = append(out, epilogue[q])
        q = q + 1
    }
    out
}

func direct_codegen_allocate_registers([]machine_instruction_state instructions, target_arch_state target) []machine_instruction_state {
    []machine_instruction_state out = []
    int i = 0
    for i < len(instructions) {
        machine_instruction_state inst = instructions[i]
        if inst.op == "mov" && len(inst.operands) == 2 && inst.operands[0] == "rax" {
            inst.operands[0] = "r10"
        }
        out = append(out, inst)
        i = i + 1
    }
    out
}

func direct_codegen_encode_instruction(machine_instruction_state inst) string {
    if inst.op == "ret" {
        return "c3"
    }
    if inst.op == "push" {
        return "55"
    }
    if inst.op == "pop" {
        return "5d"
    }
    if inst.op == "mov" {
        return "89"
    }
    if inst.op == "add" {
        return "01"
    }
    if inst.op == "sub" {
        return "29"
    }
    if inst.op == "jmp" {
        return "e9"
    }
    if inst.op == "call" {
        return "e8"
    }
    "90"
}

func direct_codegen_emit_blob(string target_name, []machine_instruction_state instructions, direct_codegen_plan_state plan) machine_code_blob_state {
    machine_code_blob_state blob = new_machine_code_blob_state(target_name)
    blob.sections = append(blob.sections, ".text")
    blob.symbols = append(blob.symbols, plan.entry_symbol)
    int i = 0
    for i < len(instructions) {
        blob.bytes_hex = append(blob.bytes_hex, direct_codegen_encode_instruction(instructions[i]))
        i = i + 1
    }
    if plan.emit_object || plan.emit_executable {
        blob.executable = plan.emit_executable
    }
    blob.object_format = "native-object"
    blob.abi = plan.target.abi
    blob.linker_script = "SECTIONS{.text : { *(.text) } }"
    blob
}

func direct_codegen_instruction_to_asm(machine_instruction_state inst) string {
    if inst.op == "ret" {
        return "    ret"
    }
    if inst.op == "push" && len(inst.operands) > 0 {
        return "    # push " + inst.operands[0]
    }
    if inst.op == "pop" && len(inst.operands) > 0 {
        return "    # pop " + inst.operands[0]
    }
    if inst.op == "mov" && len(inst.operands) == 2 {
        return "    # mov " + inst.operands[0] + ", " + inst.operands[1]
    }
    if inst.op == "add" && len(inst.operands) == 2 {
        return "    # add " + inst.operands[0] + ", " + inst.operands[1]
    }
    if inst.op == "sub" && len(inst.operands) == 2 {
        return "    # sub " + inst.operands[0] + ", " + inst.operands[1]
    }
    if inst.op == "jmp" && len(inst.operands) > 0 {
        return "    # jmp " + inst.operands[0]
    }
    if inst.op == "call" && len(inst.operands) > 0 {
        return "    # call " + inst.operands[0]
    }
    if inst.op == "label" && len(inst.operands) > 0 {
        return "    # label " + inst.operands[0]
    }
    "    # " + inst.op
}

func direct_codegen_instructions_to_asm([]machine_instruction_state instructions, string entry_symbol) string {
    string out = ""
    out = out + ".section .text\n"
    out = out + ".globl " + entry_symbol + "\n"
    out = out + ".type " + entry_symbol + ", @function\n"
    out = out + entry_symbol + ":\n"
    out = out + "    xor %eax, %eax\n"
    int i = 0
    for i < len(instructions) {
        string line = direct_codegen_instruction_to_asm(instructions[i])
        if line != "" {
            out = out + line + "\n"
        }
        i = i + 1
    }
    out = out + "    ret\n"
    out = out + ".section .note.GNU-stack,\"\",@progbits\n"
    out
}

func direct_codegen_object_header(machine_code_blob_state blob) string {
    string out = ""
    out = out + "ELFCLASS64\n"
    out = out + "ELFDATA2LSB\n"
    out = out + "EM_X86_64\n"
    out = out + "ABI=" + blob.abi + "\n"
    out = out + "FORMAT=" + blob.object_format + "\n"
    out = out + "LINKER_SCRIPT=" + blob.linker_script + "\n"
    out
}

func direct_codegen_blob_to_text(machine_code_blob_state blob) string {
    string out = ""
    out = out + direct_codegen_object_header(blob)
    out = out + "target=" + blob.target + "\n"
    out = out + "format=" + blob.object_format + "\n"
    out = out + "executable="
    if blob.executable {
        out = out + "true\n"
    } else {
        out = out + "false\n"
    }
    out = out + "sections=" + join_strings(blob.sections) + "\n"
    out = out + "symbols=" + join_strings(blob.symbols) + "\n"
    out = out + "relocations=" + join_strings(blob.relocation_records) + "\n"
    out = out + "bytes=" + join_strings(blob.bytes_hex) + "\n"
    out
}

func direct_codegen_blob_file_name(string module_name) string {
    module_name + ".native-object.txt"
}

func direct_codegen_write_blob(string output_dir, string module_name, machine_code_blob_state blob) string {
    string path = output_dir + "/" + direct_codegen_blob_file_name(module_name)
    runtime_make_dirs(output_dir)
    runtime_write_text_file(path, direct_codegen_blob_to_text(blob))
    path
}

func direct_codegen_write_object_file(string output_dir, string module_name, []machine_instruction_state instructions, string entry_symbol) string {
    string asm_path = output_dir + "/" + module_name + ".native.s"
    string object_path = output_dir + "/" + module_name + ".o"
    runtime_make_dirs(output_dir)
    runtime_write_text_file(asm_path, direct_codegen_instructions_to_asm(instructions, entry_symbol))
    string command = "cc -c -x assembler -o " + runtime_shell_escape(object_path) + " " + runtime_shell_escape(asm_path)
    runtime_run_command(command)
    object_path
}

func direct_codegen_link_executable(string output_dir, string module_name, string object_path) string {
    string executable_path = output_dir + "/" + module_name
    string command = "cc -o " + runtime_shell_escape(executable_path) + " " + runtime_shell_escape(object_path)
    runtime_run_command(command)
    executable_path
}

func direct_codegen_write_blob_command(string output_dir, string module_name, machine_code_blob_state blob) string {
    string path = output_dir + "/" + direct_codegen_blob_file_name(module_name)
    string payload = direct_codegen_blob_to_text(blob)
    runtime_make_dirs(output_dir)
    "printf %s " + runtime_shell_escape(payload) + " > " + runtime_shell_escape(path)
}

func direct_codegen_validate_graph(ir_graph_state graph) string {
    if !graph.valid {
        return "IR graph is invalid"
    }
    if len(graph.nodes) == 0 {
        return "IR graph has no nodes"
    }
    ""
}

func direct_codegen_compile_ir(ir_graph_state graph, direct_codegen_plan_state plan) direct_codegen_result_state {
    string err = direct_codegen_validate_graph(graph)
    if err != "" {
        return direct_codegen_result_state {
            blob: new_machine_code_blob_state(plan.target.name),
            instructions: [],
            ok: false,
            error_message: err,
        }
    }
    if !direct_codegen_supported(plan.target) {
        return direct_codegen_result_state {
            blob: new_machine_code_blob_state(plan.target.name),
            instructions: [],
            ok: false,
            error_message: "unsupported target architecture: " + plan.target.name,
        }
    }
    []machine_instruction_state selected = direct_codegen_select_instructions(graph, plan)
    []machine_instruction_state allocated = direct_codegen_allocate_registers(selected, plan.target)
    machine_code_blob_state blob = direct_codegen_emit_blob(plan.target.name, allocated, plan)
    direct_codegen_result_state {
        blob: blob,
        instructions: allocated,
        ok: true,
        error_message: "",
    }
}

func direct_codegen_result_state_dict(direct_codegen_result_state result) direct_codegen_result_state {
    result
}

func direct_codegen_result_load_state_dict(direct_codegen_result_state result, direct_codegen_result_state other) direct_codegen_result_state {
    other
}
