package neurx.compile.pass_manager
use neurx.strings
use neurx.runtime.compile
struct pass_plan_state {
    []string passes
    bool has_shape_infer
    bool has_fusion
    bool has_lowering
}

func default_passes(string mode, bool dynamic, bool fullgraph) []string {
    []string passes = []
    passes = append(passes, "normalize")
    passes = append(passes, "shape_infer")
    passes = append(passes, "const_fold")
    passes = append(passes, "dead_code_elim")
    if mode == "reduce-overhead" || mode == "max-autotune" {
        passes = append(passes, "fuse_linear_activation")
    }
    if fullgraph {
        passes = append(passes, "fullgraph_partition")
    }
    if dynamic {
        passes = append(passes, "dynamic_shape_specialize")
    }
    passes = append(passes, "lower_graph")
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

func pass_count(pass_plan_state plan) int {
    int count = len(plan.passes)
    count
}

func get_pass(pass_plan_state plan, int index) string {
    plan.passes[index]
}

func apply_pass_plan(compile_state state, pass_plan_state plan) compile_state {
    compile_state next = state
    int i = 0
    int passes_len = pass_count(plan)
    for i < passes_len {
        string pass_name = get_pass(plan, i)
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

func pass_plan_load_state_dict(pass_plan_state plan, pass_plan_state other) pass_plan_state {
    other
}
