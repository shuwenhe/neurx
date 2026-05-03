package neurx.ad.tracer

use neurx.ad.function
use neurx.ad.eqn

struct tracer_state {
    string name
    bool active
    bool linearized
    int op_count
    []string ops
    []string params
    []string inputs
    []string outputs
    []jaxpr_eqn eqns
    []string tags
}

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_eqn(jaxpr_eqn eqn) jaxpr_eqn {
    jaxpr_eqn {
        primitive: eqn.primitive,
        params: copy_strings(eqn.params),
        inputs: copy_strings(eqn.inputs),
        outputs: copy_strings(eqn.outputs),
    }
}

func copy_eqns([]jaxpr_eqn values) []jaxpr_eqn {
    []jaxpr_eqn out = []jaxpr_eqn{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = copy_eqn(values[i])
        i = i + 1
    }
    out
}

func new_tracer_state(string name) tracer_state {
    tracer_state {
        name: name,
        active: false,
        linearized: false,
        op_count: 0,
        ops: [],
        params: [],
        inputs: [],
        outputs: [],
        eqns: [],
        tags: [],
    }
}

func tracer_name(tracer_state state) string {
    state.name
}

func tracer_active(tracer_state state) bool {
    state.active
}

func tracer_linearized(tracer_state state) bool {
    state.linearized
}

func tracer_op_count(tracer_state state) int {
    state.op_count
}

func tracer_tag_count(tracer_state state) int {
    len(state.tags)
}

func tracer_param_count(tracer_state state) int {
    len(state.params)
}

func tracer_input_count(tracer_state state) int {
    len(state.inputs)
}

func tracer_output_count(tracer_state state) int {
    len(state.outputs)
}

func tracer_eqn_count(tracer_state state) int {
    len(state.eqns)
}

func tracer_has_op(tracer_state state, string op) bool {
    int i = 0
    while i < len(state.ops) {
        if state.ops[i] == op {
            return true
        }
        i = i + 1
    }
    false
}

func tracer_has_param(tracer_state state, string param) bool {
    int i = 0
    while i < len(state.params) {
        if state.params[i] == param {
            return true
        }
        i = i + 1
    }
    false
}

func tracer_has_input(tracer_state state, string input) bool {
    int i = 0
    while i < len(state.inputs) {
        if state.inputs[i] == input {
            return true
        }
        i = i + 1
    }
    false
}

func tracer_has_output(tracer_state state, string output) bool {
    int i = 0
    while i < len(state.outputs) {
        if state.outputs[i] == output {
            return true
        }
        i = i + 1
    }
    false
}

func tracer_has_eqn(tracer_state state, string primitive) bool {
    int i = 0
    while i < len(state.eqns) {
        if state.eqns[i].primitive == primitive {
            return true
        }
        i = i + 1
    }
    false
}

func tracer_has_tag(tracer_state state, string tag) bool {
    int i = 0
    while i < len(state.tags) {
        if state.tags[i] == tag {
            return true
        }
        i = i + 1
    }
    false
}

