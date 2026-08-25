package neurx.experimental.compiler.ir.graph

use neurx.experimental.compiler.ir.value.{value_type, tensor_value}
use neurx.experimental.compiler.ir.operation.{operation, op_type}

struct computation_graph {
    string graph_name
    int next_value_id
    int next_op_id
    vec[value_type] values
    vec[operation] operations
    int[] input_ids
    int[] output_ids
}

struct graph_node {
    int op_id
    operation op
    vec[int] input_node_ids
    vec[int] output_node_ids
}

func new_computation_graph(string name) computation_graph {
    computation_graph {
        graph_name: name,
        next_value_id: 0,
        next_op_id: 0,
        values: vec[value_type](),
        operations: vec[operation](),
        input_ids: new int[0],
        output_ids: new int[0],
    }
}

func (mut computation_graph* g) add_value(value_type vt) int {
    int value_id = g.next_value_id
    g.next_value_id = g.next_value_id + 1
    g.values.push(vt)
    value_id
}

func (mut computation_graph* g) add_operation(op_type op_kind, string op_name, int[] input_ids, int[] output_ids) int {
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
    g.operations.push(op)
    op_id
}

func (mut computation_graph* g) add_input(int value_id) int {
    input_op_id = g.add_operation(op_type::input, "input_" + value_id as string, new int[0], new int[]{value_id})
    g.input_ids.push(value_id)
    input_op_id
}

func (mut computation_graph* g) add_output(int value_id) int {
    output_op_id = g.add_operation(op_type::output, "output_" + value_id as string, new int[]{value_id}, new int[0])
    g.output_ids.push(value_id)
    output_op_id
}

func (computation_graph* g) get_value(int value_id) option[value_type] {
    if value_id >= 0 && value_id < g.values.len() {
        option::some(g.values[value_id])
    } else {
        option::none
    }
}

func (computation_graph* g) get_operation(int op_id) option[operation] {
    if op_id >= 0 && op_id < g.operations.len() {
        option::some(g.operations[op_id])
    } else {
        option::none
    }
}

func (computation_graph* g) get_operation_by_name(string name) option[operation] {
    for op in g.operations {
        if op.name == name {
            return option::some(op)
        }
    }
    option::none
}

func (computation_graph* g) operation_count() int {
    g.operations.len()
}

func (computation_graph* g) value_count() int {
    g.values.len()
}

func (computation_graph* g) input_count() int {
    g.input_ids.len()
}

func (computation_graph* g) output_count() int {
    g.output_ids.len()
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
            if input_id < 0 || input_id >= g.values.len() {
                return false
            }
        }
        for output_id in op.output_ids {
            if output_id < 0 || output_id >= g.values.len() {
                return false
            }
        }
    }
    true
}

func (computation_graph* g) find_producers(int value_id) vec[operation] {
    producers = vec[operation]()
    for op in g.operations {
        for output_id in op.output_ids {
            if output_id == value_id {
                producers.push(op)
            }
        }
    }
    producers
}

func (computation_graph* g) find_consumers(int value_id) vec[operation] {
    consumers = vec[operation]()
    for op in g.operations {
        for input_id in op.input_ids {
            if input_id == value_id {
                consumers.push(op)
            }
        }
    }
    consumers
}

func (computation_graph* g) topological_sort() vec[int] {
    sorted_ops = vec[int]()
    in_degree = new int[g.operations.len()]
    for i in range(g.operations.len()) {
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

    queue = vec[int]()
    for i in range(g.operations.len()) {
        if in_degree[i] == 0 {
            queue.push(i)
        }
    }

    for queue.len() > 0 {
        op_idx = queue[0]
        sorted_ops.push(op_idx)

        op = g.operations[op_idx]
        for output_id in op.output_ids {
            consumers = g.find_consumers(output_id)
            for consumer in consumers {
                for j in range(g.operations.len()) {
                    if g.operations[j].id == consumer.id {
                        in_degree[j] = in_degree[j] - 1
                        if in_degree[j] == 0 {
                            queue.push(j)
                        }
                    }
                }
            }
        }

        queue = queue[1:]
    }

    sorted_ops
}
