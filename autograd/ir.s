use neurx.autograd.tracer
func trace_to_ir(tracer_state state, string name) ir_graph {
    ir_from_tracer(state, name)
}

func ir_to_trace(ir_graph graph) tracer_state {
    ir_to_tracer(graph)
}

func hybrid_trace_graph(tracer_state state, string name, bool to_graph) any {
    if to_graph {
        return trace_to_ir(state, name)
    } else {
        return tracer_state {
            name: name,
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
}
package neurx.autograd.ir
use neurx.autograd.function
use neurx.autograd.eqn
use neurx.autograd.tracer
use neurx.strings

struct ir_eqn {
    string primitive
    []string params
    []string inputs
    []string outputs
}

struct ir_graph {
    string name
    int eqn_count
    []string primitives
    []string params
    []string inputs
    []string outputs
    []ir_eqn eqns
    bool ready
    bool linearized
}

func get_primitive(ir_graph graph, int index) string {
    graph.primitives[index]
}

func get_param(ir_graph graph, int index) string {
    graph.params[index]
}

func get_eqn(ir_graph graph, int index) ir_eqn {
    graph.eqns[index]
}

func get_eqn_input(ir_eqn eqn, int index) string {
    eqn.inputs[index]
}

func get_eqn_param(ir_eqn eqn, int index) string {
    eqn.params[index]
}

func get_chain_step(transform_chain chain, int index) string {
    chain.steps[index]
}

func get_chain_param(transform_chain chain, int index) string {
    chain.params[index]
}

func copy_eqn(ir_eqn eqn) ir_eqn {
    ir_eqn {
        primitive: eqn.primitive,
        params: copy_strings(eqn.params),
        inputs: copy_strings(eqn.inputs),
        outputs: copy_strings(eqn.outputs),
    }
}

func copy_eqns([]ir_eqn values) []ir_eqn {
    []ir_eqn out = []ir_eqn{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = copy_eqn(values[i])
        i = i + 1
    }
    out
}

func join_params([]string params) string {
    string out = ""
    int i = 0
    while i < len(params) {
        if i > 0 {
            out = out + ","
        }
        out = out + params[i]
        i = i + 1
    }
    out
}

func new_ir_graph(string name) ir_graph {
    ir_graph {
        name: name,
        eqn_count: 0,
        primitives: [],
        params: [],
        inputs: [],
        outputs: [],
        eqns: [],
        ready: false,
        linearized: false,
    }
}

func ir_name(ir_graph graph) string {
    graph.name
}

func ir_eqn_count(ir_graph graph) int {
    graph.eqn_count
}

func ir_primitive_count(ir_graph graph) int {
    len(graph.primitives)
}

func ir_param_count(ir_graph graph) int {
    len(graph.params)
}

func ir_input_count(ir_graph graph) int {
    len(graph.inputs)
}

func ir_output_count(ir_graph graph) int {
    len(graph.outputs)
}

func ir_has_primitive(ir_graph graph, string primitive) bool {
    int i = 0
    while i < len(graph.primitives) {
        if get_primitive(graph, i) == primitive {
            return true
        }
        i = i + 1
    }
    false
}

func ir_ready(ir_graph graph) bool {
    graph.ready
}

func ir_is_linearized(ir_graph graph) bool {
    graph.linearized
}

func ir_add_eqn_with_io(ir_graph graph, string primitive, []string params, []string inputs, []string outputs) ir_graph {
    []string primitives = copy_strings(graph.primitives)
    []string param_list = copy_strings(graph.params)
    []ir_eqn eqns = copy_eqns(graph.eqns)
    primitives.push(primitive)
    param_list.push(join_params(params))
    eqns.push(
        ir_eqn {
            primitive: primitive,
            params: copy_strings(params),
            inputs: copy_strings(inputs),
            outputs: copy_strings(outputs),
        }
    )
    ir_graph {
        name: graph.name,
        eqn_count: len(primitives),
        primitives: primitives,
        params: param_list,
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        eqns: eqns,
        ready: true,
        linearized: graph.linearized,
    }
}

func ir_add_eqn_with_params(ir_graph graph, string primitive, []string params) ir_graph {
    ir_add_eqn_with_io(graph, primitive, params, [], [])
}

func ir_add_eqn(ir_graph graph, string primitive) ir_graph {
    ir_add_eqn_with_params(graph, primitive, [])
}

func ir_add_input(ir_graph graph, string input) ir_graph {
    []string inputs = copy_strings(graph.inputs)
    inputs.push(input)
    ir_graph {
        name: graph.name,
        eqn_count: graph.eqn_count,
        primitives: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: inputs,
        outputs: copy_strings(graph.outputs),
        eqns: copy_eqns(graph.eqns),
        ready: graph.ready,
        linearized: graph.linearized,
    }
}

func ir_add_output(ir_graph graph, string output) ir_graph {
    []string outputs = copy_strings(graph.outputs)
    outputs.push(output)
    ir_graph {
        name: graph.name,
        eqn_count: graph.eqn_count,
        primitives: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: copy_strings(graph.inputs),
        outputs: outputs,
        eqns: copy_eqns(graph.eqns),
        ready: graph.ready,
        linearized: graph.linearized,
    }
}

func ir_state_dict(ir_graph graph) ir_graph {
    ir_graph {
        name: graph.name,
        eqn_count: graph.eqn_count,
        primitives: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        eqns: copy_eqns(graph.eqns),
        ready: graph.ready,
        linearized: graph.linearized,
    }
}

func ir_load_state_dict(ir_graph graph, ir_graph other) ir_graph {
    other
}

func ir_from_tracer(tracer_state state, string name) ir_graph {
    ir_graph {
        name: name,
        eqn_count: tracer.tracer_op_count(state),
        primitives: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        eqns: copy_eqns(state.eqns),
        ready: tracer.tracer_active(state),
        linearized: tracer.tracer_linearized(state),
    }
}

func ir_to_tracer(ir_graph graph) tracer_state {
    tracer_state {
        name: graph.name,
        active: graph.ready,
        linearized: graph.linearized,
        op_count: graph.eqn_count,
        ops: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        eqns: copy_eqns(graph.eqns),
        tags: [],
    }
}

func ir_capture(ir_graph graph, string primitive) ir_graph {
    ir_add_eqn(graph, primitive)
}

func ir_capture_with_params(ir_graph graph, string primitive, []string params) ir_graph {
    ir_add_eqn_with_params(graph, primitive, params)
}

func ir_capture_with_io(ir_graph graph, string primitive, []string params, []string inputs, []string outputs) ir_graph {
    ir_add_eqn_with_io(graph, primitive, params, inputs, outputs)
}

func ir_to_transform_chain(ir_graph graph) transform_chain {
    transform_chain {
        steps: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        eqns: copy_eqns(graph.eqns),
        ready: graph.ready || len(graph.primitives) > 0,
        linearized: graph.linearized,
    }
}

func transform_chain_to_jaxpr(transform_chain chain, string name) ir_graph {
    []ir_eqn eqns = copy_eqns(chain.eqns)
    if len(eqns) == 0 {
        eqns = []ir_eqn{cap: len(chain.steps)}
        int i = 0
        while i < len(chain.steps) {
            string step = get_chain_step(chain, i)
            eqns[i] = ir_eqn {
                primitive: step,
                params: []string{cap: 0},
                inputs: [],
                outputs: [],
            }
            if i < len(chain.params) && get_chain_param(chain, i) != "" {
                []string params = []string{cap: 1}
                params[0] = get_chain_param(chain, i)
                eqns[i].params = params
            }
            i = i + 1
        }
    }
    ir_graph {
        name: name,
        eqn_count: len(eqns),
        primitives: copy_strings(chain.steps),
        params: copy_strings(chain.params),
        inputs: copy_strings(chain.inputs),
        outputs: copy_strings(chain.outputs),
        eqns: eqns,
        ready: chain.ready,
        linearized: chain.linearized,
    }
}
type ir_pass = ir_graph
var ir_pass_registry = map[string]ir_pass{}

func register_ir_pass(string name, ir_pass pass) void {
    ir_pass_registry[name] = pass
}

func run_ir_pass(ir_graph graph, string pass_name) ir_graph {
    return graph
}

func optimize_ir(ir_graph graph) ir_graph {
    ir_graph out = graph
    for name, pass in ir_pass_registry {
        out = pass(out)
    }
    out
}

func simple_fuse_add(ir_graph graph) ir_graph {
    []ir_eqn optimized_eqns = []ir_eqn{}
    int i = 0
    while i < len(graph.eqns) {
        ir_eqn eqn = get_eqn(graph, i)
        if eqn.primitive == "add" && len(eqn.inputs) > 1 && get_eqn_input(eqn, 0) == get_eqn_input(eqn, 1) {
            []string params = []string{cap: 1}
            params[0] = "2.0"
            []string inputs = []string{cap: 1}
            inputs[0] = get_eqn_input(eqn, 0)
            optimized_eqns.push(ir_eqn {
                primitive: "mul",
                params: params,
                inputs: inputs,
                outputs: copy_strings(eqn.outputs),
            })
        } else {
            optimized_eqns.push(eqn)
        }
        i = i + 1
    }
    ir_graph {
        name: graph.name,
        eqn_count: len(optimized_eqns),
        primitives: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        eqns: optimized_eqns,
        ready: true,
        linearized: graph.linearized,
    }
}

func compile_jaxpr(ir_graph graph) string {
    if !graph.ready {
        return "Graph not ready for compilation"
    }
    string compiled_code = ""
    int i = 0
    while i < len(graph.eqns) {
        ir_eqn eqn = get_eqn(graph, i)
        compiled_code = compiled_code + eqn.primitive + "\n"
        i = i + 1
    }
    compiled_code
}

func synchronize_gradients([]ir_eqn eqns, int num_workers) []ir_eqn {
    int i = 0
    while i < len(eqns) {
        ir_eqn eqn = eqns[i]
        if eqn.primitive == "grad" {
            int j = 0
            while j < len(eqn.params) {
                string param_val = get_eqn_param(eqn, j)
                eqn.params[j] = param_val + "|sync"
                j = j + 1
            }
            eqns[i] = eqn
        }
        i = i + 1
    }
    eqns
}

func distributed_training(ir_graph graph, int num_workers) ir_graph {
    []ir_eqn eqns = copy_eqns(graph.eqns)
    eqns = synchronize_gradients(eqns, num_workers)
    ir_graph {
        name: graph.name,
        eqn_count: len(eqns),
        primitives: copy_strings(graph.primitives),
        params: copy_strings(graph.params),
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        eqns: eqns,
        ready: true,
        linearized: graph.linearized,
    }
}
