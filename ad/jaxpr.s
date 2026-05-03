package neurx.ad.jaxpr

use neurx.ad.function
use neurx.ad.eqn
use neurx.ad.tracer

struct jaxpr_eqn {
    string primitive
    []string params
    []string inputs
    []string outputs
}

struct jaxpr_graph {
    string name
    int eqn_count
    []string primitives
    []string params
    []string inputs
    []string outputs
    []jaxpr_eqn eqns
    bool ready
    bool linearized
}

func _copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func _copy_eqn(jaxpr_eqn eqn) jaxpr_eqn {
    jaxpr_eqn {
        primitive: eqn.primitive,
        params: _copy_strings(eqn.params),
        inputs: _copy_strings(eqn.inputs),
        outputs: _copy_strings(eqn.outputs),
    }
}

func _copy_eqns([]jaxpr_eqn values) []jaxpr_eqn {
    []jaxpr_eqn out = []jaxpr_eqn{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = _copy_eqn(values[i])
        i = i + 1
    }
    out
}

func _join_params([]string params) string {
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

func new_jaxpr_graph(string name) jaxpr_graph {
    jaxpr_graph {
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

func jaxpr_name(jaxpr_graph graph) string {
    graph.name
}

func jaxpr_eqn_count(jaxpr_graph graph) int {
    graph.eqn_count
}

func jaxpr_primitive_count(jaxpr_graph graph) int {
    len(graph.primitives)
}

func jaxpr_param_count(jaxpr_graph graph) int {
    len(graph.params)
}

func jaxpr_input_count(jaxpr_graph graph) int {
    len(graph.inputs)
}

func jaxpr_output_count(jaxpr_graph graph) int {
    len(graph.outputs)
}

func jaxpr_has_primitive(jaxpr_graph graph, string primitive) bool {
    int i = 0
    while i < len(graph.primitives) {
        if graph.primitives[i] == primitive {
            return true
        }
        i = i + 1
    }
    false
}

func jaxpr_ready(jaxpr_graph graph) bool {
    graph.ready
}

func jaxpr_is_linearized(jaxpr_graph graph) bool {
    graph.linearized
}

func jaxpr_add_eqn_with_io(jaxpr_graph graph, string primitive, []string params, []string inputs, []string outputs) jaxpr_graph {
    []string primitives = _copy_strings(graph.primitives)
    []string param_list = _copy_strings(graph.params)
    []jaxpr_eqn eqns = _copy_eqns(graph.eqns)
    primitives.push(primitive)
    param_list.push(_join_params(params))
    eqns.push(
        jaxpr_eqn {
            primitive: primitive,
            params: _copy_strings(params),
            inputs: _copy_strings(inputs),
            outputs: _copy_strings(outputs),
        }
    )
    jaxpr_graph {
        name: graph.name,
        eqn_count: len(primitives),
        primitives: primitives,
        params: param_list,
        inputs: _copy_strings(graph.inputs),
        outputs: _copy_strings(graph.outputs),
        eqns: eqns,
        ready: true,
        linearized: graph.linearized,
    }
}

func jaxpr_add_eqn_with_params(jaxpr_graph graph, string primitive, []string params) jaxpr_graph {
    jaxpr_add_eqn_with_io(graph, primitive, params, [], [])
}

func jaxpr_add_eqn(jaxpr_graph graph, string primitive) jaxpr_graph {
    jaxpr_add_eqn_with_params(graph, primitive, [])
}

func jaxpr_add_input(jaxpr_graph graph, string input) jaxpr_graph {
    []string inputs = _copy_strings(graph.inputs)
    inputs.push(input)
    jaxpr_graph {
        name: graph.name,
        eqn_count: graph.eqn_count,
        primitives: _copy_strings(graph.primitives),
        params: _copy_strings(graph.params),
        inputs: inputs,
        outputs: _copy_strings(graph.outputs),
        eqns: _copy_eqns(graph.eqns),
        ready: graph.ready,
        linearized: graph.linearized,
    }
}

func jaxpr_add_output(jaxpr_graph graph, string output) jaxpr_graph {
    []string outputs = _copy_strings(graph.outputs)
    outputs.push(output)
    jaxpr_graph {
        name: graph.name,
        eqn_count: graph.eqn_count,
        primitives: _copy_strings(graph.primitives),
        params: _copy_strings(graph.params),
        inputs: _copy_strings(graph.inputs),
        outputs: outputs,
        eqns: _copy_eqns(graph.eqns),
        ready: graph.ready,
        linearized: graph.linearized,
    }
}

func jaxpr_state_dict(jaxpr_graph graph) jaxpr_graph {
    jaxpr_graph {
        name: graph.name,
        eqn_count: graph.eqn_count,
        primitives: _copy_strings(graph.primitives),
        params: _copy_strings(graph.params),
        inputs: _copy_strings(graph.inputs),
        outputs: _copy_strings(graph.outputs),
        eqns: _copy_eqns(graph.eqns),
        ready: graph.ready,
        linearized: graph.linearized,
    }
}

func jaxpr_load_state_dict(jaxpr_graph graph, jaxpr_graph other) jaxpr_graph {
    other
}

func jaxpr_from_tracer(tracer_state state, string name) jaxpr_graph {
    jaxpr_graph {
        name: name,
        eqn_count: tracer.tracer_op_count(state),
        primitives: _copy_strings(state.ops),
        params: _copy_strings(state.params),
        inputs: _copy_strings(state.inputs),
        outputs: _copy_strings(state.outputs),
        eqns: _copy_eqns(state.eqns),
        ready: tracer.tracer_active(state),
        linearized: tracer.tracer_linearized(state),
    }
}

func jaxpr_to_tracer(jaxpr_graph graph) tracer_state {
    tracer_state {
        name: graph.name,
        active: graph.ready,
        linearized: graph.linearized,
        op_count: graph.eqn_count,
        ops: _copy_strings(graph.primitives),
        params: _copy_strings(graph.params),
        inputs: _copy_strings(graph.inputs),
        outputs: _copy_strings(graph.outputs),
        eqns: _copy_eqns(graph.eqns),
        tags: [],
    }
}

func jaxpr_capture(jaxpr_graph graph, string primitive) jaxpr_graph {
    jaxpr_add_eqn(graph, primitive)
}

func jaxpr_capture_with_params(jaxpr_graph graph, string primitive, []string params) jaxpr_graph {
    jaxpr_add_eqn_with_params(graph, primitive, params)
}

func jaxpr_capture_with_io(jaxpr_graph graph, string primitive, []string params, []string inputs, []string outputs) jaxpr_graph {
    jaxpr_add_eqn_with_io(graph, primitive, params, inputs, outputs)
}

func jaxpr_to_transform_chain(jaxpr_graph graph) transform_chain {
    transform_chain {
        steps: _copy_strings(graph.primitives),
        params: _copy_strings(graph.params),
        inputs: _copy_strings(graph.inputs),
        outputs: _copy_strings(graph.outputs),
        eqns: _copy_eqns(graph.eqns),
        ready: graph.ready || len(graph.primitives) > 0,
        linearized: graph.linearized,
    }
}

func transform_chain_to_jaxpr(transform_chain chain, string name) jaxpr_graph {
    []jaxpr_eqn eqns = _copy_eqns(chain.eqns)
    if len(eqns) == 0 {
        eqns = []jaxpr_eqn{cap: len(chain.steps)}
        int i = 0
        while i < len(chain.steps) {
            eqns[i] = jaxpr_eqn {
                primitive: chain.steps[i],
                params: []string{cap: 0},
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
    jaxpr_graph {
        name: name,
        eqn_count: len(eqns),
        primitives: _copy_strings(chain.steps),
        params: _copy_strings(chain.params),
        inputs: _copy_strings(chain.inputs),
        outputs: _copy_strings(chain.outputs),
        eqns: eqns,
        ready: chain.ready,
        linearized: chain.linearized,
    }
}
