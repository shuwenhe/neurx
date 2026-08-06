package neurx.compile.executor
use neurx.runtime.compile

struct executor_plan_state {
    string backend
    bool can_execute
    bool async_enabled
    int launch_count
}

func new_executor_plan_state(string backend) executor_plan_state {
    executor_plan_state {
        backend: backend,
        can_execute: true,
        async_enabled: backend != "eager",
        launch_count: 0,
    }
}

func execute_compile_state(compile_state state, executor_plan_state plan) compile_state {
    if !plan.can_execute {
        return state
    }
    compile_state next = state
    if !next.compiled {
        next = compile_set_compiled(next, true)
        next = compile_add_pass(next, "compile")
    }
    next = compile_set_executed(next, true)
    compile_add_pass(next, "execute")
}

func executor_mark_launch(executor_plan_state plan) executor_plan_state {
    executor_plan_state {
        backend: plan.backend,
        can_execute: plan.can_execute,
        async_enabled: plan.async_enabled,
        launch_count: plan.launch_count + 1,
    }
}

func executor_plan_state_dict(executor_plan_state plan) executor_plan_state {
    plan
}

func executor_plan_load_state_dict(executor_plan_state plan, executor_plan_state other) executor_plan_state {
    other
}

