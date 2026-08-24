package neurx.experimental.compiler.utils.graph_printer

use neurx.experimental.compiler.ir.graph.computation_graph
use neurx.experimental.compiler.ir.operation.op_type

func print_graph_info(g: *computation_graph) string {
    s = ""
    s = s + "========== Computation Graph Info ==========\n"
    s = s + "Graph name: " + g.graph_name + "\n"
    s = s + "Operations: " + g.operation_count() as string + "\n"
    s = s + "Values: " + g.value_count() as string + "\n"
    s = s + "Inputs: " + g.input_count() as string + "\n"
    s = s + "Outputs: " + g.output_count() as string + "\n"
    s = s + "Total memory: " + g.total_memory_bytes() as string + " bytes\n"
    s = s + "\n"
    s
}

func print_graph_operations(g: *computation_graph) string {
    s = ""
    s = s + "========== Operations ==========\n"

    for i, op in g.operations {
        s = s + op.id as string + ": " + op.name + " ("
        match op.op_kind {
            op_type::add: s = s + "add",
            op_type::subtract: s = s + "subtract",
            op_type::multiply: s = s + "multiply",
            op_type::matrix_multiply: s = s + "matmul",
            op_type::relu: s = s + "relu",
            op_type::gelu: s = s + "gelu",
            op_type::softmax: s = s + "softmax",
            op_type::layer_norm: s = s + "layer_norm",
            op_type::reshape: s = s + "reshape",
            op_type::transpose: s = s + "transpose",
            default: s = s + "unknown",
        }
        s = s + ")\n"

        s = s + "  Inputs: "
        for input_id in op.input_ids {
            s = s + input_id as string + " "
        }
        s = s + "\n"

        s = s + "  Outputs: "
        for output_id in op.output_ids {
            s = s + output_id as string + " "
        }
        s = s + "\n"
    }

    s = s + "\n"
    s
}

func print_graph_values(g: *computation_graph) string {
    s = ""
    s = s + "========== Values ==========\n"

    for i, vt in g.values {
        s = s + "Value " + i as string + ": "
        s = s + vt.dtype + " "
        s = s + vt.shape_str()
        s = s + " (" + vt.memory_bytes() as string + " bytes)\n"
    }

    s = s + "\n"
    s
}

func print_graph_structure(g: *computation_graph) string {
    s = print_graph_info(g)
    s = s + print_graph_operations(g)
    s = s + print_graph_values(g)
    s
}

func print_graph_dataflow(g: *computation_graph) string {
    s = ""
    s = s + "========== Data Flow ==========\n"

    for op in g.operations {
        s = s + "Op " + op.id as string + " (" + op.name + "):\n"

        s = s + "  Producers:\n"
        for input_id in op.input_ids {
            producers = g.find_producers(input_id)
            for producer in producers {
                s = s + "    Value " + input_id as string + " from Op " + producer.id as string + "\n"
            }
        }

        s = s + "  Consumers:\n"
        for output_id in op.output_ids {
            consumers = g.find_consumers(output_id)
            for consumer in consumers {
                s = s + "    Value " + output_id as string + " to Op " + consumer.id as string + "\n"
            }
        }
    }

    s = s + "\n"
    s
}

func print_graph_dot_format(g: *computation_graph) string {
    s = ""
    s = s + "digraph computation_graph {\n"
    s = s + "  rankdir=LR;\n"
    s = s + "  node [shape=box];\n"
    s = s + "\n"

    for op in g.operations {
        s = s + "  node_" + op.id as string + " [label=\"" + op.name + "\"];\n"
    }

    s = s + "\n"

    for op in g.operations {
        for input_id in op.input_ids {
            producers = g.find_producers(input_id)
            for producer in producers {
                s = s + "  node_" + producer.id as string + " -> node_" + op.id as string + ";\n"
            }
        }
    }

    s = s + "}\n"
    s
}
