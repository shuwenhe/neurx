package neurx.runtime.stage
use neurx.strings

use neurx.runtime.control
use neurx.strings
use neurx.autograd.function
use neurx.strings

struct stage_state {
    string name
    string backend
    string mode
    bool jit_enabled
    bool lowered
    bool compiled
    bool executed
    []string stages
    []string params
    bool control_enabled
    bool control_cond_enabled
    bool control_loop_enabled
    bool control_scan_enabled
    int control_iterations
    []string control_branches
    []string control_params
}

func join_strings([]string values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + values[i]
        i = i + 1
    }
    out
}

func new_stage_state(string name, string backend, string mode) stage_state {
    stage_state {
        name: name,
        backend: backend,
        mode: mode,
        jit_enabled: false,
        lowered: false,
        compiled: false,
        executed: false,
        stages: [],
        params: [],
        control_enabled: false,
        control_cond_enabled: false,
        control_loop_enabled: false,
        control_scan_enabled: false,
        control_iterations: 0,
        control_branches: [],
        control_params: [],
    }
}

func stage_name(stage_state state) string {
    state.name
}

func stage_backend(stage_state state) string {
    state.backend
}

func stage_mode(stage_state state) string {
    state.mode
}

func stage_jit_enabled(stage_state state) bool {
    state.jit_enabled
}

func stage_lowered(stage_state state) bool {
    state.lowered
}

func stage_compiled(stage_state state) bool {
    state.compiled
}

func stage_executed(stage_state state) bool {
    state.executed
}

func stage_stage_count(stage_state state) int {
    len(state.stages)
}

func stage_param_count(stage_state state) int {
    len(state.params)
}

func stage_has_stage(stage_state state, string value) bool {
    int i = 0
    while i < len(state.stages) {
        if neurx.strings.strings_eq(state.stages[i], value) {
            return true
        }
        i = i + 1
    }
    false
}

func stage_has_param(stage_state state, string value) bool {
    int i = 0
    while i < len(state.params) {
        if neurx.strings.strings_eq(state.params[i], value) {
            return true
        }
        i = i + 1
    }
    false
}

func stage_add_stage(stage_state state, string value) stage_state {
    []string stages = copy_strings(state.stages)
    stages.push(value)
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: stages,
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_add_param(stage_state state, string value) stage_state {
    []string params = copy_strings(state.params)
    params.push(value)
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: params,
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_jit_enabled(stage_state state, bool enabled) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_lowered(stage_state state, bool lowered) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_compiled(stage_state state, bool compiled) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_executed(stage_state state, bool executed) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_clear_stages(stage_state state) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: [],
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_clear_params(stage_state state) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: [],
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_control_enabled(stage_state state) bool {
    state.control_enabled
}

func stage_control_cond_enabled(stage_state state) bool {
    state.control_cond_enabled
}

func stage_control_loop_enabled(stage_state state) bool {
    state.control_loop_enabled
}

func stage_control_scan_enabled(stage_state state) bool {
    state.control_scan_enabled
}

func stage_control_iterations(stage_state state) int {
    state.control_iterations
}

func stage_control_branch_count(stage_state state) int {
    len(state.control_branches)
}

func stage_control_param_count(stage_state state) int {
    len(state.control_params)
}

func stage_has_control_branch(stage_state state, string branch) bool {
    int i = 0
    while i < len(state.control_branches) {
        if neurx.strings.strings_eq(state.control_branches[i], branch) {
            return true
        }
        i = i + 1
    }
    false
}

func stage_has_control_param(stage_state state, string param) bool {
    int i = 0
    while i < len(state.control_params) {
        if neurx.strings.strings_eq(state.control_params[i], param) {
            return true
        }
        i = i + 1
    }
    false
}

func stage_add_control_branch(stage_state state, string branch) stage_state {
    []string branches = copy_strings(state.control_branches)
    branches.push(branch)
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: true,
        control_cond_enabled: state.control_cond_enabled || branch == "cond",
        control_loop_enabled: state.control_loop_enabled || branch == "while_loop",
        control_scan_enabled: state.control_scan_enabled || branch == "scan",
        control_iterations: state.control_iterations,
        control_branches: branches,
        control_params: copy_strings(state.control_params),
    }
}

func stage_add_control_param(stage_state state, string param) stage_state {
    []string params = copy_strings(state.control_params)
    params.push(param)
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled || len(state.control_branches) > 0 || len(params) > 0,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: params,
    }
}

