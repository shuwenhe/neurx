package main

use neurx.compilation.ir.graph.new_computation_graph
use neurx.compilation.ir.value.{value_type_float32, value_type_int32}
use neurx.compilation.ir.operation.op_type
use neurx.compilation.compiler.graph_compiler.{new_graph_compiler_default, graph_compiler}
use neurx.compilation.compiler.compilation_unit.default_compilation_config
use neurx.compilation.utils.graph_printer.print_graph_structure
use neurx.compilation.utils.graph_validator.validate_graph
use neurx.compilation.utils.performance_meter.estimate_graph_performance
use neurx.compilation.executor.runtime_executor.execute_operation_sequence

func main() {
    println("=== NeurX Compilation Framework Example ===")
    println("")

    g = new_computation_graph("simple_mlp")

    input_shape = new int[2]
    input_shape[0] = 32
    input_shape[1] = 784

    input_value_id = g.add_value(value_type_float32(input_shape))
    g.add_input(input_value_id)

    hidden1_shape = new int[2]
    hidden1_shape[0] = 32
    hidden1_shape[1] = 512
    hidden1_id = g.add_value(value_type_float32(hidden1_shape))

    weight1_shape = new int[2]
    weight1_shape[0] = 784
    weight1_shape[1] = 512
    weight1_id = g.add_value(value_type_float32(weight1_shape))

    matmul1_id = g.add_operation(op_type::matrix_multiply, "matmul1", new int[]{input_value_id, weight1_id}, new int[]{hidden1_id})

    hidden1_relu_shape = new int[2]
    hidden1_relu_shape[0] = 32
    hidden1_relu_shape[1] = 512
    hidden1_relu_id = g.add_value(value_type_float32(hidden1_relu_shape))

    relu1_id = g.add_operation(op_type::relu, "relu1", new int[]{hidden1_id}, new int[]{hidden1_relu_id})

    output_shape = new int[2]
    output_shape[0] = 32
    output_shape[1] = 10
    output_id = g.add_value(value_type_float32(output_shape))

    weight2_shape = new int[2]
    weight2_shape[0] = 512
    weight2_shape[1] = 10
    weight2_id = g.add_value(value_type_float32(weight2_shape))

    matmul2_id = g.add_operation(op_type::matrix_multiply, "matmul2", new int[]{hidden1_relu_id, weight2_id}, new int[]{output_id})

    g.add_output(output_id)

    println("=== Original Graph ===")
    println(print_graph_structure(g))
    println("")

    validation = validate_graph(g)
    println("Graph validation: " + validation.is_valid as string)
    println("")

    metrics_before = estimate_graph_performance(g)
    println("Performance before optimization:")
    println(metrics_before.summary_string())
    println("")

    compiler = new_graph_compiler_default()
    config = default_compilation_config()

    println("=== Compiling with O2 Optimization ===")
    unit = compiler.compile_with_config(g, "mlp_optimized", config)
    println("")

    println("=== Compilation Statistics ===")
    println(compiler.dump_compilation_stats(unit))
    println("")

    println("=== Optimized Graph ===")
    println(print_graph_structure(unit.optimized_graph))
    println("")

    exec_result = execute_operation_sequence(unit.optimized_graph)
    println("Execution result:")
    println(exec_result.summary_string())
    println("")

    println("=== Compilation Complete ===")
}
