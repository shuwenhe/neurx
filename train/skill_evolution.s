package neurx.train.skill_evolution

use neurx.agent.skill_feedback
use neurx.registry.skill_registry
use neurx.agent.skill_synthesizer
use neurx.agent.skill_evaluator
use neurx.agent.skill_schema
use neurx.runtime.io.{runtime_write_text_file}

struct skill_evolution_config {
    int max_generations
    float promotion_threshold
    float retire_threshold
    float min_success_rate
    int max_avg_steps
}

struct skill_evolution_metrics {
    int generation
    int collected
    int synthesized
    int evaluated
    int promoted
    int retired
}

struct skill_evolution_state {
    skill_evolution_config config
    agent_skill_registry_state registry
    skill_evolution_metrics metrics
    bool finished
}

func new_skill_evolution_config(int max_generations, float promotion_threshold, float retire_threshold, float min_success_rate, int max_avg_steps) skill_evolution_config {
    skill_evolution_config {
        max_generations: max_generations,
        promotion_threshold: promotion_threshold,
        retire_threshold: retire_threshold,
        min_success_rate: min_success_rate,
        max_avg_steps: max_avg_steps,
    }
}

func new_skill_evolution_metrics() skill_evolution_metrics {
    skill_evolution_metrics {
        generation: 0,
        collected: 0,
        synthesized: 0,
        evaluated: 0,
        promoted: 0,
        retired: 0,
    }
}

func new_skill_evolution_state(skill_evolution_config config) skill_evolution_state {
    skill_evolution_state {
        config: config,
        registry: new_agent_skill_registry_state(),
        metrics: new_skill_evolution_metrics(),
        finished: false,
    }
}

func skill_evolution_state_dict(skill_evolution_state state) skill_evolution_state {
    skill_evolution_state {
        config: state.config,
        registry: agent_skill_registry_state_dict(state.registry),
        metrics: state.metrics,
        finished: state.finished,
    }
}

func skill_evolution_load_state_dict(skill_evolution_state state, skill_evolution_state other) skill_evolution_state {
    skill_evolution_state {
        config: other.config,
        registry: agent_skill_registry_load_state_dict(state.registry, other.registry),
        metrics: other.metrics,
        finished: other.finished,
    }
}

func skill_evolution_should_finish(skill_evolution_state state) bool {
    if state.finished {
        return true
    }
    state.metrics.generation >= state.config.max_generations
}

func skill_evolution_collect(skill_evolution_state state, agent_skill_feedback_state feedback) skill_evolution_state {
    skill_evolution_metrics metrics = state.metrics
    metrics.collected = metrics.collected + 1
    agent_skill_registry_state registry = state.registry
    agent_skill_record record = agent_skill_synthesize(feedback)
    registry = agent_skill_registry_add(registry, record)
    skill_evolution_state {
        config: state.config,
        registry: registry,
        metrics: metrics,
        finished: state.finished,
    }
}

func skill_evolution_step(skill_evolution_state state, agent_skill_feedback_state feedback) skill_evolution_state {
    if skill_evolution_should_finish(state) {
        return state
    }

    skill_evolution_metrics metrics = state.metrics
    metrics.generation = metrics.generation + 1
    metrics.synthesized = metrics.synthesized + 1

    agent_skill_record record = agent_skill_synthesize(feedback)
    agent_skill_eval_result result = agent_skill_evaluate(record, state.config.promotion_threshold, state.config.retire_threshold)
    metrics.evaluated = metrics.evaluated + 1

    agent_skill_registry_state registry = state.registry
    registry = agent_skill_registry_add(registry, record)

    if result.should_promote && record.metrics.success_rate >= state.config.min_success_rate && record.metrics.avg_steps <= float(state.config.max_avg_steps) {
        registry = agent_skill_registry_promote(registry, record.spec.name)
        metrics.promoted = metrics.promoted + 1
    } else if result.should_retire {
        registry = agent_skill_registry_retire(registry, record.spec.name)
        metrics.retired = metrics.retired + 1
    }

    bool finished = metrics.generation >= state.config.max_generations
    skill_evolution_state {
        config: state.config,
        registry: registry,
        metrics: metrics,
        finished: finished,
    }
}

func skill_evolution_state_string(skill_evolution_state state) string {
    "generation=" + string(state.metrics.generation) + " promoted=" + string(state.metrics.promoted) + " retired=" + string(state.metrics.retired)
}

func skill_evolution_registry_snapshot(skill_evolution_state state) string {
    agent_skill_registry_snapshot(state.registry)
}

func skill_evolution_candidate_report(skill_evolution_state state) string {
    string out = skill_evolution_state_string(state)
    out = out + "\ncollected=" + string(state.metrics.collected)
    out = out + "\nsynthesized=" + string(state.metrics.synthesized)
    out = out + "\nevaluated=" + string(state.metrics.evaluated)
    out = out + "\n" + skill_evolution_registry_snapshot(state)
    out
}

func skill_evolution_persist_registry_snapshot(skill_evolution_state state, string path) string {
    runtime_write_text_file(path, skill_evolution_registry_snapshot(state))
    path
}

func skill_evolution_persist_candidate_report(skill_evolution_state state, string path) string {
    runtime_write_text_file(path, skill_evolution_candidate_report(state))
    path
}