func stage_set_control_enabled(stage_state state, bool enabled) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_control_cond_enabled(stage_state state, bool enabled) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled || enabled,
        control_cond_enabled: enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_control_loop_enabled(stage_state state, bool enabled) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled || enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_control_scan_enabled(stage_state state, bool enabled) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled || enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_set_control_iterations(stage_state state, int iterations) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_clear_control_branches(stage_state state) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: [],
        control_params: copy_strings(state.control_params),
    }
}

func stage_clear_control_params(stage_state state) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: [],
    }
}

func stage_state_dict(stage_state state) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.jit_enabled,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        stages: copy_strings(state.stages),
        params: copy_strings(state.params),
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_load_state_dict(stage_state state, stage_state other) stage_state {
    other
}

func stage_control_state_dict(stage_state state) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: false,
        lowered: false,
        compiled: false,
        executed: false,
        stages: [],
        params: [],
        control_enabled: state.control_enabled,
        control_cond_enabled: state.control_cond_enabled,
        control_loop_enabled: state.control_loop_enabled,
        control_scan_enabled: state.control_scan_enabled,
        control_iterations: state.control_iterations,
        control_branches: copy_strings(state.control_branches),
        control_params: copy_strings(state.control_params),
    }
}

func stage_to_control_state(stage_state state) control_state {
    control_state {
        name: state.name,
        cond_enabled: state.control_cond_enabled,
        loop_enabled: state.control_loop_enabled,
        scan_enabled: state.control_scan_enabled,
        iterations: state.control_iterations,
        branches: copy_strings(state.control_branches),
        params: copy_strings(state.control_params),
    }
}

func control_state_to_stage(control_state state, string backend, string mode) stage_state {
    stage_state {
        name: state.name,
        backend: backend,
        mode: mode,
        jit_enabled: false,
        lowered: false,
        compiled: false,
        executed: false,
        stages: [],
        params: [],
        control_enabled: state.cond_enabled || state.loop_enabled || state.scan_enabled || len(state.branches) > 0 || len(state.params) > 0,
        control_cond_enabled: state.cond_enabled,
        control_loop_enabled: state.loop_enabled,
        control_scan_enabled: state.scan_enabled,
        control_iterations: state.iterations,
        control_branches: copy_strings(state.branches),
        control_params: copy_strings(state.params),
    }
}

func jit(stage_state state) stage_state {
    stage_state next = state
    if !stage_has_stage(next, "jit") {
        next = stage_add_stage(next, "jit")
    }
    stage_set_jit_enabled(next, true)
}

func lower(stage_state state) stage_state {
    stage_state next = state
    if !stage_has_stage(next, "jit") {
        next = stage_add_stage(next, "jit")
    }
    if !stage_has_stage(next, "lower") {
        next = stage_add_stage(next, "lower")
    }
    stage_set_lowered(next, true)
}

func compile(stage_state state) stage_state {
    stage_state next = lower(state)
    if !stage_has_stage(next, "compile") {
        next = stage_add_stage(next, "compile")
    }
    stage_set_compiled(next, true)
}

func execute(stage_state state) stage_state {
    stage_state next = compile(state)
    if !stage_has_stage(next, "execute") {
        next = stage_add_stage(next, "execute")
    }
    stage_set_executed(next, true)
}

