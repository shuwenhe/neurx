package neurx.compile.pass_manager

use neurx.runtime.compile

struct pass_plan_state {
    []string passes
    bool has_shape_infer
    bool has_fusion
    bool has_lowering
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

func default_passes(string mode, bool dynamic, bool fullgraph) []string {
    []string passes = []
    passes.push("normalize")
    passes.push("shape_infer")
    passes.push("const_fold")
    passes.push("dead_code_elim")
    if mode == "reduce-overhead" || mode == "max-autotune" {
        passes.push("fuse_linear_activation")
    }
    if fullgraph {
        passes.push("fullgraph_partition")
    }
    if dynamic {
        passes.push("dynamic_shape_specialize")
    }
    passes.push("lower_graph")
    passes
}

func new_pass_plan_state(string mode, bool dynamic, bool fullgraph) pass_plan_state {
    []string passes = default_passes(mode, dynamic, fullgraph)
    pass_plan_state {
        passes: passes,
        has_shape_infer: true,
        has_fusion: mode == "reduce-overhead" || mode == "max-autotune",
        has_lowering: true,
    }
}

func apply_pass_plan(compile_state state, pass_plan_state plan) compile_state {
    compile_state next = state
    int i = 0
    while i < len(plan.passes) {
        string pass_name = plan.passes[i]
        next = compile_add_pass(next, pass_name)
        if pass_name == "shape_infer" {
            next = compile_shape_specialize(next)
        }
        if pass_name == "fuse_linear_activation" {
            next = compile_fuse_linear_activation(next)
        }
        if pass_name == "lower_graph" {
            next = compile_lower_graph(next)
            next = compile_linearize(next)
        }
        i = i + 1
    }
    next
}

func pass_count(pass_plan_state plan) int {
    len(plan.passes)
}

func pass_plan_state_dict(pass_plan_state plan) pass_plan_state {
    plan
}

func pass_plan_load_state_dict(pass_plan_state plan, pass_plan_state other) pass_plan_state {
    other
}
