package neurx.reasoning.data
use neurx.agent.runtime
struct reasoning_trace_sample_state {
    int step
    string goal
    string task
    string input
    string action
    string observation
    bool ok
}

struct reasoning_trace_dataset_state {
    string source
    []reasoning_trace_sample_state samples
    int cursor
    int epoch
    bool exhausted
}

struct reasoning_trace_step_output {
    reasoning_trace_dataset_state state
    reasoning_trace_sample_state sample
    bool ok
}
func get_reasoning_trace_sample(reasoning_trace_dataset_state state, int index) reasoning_trace_sample_state {
    state.samples[index]
}

func copy_reasoning_trace_samples([]reasoning_trace_sample_state samples) []reasoning_trace_sample_state {
    []reasoning_trace_sample_state out = []reasoning_trace_sample_state{cap: len(samples)}
    int i = 0
    while i < len(samples) {
        out[i] = reasoning_trace_sample_state {
            step: samples[i].step,
            goal: samples[i].goal,
            task: samples[i].task,
            input: samples[i].input,
            action: samples[i].action,
            observation: samples[i].observation,
            ok: samples[i].ok,
        }
        i = i + 1
    }
    out
}

func new_reasoning_trace_dataset_state(string source) reasoning_trace_dataset_state {
    reasoning_trace_dataset_state {
        source: source,
        samples: [],
        cursor: 0,
        epoch: 0,
        exhausted: false,
    }
}

func reasoning_trace_sample_prompt(reasoning_trace_sample_state sample) string {
    string prompt = "### Goal\n" + sample.goal
    prompt = prompt + "\n\n### Current Step\n" + sample.task
    if sample.input != "" {
        prompt = prompt + "\n\n### Input\n" + sample.input
    }
    prompt
}

func reasoning_trace_sample_target(reasoning_trace_sample_state sample) string {
    string target = "### Action\n" + sample.action
    target = target + "\n\n### Observation\n" + sample.observation
    if sample.ok {
        target = target + "\n\n### status\nok"
    } else {
        target = target + "\n\n### status\nfailed"
    }
    target
}

func reasoning_trace_sample_render(reasoning_trace_sample_state sample) string {
    reasoning_trace_sample_prompt(sample) + "\n\n" + reasoning_trace_sample_target(sample)
}

func reasoning_trace_dataset_add_sample(reasoning_trace_dataset_state state, reasoning_trace_sample_state sample) reasoning_trace_dataset_state {
    int size = len(state.samples)
    []reasoning_trace_sample_state samples = []reasoning_trace_sample_state{cap: size + 1}
    int i = 0
    while i < size {
        samples[i] = state.samples[i]
        i = i + 1
    }
    samples[size] = sample
    reasoning_trace_dataset_state {
        source: state.source,
        samples: samples,
        cursor: state.cursor,
        epoch: state.epoch,
        exhausted: state.exhausted,
    }
}

func reasoning_trace_dataset_count(reasoning_trace_dataset_state state) int {
    len(state.samples)
}

func reasoning_trace_dataset_has_next(reasoning_trace_dataset_state state) bool {
    !state.exhausted && state.cursor < len(state.samples)
}

func reasoning_trace_dataset_reset(reasoning_trace_dataset_state state) reasoning_trace_dataset_state {
    reasoning_trace_dataset_state {
        source: state.source,
        samples: copy_reasoning_trace_samples(state.samples),
        cursor: 0,
        epoch: state.epoch + 1,
        exhausted: false,
    }
}

func reasoning_trace_dataset_next(reasoning_trace_dataset_state state) reasoning_trace_step_output {
    if !reasoning_trace_dataset_has_next(state) {
        reasoning_trace_step_output {
            state: reasoning_trace_dataset_state {
                source: state.source,
                samples: copy_reasoning_trace_samples(state.samples),
                cursor: state.cursor,
                epoch: state.epoch,
                exhausted: true,
            },
            sample: reasoning_trace_sample_state {
                step: -1,
                goal: "",
                task: "",
                input: "",
                action: "",
                observation: "",
                ok: false,
            },
            ok: false,
        }
    } else {
        reasoning_trace_sample_state sample = state.samples[state.cursor]
        int next_cursor = state.cursor + 1
        bool next_exhausted = next_cursor >= len(state.samples)
        reasoning_trace_step_output {
            state: reasoning_trace_dataset_state {
                source: state.source,
                samples: copy_reasoning_trace_samples(state.samples),
                cursor: next_cursor,
                epoch: state.epoch,
                exhausted: next_exhausted,
            },
            sample: sample,
            ok: true,
        }
    }
}

func reasoning_trace_dataset_render(reasoning_trace_dataset_state state) string {
    string out = ""
    int i = 0
    while i < len(state.samples) {
        string rendered = reasoning_trace_sample_render(get_reasoning_trace_sample(state, i))
        if rendered != "" {
            if out != "" {
                out = out + "\n\n---\n\n"
            }
            out = out + rendered
        }
        i = i + 1
    }
    out
}

func reasoning_trace_from_agent(agent_runtime_state state, string source) reasoning_trace_dataset_state {
    reasoning_trace_dataset_state ds = new_reasoning_trace_dataset_state(source)
    int total = len(state.trace.steps)
    int i = 0
    while i < total {
        ds = reasoning_trace_dataset_add_sample(
            ds,
            reasoning_trace_sample_state {
                step: state.trace.steps[i],
                goal: state.plan.goal,
                task: state.trace.tasks[i],
                input: state.trace.inputs[i],
                action: state.trace.actions[i],
                observation: state.trace.observations[i],
                ok: state.trace.ok_flags[i]
            }
        )
        i = i + 1
    }
    ds
}

func reasoning_trace_dataset_state_dict(reasoning_trace_dataset_state state) reasoning_trace_dataset_state {
    state
}

func reasoning_trace_dataset_load_state_dict(reasoning_trace_dataset_state state, reasoning_trace_dataset_state other) reasoning_trace_dataset_state {
    other
}

func reasoning_trace_sample_state_dict(reasoning_trace_sample_state sample) reasoning_trace_sample_state {
    sample
}

func reasoning_trace_sample_load_state_dict(reasoning_trace_sample_state sample, reasoning_trace_sample_state other) reasoning_trace_sample_state {
    other
}

func reasoning_trace_step_output_state_dict(reasoning_trace_step_output output) reasoning_trace_step_output {
    output
}

func reasoning_trace_step_output_load_state_dict(reasoning_trace_step_output output, reasoning_trace_step_output other) reasoning_trace_step_output {
    other
}