func stage_to_transform_chain(stage_state state) transform_chain {
    transform_chain chain = neurx.autograd.function.new_transform_chain()
    int i = 0
    while i < len(state.stages) {
        string param = neurx.strings.string_at(state.params, i)
        if param != "" {
            chain = neurx.autograd.function.transform_chain_add_step_with_param(chain, state.stages[i], param)
        } else {
            chain = neurx.autograd.function.transform_chain_add_step(chain, state.stages[i])
        }
        i = i + 1
    }
    if state.control_enabled || state.control_cond_enabled || state.control_loop_enabled || state.control_scan_enabled || len(state.control_branches) > 0 || len(state.control_params) > 0 {
        int j = 0
        while j < len(state.control_branches) {
            string branch = neurx.strings.string_at(state.control_branches, j)
            string param = neurx.strings.string_at(state.control_params, j)
            if param != "" {
                chain = neurx.autograd.function.transform_chain_add_step_with_param(chain, branch, param)
            } else {
                chain = neurx.autograd.function.transform_chain_add_step(chain, branch)
            }
            j = j + 1
        }
        int k = len(state.control_branches)
        while k < len(state.control_params) {
            chain = neurx.autograd.function.transform_chain_add_step_with_param(chain, "control_param", neurx.strings.string_at(state.control_params, k))
            k = k + 1
        }
    }
    chain = neurx.autograd.function.transform_chain_set_ready(chain, state.jit_enabled || state.lowered || state.compiled || state.executed || len(state.stages) > 0)
    chain = neurx.autograd.function.transform_chain_set_linearized(chain, state.lowered || state.compiled || state.executed)
    chain
}

func transform_chain_to_stage(transform_chain chain, string name, string backend, string mode) stage_state {
    []string stages = copy_strings(chain.steps)
    []string params = copy_strings(chain.params)
    bool control_enabled = false
    bool control_cond_enabled = false
    bool control_loop_enabled = false
    bool control_scan_enabled = false
    int control_iterations = 0
    []string control_branches = []
    []string control_params = []
    if len(chain.eqns) > 0 {
        stages = []string{cap: len(chain.eqns)}
        params = []string{cap: len(chain.eqns)}
        int i = 0
        while i < len(chain.eqns) {
            string primitive = chain.eqns[i].primitive
            string joined = join_strings(chain.eqns[i].params)
            if primitive == "jit" || primitive == "lower" || primitive == "compile" || primitive == "execute" {
                stages[i] = primitive
                params[i] = joined
            } else {
                if primitive == "control_param" {
                    control_enabled = true
                    if joined != "" {
                        control_params.push(joined)
                    }
                } else {
                    control_enabled = true
                    control_branches.push(primitive)
                    if joined != "" {
                        control_params.push(joined)
                    }
                    if primitive == "cond" {
                        control_cond_enabled = true
                    }
                    if primitive == "while_loop" {
                        control_loop_enabled = true
                    }
                    if primitive == "scan" {
                        control_scan_enabled = true
                    }
                }
            }
            i = i + 1
        }
    }
    bool jit_enabled = false
    bool lowered = false
    bool compiled = false
    bool executed = false
    int i = 0
    while i < len(stages) {
        if stages[i] == "jit" {
            jit_enabled = true
        }
        if stages[i] == "lower" {
            lowered = true
        }
        if stages[i] == "compile" {
            compiled = true
        }
        if stages[i] == "execute" {
            executed = true
        }
        i = i + 1
    }
    stage_state {
        name: name,
        backend: backend,
        mode: mode,
        jit_enabled: jit_enabled || len(stages) > 0,
        lowered: lowered || compiled || executed,
        compiled: compiled || executed,
        executed: executed,
        stages: stages,
        params: params,
        control_enabled: control_enabled || control_cond_enabled || control_loop_enabled || control_scan_enabled || len(control_branches) > 0 || len(control_params) > 0,
        control_cond_enabled: control_cond_enabled,
        control_loop_enabled: control_loop_enabled,
        control_scan_enabled: control_scan_enabled,
        control_iterations: control_iterations,
        control_branches: control_branches,
        control_params: control_params,
    }
}
