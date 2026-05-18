package neurx.runtime.compile

use neurx.runtime.stage

struct compile_state {
    string name
    string backend
    string mode
    bool captured
    bool lowered
    bool compiled
    bool executed
    bool ready
    bool linearized
    bool dynamic
    bool fullgraph
    bool debug
    int node_count
    []string nodes
    []string ops
    []string params
    []string inputs
    []string outputs
    []string edges
    []string passes
    []string cache_keys
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

func new_compile_state(string name, string backend, string mode) compile_state {
    compile_state {
        name: name,
        backend: backend,
        mode: mode,
        captured: false,
        lowered: false,
        compiled: false,
        executed: false,
        ready: false,
        linearized: false,
        dynamic: false,
        fullgraph: false,
        debug: false,
        node_count: 0,
        nodes: [],
        ops: [],
        params: [],
        inputs: [],
        outputs: [],
        edges: [],
        passes: [],
        cache_keys: [],
        tags: [],
    }
}

func compile_name(compile_state state) string {
    state.name
}

func compile_backend(compile_state state) string {
    state.backend
}

func compile_mode(compile_state state) string {
    state.mode
}

func compile_captured(compile_state state) bool {
    state.captured
}

func compile_lowered(compile_state state) bool {
    state.lowered
}

func compile_compiled(compile_state state) bool {
    state.compiled
}

func compile_executed(compile_state state) bool {
    state.executed
}

func compile_ready(compile_state state) bool {
    state.ready
}

func compile_is_linearized(compile_state state) bool {
    state.linearized
}

func compile_node_count(compile_state state) int {
    state.node_count
}

func compile_pass_count(compile_state state) int {
    len(state.passes)
}

func compile_param_count(compile_state state) int {
    len(state.params)
}

func compile_input_count(compile_state state) int {
    len(state.inputs)
}

func compile_output_count(compile_state state) int {
    len(state.outputs)
}

func compile_edge_count(compile_state state) int {
    len(state.edges)
}

func compile_has_node(compile_state state, string node) bool {
    int i = 0
    while i < len(state.nodes) {
        if state.nodes[i] == node {
            return true
        }
        i = i + 1
    }
    false
}

func compile_has_edge(compile_state state, string edge) bool {
    int i = 0
    while i < len(state.edges) {
        if state.edges[i] == edge {
            return true
        }
        i = i + 1
    }
    false
}

func compile_has_pass(compile_state state, string pass) bool {
    int i = 0
    while i < len(state.passes) {
        if state.passes[i] == pass {
            return true
        }
        i = i + 1
    }
    false
}

func compile_has_cache_key(compile_state state, string key) bool {
    int i = 0
    while i < len(state.cache_keys) {
        if state.cache_keys[i] == key {
            return true
        }
        i = i + 1
    }
    false
}

func compile_is_activation_op(string op) bool {
    op == "gelu" || op == "relu" || op == "silu" || op == "swish"
}

func compile_add_edge(compile_state state, string edge) compile_state {
    []string edges = copy_strings(state.edges)
    edges.push(edge)
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: true,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: true,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: edges,
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_add_node_with_io(compile_state state, string node, string op, []string params, []string inputs, []string outputs) compile_state {
    []string nodes = copy_strings(state.nodes)
    []string ops = copy_strings(state.ops)
    []string param_list = copy_strings(state.params)
    []string input_list = copy_strings(state.inputs)
    []string output_list = copy_strings(state.outputs)
    nodes.push(node)
    ops.push(op)
    param_list.push(join_strings(params))
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
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: true,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: true,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: len(nodes),
        nodes: nodes,
        ops: ops,
        params: param_list,
        inputs: input_list,
        outputs: output_list,
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_add_node(compile_state state, string node, string op) compile_state {
    compile_add_node_with_io(state, node, op, [], [], [])
}

func compile_add_input(compile_state state, string input) compile_state {
    []string inputs = copy_strings(state.inputs)
    inputs.push(input)
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready || len(inputs) > 0,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: inputs,
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_add_output(compile_state state, string output) compile_state {
    []string outputs = copy_strings(state.outputs)
    outputs.push(output)
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready || len(outputs) > 0,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: outputs,
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_add_pass(compile_state state, string pass) compile_state {
    []string passes = copy_strings(state.passes)
    passes.push(pass)
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: true,
        lowered: state.lowered || pass == "lower" || pass == "jit" || pass == "linearize" || pass == "lower_graph",
        compiled: state.compiled || pass == "compile",
        executed: state.executed || pass == "execute",
        ready: true,
        linearized: state.linearized || pass == "lower" || pass == "compile" || pass == "execute" || pass == "linearize" || pass == "lower_graph",
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: passes,
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_normalize(compile_state state) compile_state {
    compile_add_pass(state, "normalize")
}

func compile_shape_specialize(compile_state state) compile_state {
    compile_add_pass(state, "shape_specialize")
}

func compile_fuse_linear_activation(compile_state state) compile_state {
    compile_add_tag(compile_add_pass(state, "fuse_linear_activation"), "fused=linear_activation")
}

func compile_linearize(compile_state state) compile_state {
    compile_state next = compile_add_pass(state, "linearize")
    next = compile_add_tag(next, "linearized=true")
    next = compile_add_tag(next, "linear_order=topological")
    next
}

func compile_lower_graph(compile_state state) compile_state {
    compile_state next = compile_add_pass(state, "lower_graph")
    next = compile_add_tag(next, "lowered=graph")
    next = compile_add_tag(next, "lower_graph_edges=tracked")
    next
}

func compile_set_linearized(compile_state state, bool linearized) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_add_param(compile_state state, string param) compile_state {
    []string params = copy_strings(state.params)
    params.push(param)
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: true,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: true,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: params,
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_add_cache_key(compile_state state, string key) compile_state {
    []string cache_keys = copy_strings(state.cache_keys)
    cache_keys.push(key)
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: cache_keys,
        tags: copy_strings(state.tags),
    }
}

func compile_add_tag(compile_state state, string tag) compile_state {
    []string tags = copy_strings(state.tags)
    tags.push(tag)
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: tags,
    }
}

func compile_set_captured(compile_state state, bool captured) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready || captured,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_set_lowered(compile_state state, bool lowered) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: lowered || state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_set_compiled(compile_state state, bool compiled) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: state.linearized || compiled,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_set_executed(compile_state state, bool executed) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: executed,
        ready: state.ready || executed,
        linearized: state.linearized || executed,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_set_dynamic(compile_state state, bool dynamic) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: state.linearized,
        dynamic: dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_set_fullgraph(compile_state state, bool fullgraph) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_set_debug(compile_state state, bool debug) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_state_dict(compile_state state) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.captured,
        lowered: state.lowered,
        compiled: state.compiled,
        executed: state.executed,
        ready: state.ready,
        linearized: state.linearized,
        dynamic: state.dynamic,
        fullgraph: state.fullgraph,
        debug: state.debug,
        node_count: state.node_count,
        nodes: copy_strings(state.nodes),
        ops: copy_strings(state.ops),
        params: copy_strings(state.params),
        inputs: copy_strings(state.inputs),
        outputs: copy_strings(state.outputs),
        edges: copy_strings(state.edges),
        passes: copy_strings(state.passes),
        cache_keys: copy_strings(state.cache_keys),
        tags: copy_strings(state.tags),
    }
}

func compile_load_state_dict(compile_state state, compile_state other) compile_state {
    other
}

func compile_to_stage(compile_state state) stage_state {
    stage_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        jit_enabled: state.ready || len(state.nodes) > 0 || len(state.passes) > 0,
        lowered: state.lowered || state.compiled || state.executed,
        compiled: state.compiled || state.executed,
        executed: state.executed,
        stages: copy_strings(state.passes),
        params: copy_strings(state.params),
        control_enabled: state.dynamic || state.fullgraph || state.debug,
        control_cond_enabled: state.fullgraph,
        control_loop_enabled: state.dynamic,
        control_scan_enabled: state.mode == "max-autotune",
        control_iterations: 1,
        control_branches: [],
        control_params: [],
    }
}

func stage_to_compile(stage_state state) compile_state {
    compile_state {
        name: state.name,
        backend: state.backend,
        mode: state.mode,
        captured: state.jit_enabled || state.lowered || state.compiled || state.executed || len(state.stages) > 0,
        lowered: state.lowered || state.compiled || state.executed,
        compiled: state.compiled || state.executed,
        executed: state.executed,
        ready: state.jit_enabled || state.lowered || state.compiled || state.executed || len(state.stages) > 0,
        linearized: state.lowered || state.compiled || state.executed,
        dynamic: state.control_loop_enabled,
        fullgraph: state.control_cond_enabled,
        debug: false,
        node_count: len(state.stages),
        nodes: copy_strings(state.stages),
        ops: copy_strings(state.stages),
        params: copy_strings(state.params),
        inputs: [],
        outputs: [],
        edges: [],
        passes: copy_strings(state.stages),
        cache_keys: [],
        tags: [],
    }
}
