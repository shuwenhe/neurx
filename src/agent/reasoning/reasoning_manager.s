package neurx.reasoning.reasoning_manager

use neurx.reasoning.cot_config.cot_config
use neurx.reasoning.reasoning_chain.{reasoning_chain, chain_state}
use neurx.reasoning.reasoning_step.{reasoning_step, step_type}
use neurx.reasoning.prompt_engineer.prompt_engineer
use neurx.reasoning.reasoning_validator.{reasoning_validator, validation_result}

struct reasoning_manager {
    map[string]reasoning_chain chains
    prompt_engineer engineer
    reasoning_validator validator
    int next_chain_id
    int max_active_chains
    map[string]map[string]string] history
}

func new_reasoning_manager(cot_config config) reasoning_manager {
    reasoning_manager {
        chains: map[string]reasoning_chain{},
        engineer: new_prompt_engineer(config),
        validator: new_reasoning_validator(config),
        next_chain_id: 1,
        max_active_chains: 100,
        history: map[string]map[string]string]{},
    }
}

func (mgr: &reasoning_manager) start_reasoning_chain(string user_prompt, cot_config config) reasoning_chain {
    if len(mgr.chains) >= mgr.max_active_chains {
        return reasoning_chain{}
    }

    chain_id := "chain_" + string(mgr.next_chain_id)
    mgr.next_chain_id = mgr.next_chain_id + 1

    chain := new_reasoning_chain(chain_id, user_prompt, config)
    chain = chain.start()

    mgr.chains[chain_id] = chain
    mgr.history[chain_id] = map[string]string{}

    chain
}

func (mgr: &reasoning_manager) add_reasoning_step(string chain_id, reasoning_step step) bool {
    if chain, exists := mgr.chains[chain_id]; exists {
        if chain.state == chain_state.running {
            mgr.chains[chain_id] = chain.add_step(step)
            return true
        }
    }
    false
}

func (mgr: &reasoning_manager) update_step(string chain_id, int step_index, string reasoning, string result, float confidence) bool {
    if chain, exists := mgr.chains[chain_id]; exists {
        if step_index >= 0 && step_index < len(chain.steps) {
            updated_step := chain.steps[step_index]
            updated_step = updated_step.complete(reasoning, result, confidence)
            chain.steps[step_index] = updated_step
            mgr.chains[chain_id] = chain
            return true
        }
    }
    false
}

func (mgr: &reasoning_manager) complete_reasoning_chain(string chain_id, string final_answer) bool {
    if chain, exists := mgr.chains[chain_id]; exists {
        completed_chain := chain.complete(final_answer)

        validation := mgr.validator.validate_chain(completed_chain)
        if validation.is_valid {
            mgr.chains[chain_id] = completed_chain

            mgr.save_to_history(chain_id, completed_chain)
            return true
        }
    }
    false
}

func (mgr: &reasoning_manager) fail_reasoning_chain(string chain_id, string error_msg) bool {
    if chain, exists := mgr.chains[chain_id]; exists {
        mgr.chains[chain_id] = chain.fail(error_msg)
        return true
    }
    false
}

func (mgr: &reasoning_manager) get_chain(string chain_id) reasoning_chain {
    if chain, exists := mgr.chains[chain_id]; exists {
        return chain
    }
    reasoning_chain{}
}

func (mgr: &reasoning_manager) get_active_chains() []reasoning_chain {
    chains := []reasoning_chain{}
    for _, chain := range mgr.chains {
        if chain.state == chain_state.running {
            chains = append(chains, chain)
        }
    }
    chains
}

func (mgr: &reasoning_manager) get_chain_count() int {
    len(mgr.chains)
}

func (mgr: &reasoning_manager) generate_next_prompt(string chain_id) string {
    if chain, exists := mgr.chains[chain_id]; exists {
        if chain.current_step_index < len(chain.steps) {
            current_step := chain.steps[chain.current_step_index]
            return mgr.engineer.get_step_prompt(
                current_step.reasoning,
                current_step.intermediate_result,
                chain.current_step_index + 1,
            )
        }
    }
    ""
}

func (mgr: &reasoning_manager) validate_chain(string chain_id) validation_result {
    if chain, exists := mgr.chains[chain_id]; exists {
        return mgr.validator.validate_chain(chain)
    }
    validation_result{
        is_valid: false,
        message: "Chain not found",
        issues: [],
        confidence_score: 0.0,
        severity_level: 2,
    }
}

func (mgr: &reasoning_manager) backtrack_chain(string chain_id, int depth) bool {
    if chain, exists := mgr.chains[chain_id]; exists {
        if chain.can_backtrack() {
            mgr.chains[chain_id] = chain.backtrack(depth)
            return true
        }
    }
    false
}

func (mgr: &reasoning_manager) get_reasoning_summary(string chain_id) string {
    if chain, exists := mgr.chains[chain_id]; exists {
        return chain.get_reasoning_text()
    }
    ""
}

func (mgr: &reasoning_manager) cleanup_completed_chains() int {
    to_delete := []string{}

    for chain_id, chain := range mgr.chains {
        if chain.state == chain_state.completed || chain.state == chain_state.failed {
            to_delete = append(to_delete, chain_id)
        }
    }

    i := 0
    while i < len(to_delete) {
        delete(mgr.chains, to_delete[i])
        i = i + 1
    }

    len(to_delete)
}

func (mgr: &reasoning_manager) save_to_history(string chain_id, reasoning_chain chain) {
    step_history := map[string]string{}

    i := 0
    while i < len(chain.steps) {
        step := chain.steps[i]
        key := "step_" + string(i)
        step_history[key] = step.format_step()
        i = i + 1
    }

    mgr.history[chain_id] = step_history
}

func (mgr: &reasoning_manager) get_history(string chain_id) map[string]string {
    if history, exists := mgr.history[chain_id]; exists {
        return history
    }
    map[string]string{}
}

func (mgr: &reasoning_manager) get_statistics() map[string]string {
    stats := map[string]string{}

    total := len(mgr.chains)
    running := 0
    completed := 0
    failed := 0

    for _, chain := range mgr.chains {
        if chain.state == chain_state.running {
            running = running + 1
        } else if chain.state == chain_state.completed {
            completed = completed + 1
        } else if chain.state == chain_state.failed {
            failed = failed + 1
        }
    }

    stats["total_chains"] = string(total)
    stats["running_chains"] = string(running)
    stats["completed_chains"] = string(completed)
    stats["failed_chains"] = string(failed)

    stats
}

func (mgr: &reasoning_manager) batch_start_reasoning([]string prompts, cot_config config) []reasoning_chain {
    chains := []reasoning_chain{}

    i := 0
    while i < len(prompts) {
        chain := mgr.start_reasoning_chain(prompts[i], config)
        chains = append(chains, chain)
        i = i + 1
    }

    chains
}

func (mgr: &reasoning_manager) clear_all() {
    mgr.chains = map[string]reasoning_chain{}
    mgr.history = map[string]map[string]string]{}
    mgr.next_chain_id = 1
}

func map_values[K comparable, V any](m map[K]V) []V {
    values := []V{}
    for _, v := range m {
        values = append(values, v)
    }
    values
}
