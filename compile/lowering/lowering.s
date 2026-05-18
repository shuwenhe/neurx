package neurx.compile.lowering

use neurx.runtime.compile

struct lowering_plan_state {
    string backend
    string target
    bool lowered
    bool compiled
}

func new_lowering_plan_state(string backend) lowering_plan_state {
    string target = "cpu_ref"
    if backend == "aot" {
        target = "aot_ref"
    }
    lowering_plan_state {
        backend: backend,
        target: target,
        lowered: false,
        compiled: false,
    }
}

func lower_compile_state(compile_state state, lowering_plan_state plan) compile_state {
    compile_state next = compile_set_lowered(state, true)
    next = compile_add_pass(next, "lower")
    next = compile_add_tag(next, "target=" + plan.target)
    if plan.backend == "aot" {
        next = compile_set_compiled(next, true)
        next = compile_add_pass(next, "compile")
    }
    next
}

func mark_lowered(lowering_plan_state plan, bool lowered, bool compiled) lowering_plan_state {
    lowering_plan_state {
        backend: plan.backend,
        target: plan.target,
        lowered: lowered,
        compiled: compiled,
    }
}

func lowering_plan_state_dict(lowering_plan_state plan) lowering_plan_state {
    plan
}

func lowering_plan_load_state_dict(lowering_plan_state plan, lowering_plan_state other) lowering_plan_state {
    other
}
