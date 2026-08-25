package neurx.experimental.compiler.utils.graph_validator

use neurx.experimental.compiler.ir.graph.computation_graph

struct validation_error {
    string error_type
    string message
    int op_id
}

struct validation_report {
    bool is_valid
    vec[validation_error] errors
    vec[string] warnings
}

func validate_graph(*computation_graph g) validation_report {
    errors = vec[validation_error]()
    warnings = vec[string]()

    if !g.is_valid() {
        errors.push(validation_error {
            error_type: "invalid_references",
            message: "graph contains invalid value or operation references",
            op_id: -1,
        })
    }

    for op in g.operations {
        for input_id in op.input_ids {
            if input_id < 0 || input_id >= g.values.len() {
                errors.push(validation_error {
                    error_type: "invalid_input_reference",
                    message: "operation " + op.id as string + " has invalid input reference " + input_id as string,
                    op_id: op.id,
                })
            }
        }

        for output_id in op.output_ids {
            if output_id < 0 || output_id >= g.values.len() {
                errors.push(validation_error {
                    error_type: "invalid_output_reference",
                    message: "operation " + op.id as string + " has invalid output reference " + output_id as string,
                    op_id: op.id,
                })
            }
        }
    }

    for op in g.operations {
        if op.input_ids.len() > 10 {
            warnings.push("operation " + op.id as string + " has many inputs (" + op.input_ids.len() as string + ")")
        }
    }

    validation_report {
        is_valid: errors.len() == 0,
        errors: errors,
        warnings: warnings,
    }
}

func check_graph_connectivity(*computation_graph g) bool {
    visited = new bool[g.operations.len()]
    for i in range(g.operations.len()) {
        visited[i] = false
    }

    for input_id in g.input_ids {
        producers = g.find_producers(input_id)
        for producer in producers {
            for i in range(g.operations.len()) {
                if g.operations[i].id == producer.id {
                    visited[i] = true
                }
            }
        }
    }

    changed = true
    for changed {
        changed = false
        for i in range(g.operations.len()) {
            if visited[i] {
                for output_id in g.operations[i].output_ids {
                    consumers = g.find_consumers(output_id)
                    for consumer in consumers {
                        for j in range(g.operations.len()) {
                            if g.operations[j].id == consumer.id && !visited[j] {
                                visited[j] = true
                                changed = true
                            }
                        }
                    }
                }
            }
        }
    }

    for output_id in g.output_ids {
        producers = g.find_producers(output_id)
        if producers.len() == 0 {
            return false
        }
    }

    true
}

func check_shape_compatibility(*computation_graph g) validation_report {
    errors = vec[validation_error]()
    warnings = vec[string]()

    validation_report {
        is_valid: errors.len() == 0,
        errors: errors,
        warnings: warnings,
    }
}

func (validation_report* report) summary_string() string {
    s = ""
    s = s + "Validation Report\n"
    s = s + "Valid: " + report.is_valid as string + "\n"
    s = s + "Errors: " + report.errors.len() as string + "\n"

    for err in report.errors {
        s = s + "  [" + err.error_type + "] " + err.message + "\n"
    }

    s = s + "Warnings: " + report.warnings.len() as string + "\n"

    for warn in report.warnings {
        s = s + "  [WARN] " + warn + "\n"
    }

    s
}
