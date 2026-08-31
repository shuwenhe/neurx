package neurx.compile.ir
use neurx.strings
struct ir_node_state {
    string name
    string op
    string[] inputs
    string[] outputs
}

struct ir_graph_state {
    string name
    []ir_node_state nodes
    string[] edges
    string[] inputs
    string[] outputs
    bool valid
}

func copy_nodes([]ir_node_state values) []ir_node_state {
    []ir_node_state out = make([]ir_node_state, len(values))
    int i = 0
    for i < len(values) {
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

func make_ir_node_state(string name, string op, string[] inputs, string[] outputs) ir_node_state {
    ir_node_state {
        name: name,
        op: op,
        inputs: copy_strings(inputs),
        outputs: copy_strings(outputs),
    }
}

func ir_add_node(ir_graph_state graph, ir_node_state node) ir_graph_state {
    []ir_node_state nodes = copy_nodes(graph.nodes)
    nodes = append(nodes, node)
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
    string[] edges = copy_strings(graph.edges)
    edges = append(edges, edge)
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
    string[] inputs = copy_strings(graph.inputs)
    inputs = append(inputs, input_name)
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
    string[] outputs = copy_strings(graph.outputs)
    outputs = append(outputs, output_name)
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

func ir_graph_to_text(ir_graph_state graph) string {
    string out = ""
    out = out + "graph " + graph.name + "\n"
    out = out + "valid " + (graph.valid ? "true" : "false") + "\n"
    int i = 0
    for i < len(graph.inputs) {
        out = out + "input " + graph.inputs[i] + "\n"
        i = i + 1
    }
    i = 0
    for i < len(graph.outputs) {
        out = out + "output " + graph.outputs[i] + "\n"
        i = i + 1
    }
    i = 0
    for i < len(graph.edges) {
        out = out + "edge " + graph.edges[i] + "\n"
        i = i + 1
    }
    i = 0
    for i < len(graph.nodes) {
        ir_node_state node = graph.nodes[i]
        out = out + "node " + node.name + " " + node.op + "\n"
        int j = 0
        while j < len(node.inputs) {
            out = out + "  in " + node.inputs[j] + "\n"
            j = j + 1
        }
        j = 0
        while j < len(node.outputs) {
            out = out + "  out " + node.outputs[j] + "\n"
            j = j + 1
        }
        i = i + 1
    }
    out
}
