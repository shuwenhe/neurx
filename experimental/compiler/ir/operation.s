package neurx.experimental.compiler.ir.operation

use neurx.experimental.compiler.ir.value.{value_type, tensor_value, attr_value}

enum op_type {
    add,
    subtract,
    multiply,
    divide,
    matrix_multiply,
    convolution,
    relu,
    gelu,
    softmax,
    layer_norm,
    batch_norm,
    pool_max,
    pool_avg,
    reshape,
    transpose,
    slice,
    concat,
    split,
    reduce_sum,
    reduce_mean,
    reduce_max,
    constant,
    variable,
    input,
    output,
}

struct operation {
    int id
    op_type op_kind
    string name
    int[] input_ids
    int[] output_ids
    attr_value[] attributes
}

struct operation_def {
    op_type op_kind
    string op_name
    int num_inputs
    int num_outputs
    string description
}

func get_op_definition(op_type op_kind) operation_def {
    match op_kind {
        op_type::add: operation_def {
            op_kind: op_type::add,
            op_name: "add",
            num_inputs: 2,
            num_outputs: 1,
            description: "element-wise addition",
        },
        op_type::subtract: operation_def {
            op_kind: op_type::subtract,
            op_name: "subtract",
            num_inputs: 2,
            num_outputs: 1,
            description: "element-wise subtraction",
        },
        op_type::multiply: operation_def {
            op_kind: op_type::multiply,
            op_name: "multiply",
            num_inputs: 2,
            num_outputs: 1,
            description: "element-wise multiplication",
        },
        op_type::matrix_multiply: operation_def {
            op_kind: op_type::matrix_multiply,
            op_name: "matmul",
            num_inputs: 2,
            num_outputs: 1,
            description: "matrix multiplication",
        },
        op_type::relu: operation_def {
            op_kind: op_type::relu,
            op_name: "relu",
            num_inputs: 1,
            num_outputs: 1,
            description: "rectified linear unit activation",
        },
        op_type::gelu: operation_def {
            op_kind: op_type::gelu,
            op_name: "gelu",
            num_inputs: 1,
            num_outputs: 1,
            description: "gaussian error linear unit activation",
        },
        op_type::softmax: operation_def {
            op_kind: op_type::softmax,
            op_name: "softmax",
            num_inputs: 1,
            num_outputs: 1,
            description: "softmax activation",
        },
        op_type::layer_norm: operation_def {
            op_kind: op_type::layer_norm,
            op_name: "layer_norm",
            num_inputs: 1,
            num_outputs: 1,
            description: "layer normalization",
        },
        op_type::reshape: operation_def {
            op_kind: op_type::reshape,
            op_name: "reshape",
            num_inputs: 2,
            num_outputs: 1,
            description: "reshape tensor",
        },
        op_type::transpose: operation_def {
            op_kind: op_type::transpose,
            op_name: "transpose",
            num_inputs: 1,
            num_outputs: 1,
            description: "transpose tensor",
        },
        op_type::reduce_sum: operation_def {
            op_kind: op_type::reduce_sum,
            op_name: "reduce_sum",
            num_inputs: 1,
            num_outputs: 1,
            description: "reduce sum over dimensions",
        },
        op_type::reduce_mean: operation_def {
            op_kind: op_type::reduce_mean,
            op_name: "reduce_mean",
            num_inputs: 1,
            num_outputs: 1,
            description: "reduce mean over dimensions",
        },
        op_type::constant: operation_def {
            op_kind: op_type::constant,
            op_name: "constant",
            num_inputs: 0,
            num_outputs: 1,
            description: "constant value",
        },
        op_type::input: operation_def {
            op_kind: op_type::input,
            op_name: "input",
            num_inputs: 0,
            num_outputs: 1,
            description: "graph input",
        },
        op_type::output: operation_def {
            op_kind: op_type::output,
            op_name: "output",
            num_inputs: 1,
            num_outputs: 0,
            description: "graph output",
        },
        default: operation_def {
            op_kind: op_kind,
            op_name: "unknown",
            num_inputs: 0,
            num_outputs: 0,
            description: "unknown operation",
        },
    }
}

func new_operation(int id, op_type op_kind, string name, int[] input_ids, int[] output_ids) operation {
    operation {
        id: id,
        op_kind: op_kind,
        name: name,
        input_ids: input_ids,
        output_ids: output_ids,
        attributes: new attr_value[0],
    }
}

func (mut operation* op) add_attribute(string key, string value) {
    attr = attr_value {
        key: key,
        value_str: value,
    }
    op.attributes.push(attr)
}

func (operation* op) get_attribute(string key) option[string] {
    for attr in op.attributes {
        if attr.key == key {
            return option::some(attr.value_str)
        }
    }
    option::none
}

func (operation* op) num_inputs() int {
    op.input_ids.len()
}

func (operation* op) num_outputs() int {
    op.output_ids.len()
}