func tracer_add_op(tracer_state state, string op) tracer_state {
    []string ops = copy_strings(state.ops)
    ops.push(op)
    tracer_state {
        name: state.name,
        active: true,
        linearized: state.linearized,
        op_count: len(ops),
        ops: ops,
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_add_op_with_param(tracer_state state, string op, string param) tracer_state {
    []string ops = copy_strings(state.ops)
    []string params = copy_strings(state.params)
    ops.push(op)
    params.push(param)
    tracer_state {
        name: state.name,
        active: true,
        linearized: state.linearized,
        op_count: len(ops),
        ops: ops,
        params: params,
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_add_input(tracer_state state, string input) tracer_state {
    []string inputs = copy_strings(state.inputs)
    inputs.push(input)
    tracer_state {
        name: state.name,
        active: true,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: inputs,
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_add_output(tracer_state state, string output) tracer_state {
    []string outputs = copy_strings(state.outputs)
    outputs.push(output)
    tracer_state {
        name: state.name,
        active: true,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: outputs,
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func eqn_inputs([]string inputs) []string {
    copy_strings(inputs)
}

func eqn_outputs([]string outputs) []string {
    copy_strings(outputs)
}

func tracer_add_eqn_with_io(tracer_state state, string primitive, []string params, []string inputs, []string outputs) tracer_state {
    []string ops = copy_strings(state.ops)
    []string param_list = copy_strings(state.params)
    []string input_list = copy_strings(state.inputs)
    []string output_list = copy_strings(state.outputs)
    []jaxpr_eqn eqns = copy_eqns(state.eqns)
    ops.push(primitive)
    param_list.push(join_params(params))
    int i = 0
    while i < len(inputs) {
        input_list.push(inputs[i])
        i = i + 1
    }
    i = 0
    while i < len(outputs) {
        output_list.push(outputs[i])
        i = i + 1
    }
    eqns.push(
        jaxpr_eqn {
            primitive: primitive,
            params: copy_strings(params),
            inputs: eqn_inputs(inputs),
            outputs: eqn_outputs(outputs),
        }
    )
    tracer_state {
        name: state.name,
        active: true,
        linearized: state.linearized,
        op_count: len(ops),
        ops: ops,
        params: param_list,
        inputs: input_list,
        outputs: output_list,
        eqns: eqns,
        tags: copy_strings(state.tags),
    }
}

func tracer_add_eqn(tracer_state state, string primitive) tracer_state {
    tracer_add_eqn_with_io(state, primitive, [], [], [])
}

func tracer_add_eqn_with_param(tracer_state state, string primitive, string param) tracer_state {
    []string params = []string{cap: 1}
    params[0] = param
    tracer_add_eqn_with_io(state, primitive, params, [], [])
}

func tracer_clear_tags(tracer_state state) tracer_state {
    tracer_state {
        name: state.name,
        active: state.active,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: [],
    }
}

func tracer_clear_inputs(tracer_state state) tracer_state {
    tracer_state {
        name: state.name,
        active: state.active,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: [],
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_clear_outputs(tracer_state state) tracer_state {
    tracer_state {
        name: state.name,
        active: state.active,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: [],
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_clear_eqns(tracer_state state) tracer_state {
    tracer_state {
        name: state.name,
        active: state.active,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: [],
        tags: copy_strings(state.tags),
    }
}

func tracer_set_active(tracer_state state, bool active) tracer_state {
    tracer_state {
        name: state.name,
        active: active,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_set_linearized(tracer_state state, bool linearized) tracer_state {
    tracer_state {
        name: state.name,
        active: state.active,
        linearized: linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_state_dict(tracer_state state) tracer_state {
    tracer_state {
        name: state.name,
        active: state.active,
        linearized: state.linearized,
        op_count: state.op_count,
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        tags: copy_strings(state.tags),
    }
}

func tracer_load_state_dict(tracer_state state, tracer_state other) tracer_state {
    other
}

func tracer_capture(tracer_state state, string op) tracer_state {
    tracer_add_op(state, op)
}

func tracer_capture_with_param(tracer_state state, string op, string param) tracer_state {
    tracer_add_op_with_param(state, op, param)
}

func tracer_capture_with_io(tracer_state state, string op, []string params, []string inputs, []string outputs) tracer_state {
    tracer_add_eqn_with_io(state, op, params, inputs, outputs)
}

func tracer_to_transform_chain(tracer_state state) transform_chain {
    transform_chain {
        steps: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        ready: state.active || len(state.ops) > 0,
        linearized: state.linearized,
    }
}

func transform_chain_to_tracer(transform_chain chain, string name) tracer_state {
    []jaxpr_eqn eqns = copy_eqns(chain.eqns)
    if len(eqns) == 0 {
        eqns = []jaxpr_eqn{cap: len(chain.steps)}
        int i = 0
        while i < len(chain.steps) {
            eqns[i] = jaxpr_eqn {
                primitive: chain.steps[i],
                params: copy_strings([]string{cap: 0}),
                inputs: [],
                outputs: [],
            }
            if i < len(chain.params) && chain.params[i] != "" {
                []string params = []string{cap: 1}
                params[0] = chain.params[i]
                eqns[i].params = params
            }
            i = i + 1
        }
    }
    tracer_state {
        name: name,
        active: chain.ready,
        linearized: chain.linearized,
        op_count: len(chain.steps),
        ops: copy_strings(chain.steps),
        params: copy_strings(chain.params),
        inputs: copy_strings(chain.inputs),
        outputs: copy_strings(chain.outputs),
        eqns: eqns,
        tags: [],
    }
}
