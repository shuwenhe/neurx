package neurx.experimental.compiler.ir.graph

use neurx.experimental.compiler.ir.value.{value_type, tensor_value}
use neurx.experimental.compiler.ir.operation.{operation, op_type}

struct computation_graph {
    string graph_name
    int next_value_id
    int next_op_id
    value_type[] values
    operation[] operations
    []int input_ids
    []int output_ids
}

struct graph_node {
    int op_id
    operation op
    []int input_node_ids
    []int output_node_ids
}

func new_computation_graph(string name) computation_graph {
    computation_graph {
        graph_name: name,
        next_value_id: 0,
        next_op_id: 0,
        values: value_type[](),
        operations: operation[](),
        input_ids: new int[0],
        output_ids: new int[0],
    }
}

func (computation_graph* g) add_value(value_type vt) int {
    int value_id = g.next_value_id
    g.next_value_id = g.next_value_id + 1
    g.values = append(g.values, vt)
    value_id
}

func (computation_graph* g) add_operation(op_type op_kind, string op_name, []int input_ids, []int output_ids) int {
    int op_id = g.next_op_id
    g.next_op_id = g.next_op_id + 1
    op = operation {
        id: op_id,
        op_kind: op_kind,
        name: op_name,
        input_ids: input_ids,
        output_ids: output_ids,
        attributes: new attr_value[0],
    }
    g.operations = append(g.operations, op)
    op_id
}

func (computation_graph* g) add_input(int value_id) int {
    input_op_id = g.add_operation(op_type_input, "input_" + value_id as string, new int[0], new []int{value_id})
    g.input_ids = append(g.input_ids, value_id)
    input_op_id
}

func (computation_graph* g) add_output(int value_id) int {
    output_op_id = g.add_operation(op_type_output, "output_" + value_id as string, new []int{value_id}, new int[0])
    g.output_ids = append(g.output_ids, value_id)
    output_op_id
}

func (computation_graph* g) get_value(int value_id) option[value_type] {
    if value_id >= 0 && value_id < len(g.values) {
        some(g.values[value_id])
    } else {
        nil
    }
}

func (computation_graph* g) get_operation(int op_id) option[operation] {
    if op_id >= 0 && op_id < len(g.operations) {
        some(g.operations[op_id])
    } else {
        nil
    }
}

func (computation_graph* g) get_operation_by_name(string name) option[operation] {
    for op in g.operations {
        if op.name == name {
            return some(op)
        }
    }
    nil
}

func (computation_graph* g) operation_count() int {
    len(g.operations)
}

func (computation_graph* g) value_count() int {
    len(g.values)
}

func (computation_graph* g) input_count() int {
    len(g.input_ids)
}

func (computation_graph* g) output_count() int {
    len(g.output_ids)
}

func (computation_graph* g) total_memory_bytes() int {
    int total = 0
    for vt in g.values {
        total = total + vt.memory_bytes()
    }
    total
}

func (computation_graph* g) is_valid() bool {
    for op in g.operations {
        for input_id in op.input_ids {
            if input_id < 0 || input_id >= len(g.values) {
                return false
            }
        }
        for output_id in op.output_ids {
            if output_id < 0 || output_id >= len(g.values) {
                return false
            }
        }
    }
    true
}

func (computation_graph* g) find_producers(int value_id) []operation {
    producers = operation[]()
    for op in g.operations {
        for output_id in op.output_ids {
            if output_id == value_id {
                producers = append(producers, op)
            }
        }
    }
    producers
}

func (computation_graph* g) find_consumers(int value_id) []operation {
    consumers = operation[]()
    for op in g.operations {
        for input_id in op.input_ids {
            if input_id == value_id {
                consumers = append(consumers, op)
            }
        }
    }
    consumers
}

func (computation_graph* g) topological_sort() []int {
    sorted_ops = []int()
    in_degree = new int[len(g.operations)]
    for i in range(len(g.operations)) {
        in_degree[i] = 0
    }

    for i, op in g.operations {
        for input_id in op.input_ids {
            producers = g.find_producers(input_id)
            for producer in producers {
                in_degree[i] = in_degree[i] + 1
            }
        }
    }

    queue = []int()
    for i in range(len(g.operations)) {
        if in_degree[i] == 0 {
            queue = append(queue, i)
        }
    }

    for len(queue) > 0 {
        op_idx = queue[0]
        sorted_ops = append(sorted_ops, op_idx)

        op = g.operations[op_idx]
        for output_id in op.output_ids {
            consumers = g.find_consumers(output_id)
            for consumer in consumers {
                for j in range(len(g.operations)) {
                    if g.operations[j].id == consumer.id {
                        in_degree[j] = in_degree[j] - 1
                        if in_degree[j] == 0 {
                            queue = append(queue, j)
                        }
                    }
                }
            }
        }

        queue = queue[1:]
    }

    sorted_ops
}
