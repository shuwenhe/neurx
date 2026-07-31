package neurx.compile.ir
use neurx.strings
struct ir_node_state {
    string name
    string op
    []string inputs
    []string outputs
}

struct ir_graph_state {
    string name
    []ir_node_state nodes
    []string edges
    []string inputs
    []string outputs
    bool valid
}
func copy_nodes([]ir_node_state values) []ir_node_state {
    []ir_node_state out = []ir_node_state{cap: len(values)}
    int i = 0
    while i < len(values) {
        ir_node_state n = values[i]
        out[i] = ir_node_state {
            name: n.name,
            op: n.op,
            inputs: copy_strings(n.inputs),
            outputs: copy_strings(n.outputs),
        }
        i = i + 1
    }
    out
}

func new_ir_graph_state(string name) ir_graph_state {
    ir_graph_state {
        name: name,
        nodes: [],
        edges: [],
        inputs: [],
        outputs: [],
        valid: true,
    }
}

func make_ir_node_state(string name, string op, []string inputs, []string outputs) ir_node_state {
    ir_node_state {
        name: name,
        op: op,
        inputs: copy_strings(inputs),
        outputs: copy_strings(outputs),
    }
}

func ir_add_node(ir_graph_state graph, ir_node_state node) ir_graph_state {
    []ir_node_state nodes = copy_nodes(graph.nodes)
    nodes.push(node)
    ir_graph_state {
        name: graph.name,
        nodes: nodes,
        edges: copy_strings(graph.edges),
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        valid: graph.valid,
    }
}

func ir_add_edge(ir_graph_state graph, string edge) ir_graph_state {
    []string edges = copy_strings(graph.edges)
    edges.push(edge)
    ir_graph_state {
        name: graph.name,
        nodes: copy_nodes(graph.nodes),
        edges: edges,
        inputs: copy_strings(graph.inputs),
        outputs: copy_strings(graph.outputs),
        valid: graph.valid,
    }
}

func ir_add_input(ir_graph_state graph, string input_name) ir_graph_state {
    []string inputs = copy_strings(graph.inputs)
    inputs.push(input_name)
    ir_graph_state {
        name: graph.name,
        nodes: copy_nodes(graph.nodes),
        edges: copy_strings(graph.edges),
        inputs: inputs,
        outputs: copy_strings(graph.outputs),
        valid: graph.valid,
    }
}

func ir_add_output(ir_graph_state graph, string output_name) ir_graph_state {
    []string outputs = copy_strings(graph.outputs)
    outputs.push(output_name)
    ir_graph_state {
        name: graph.name,
        nodes: copy_nodes(graph.nodes),
        edges: copy_strings(graph.edges),
        inputs: copy_strings(graph.inputs),
        outputs: outputs,
        valid: graph.valid,
    }
}

func ir_node_count(ir_graph_state graph) int {
    len(graph.nodes)
}

func ir_edge_count(ir_graph_state graph) int {
    len(graph.edges)
}

func ir_graph_state_dict(ir_graph_state graph) ir_graph_state {
    graph
}

func ir_graph_load_state_dict(ir_graph_state graph, ir_graph_state other) ir_graph_state {
    other
}
