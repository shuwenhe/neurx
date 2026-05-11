package neurx.train.language_chain

use neurx.dataset_text.{build_vocab, encode_text}
use neurx.dl.dataloader.{batch_count, dataloader_state, new_state, reset_state, has_next, next_batch}
use neurx.train.loop.{training_pipeline_state, new_training_pipeline_state, train_steps, training_pipeline_state_dict, training_pipeline_load_state_dict, training_pipeline_metrics, training_pipeline_metrics_state}

struct language_stage_config {
    string name
    int epochs
    int batch_size
    int seq_len
    bool instruction_tuning
}

struct language_sample {
    string instruction
    string input
    string output
}

struct language_training_plan {
    language_stage_config pretrain
    language_stage_config finetune
}

struct language_stage_state {
    language_stage_config config
    []int token_ids
    training_pipeline_state pipeline
    int target_steps
    bool complete
}

struct language_training_chain_state {
    language_training_plan plan
    language_stage_state pretrain
    language_stage_state finetune
    int active_stage
    bool finished
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

func copy_ints([]int values) []int {
    []int out = []int{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_samples([]language_sample samples) []language_sample {
    []language_sample out = []language_sample{cap: len(samples)}
    int i = 0
    while i < len(samples) {
        out[i] = language_sample {
            instruction: samples[i].instruction,
            input: samples[i].input,
            output: samples[i].output,
        }
        i = i + 1
    }
    out
}

func language_stage_config_state_dict(language_stage_config config) language_stage_config {
    config
}

func language_stage_config_load_state_dict(language_stage_config config, language_stage_config other) language_stage_config {
    other
}

func language_sample_state_dict(language_sample sample) language_sample {
    sample
}

func language_sample_load_state_dict(language_sample sample, language_sample other) language_sample {
    other
}

func language_training_plan_state_dict(language_training_plan plan) language_training_plan {
    plan
}

func language_training_plan_load_state_dict(language_training_plan plan, language_training_plan other) language_training_plan {
    other
}

func language_stage_state_dict(language_stage_state state) language_stage_state {
    language_stage_state {
        config: language_stage_config_state_dict(state.config),
        token_ids: copy_ints(state.token_ids),
        pipeline: training_pipeline_state_dict(state.pipeline),
        target_steps: state.target_steps,
        complete: state.complete,
    }
}

func language_stage_load_state_dict(language_stage_state state, language_stage_state other) language_stage_state {
    language_stage_state {
        config: language_stage_config_load_state_dict(state.config, other.config),
        token_ids: copy_ints(other.token_ids),
        pipeline: training_pipeline_load_state_dict(state.pipeline, other.pipeline),
        target_steps: other.target_steps,
        complete: other.complete,
    }
}

func language_training_chain_state_dict(language_training_chain_state state) language_training_chain_state {
    language_training_chain_state {
        plan: language_training_plan_state_dict(state.plan),
        pretrain: language_stage_state_dict(state.pretrain),
        finetune: language_stage_state_dict(state.finetune),
        active_stage: state.active_stage,
        finished: state.finished,
    }
}

func language_training_chain_load_state_dict(language_training_chain_state state, language_training_chain_state other) language_training_chain_state {
    language_training_chain_state {
        plan: language_training_plan_load_state_dict(state.plan, other.plan),
        pretrain: language_stage_load_state_dict(state.pretrain, other.pretrain),
        finetune: language_stage_load_state_dict(state.finetune, other.finetune),
        active_stage: other.active_stage,
        finished: other.finished,
    }
}

func new_language_stage_config(string name, int epochs, int batch_size, int seq_len, bool instruction_tuning) language_stage_config {
    language_stage_config {
        name: name,
        epochs: epochs,
        batch_size: batch_size,
        seq_len: seq_len,
        instruction_tuning: instruction_tuning,
    }
}

func new_language_training_plan(language_stage_config pretrain, language_stage_config finetune) language_training_plan {
    language_training_plan {
        pretrain: pretrain,
        finetune: finetune,
    }
}

func render_pretrain_corpus([]string documents) string {
    string out = ""
    int i = 0
    while i < len(documents) {
        if trim(documents[i]) != "" {
            if out != "" {
                out = out + "\n\n"
            }
            out = out + trim(documents[i])
        }
        i = i + 1
    }
    out
}

func render_instruction_sample(language_sample sample) string {
    string prompt = "### 指令\n" + trim(sample.instruction)
    if trim(sample.input) != "" {
        prompt = prompt + "\n\n### 输入\n" + trim(sample.input)
    }
    prompt + "\n\n### 回复\n" + trim(sample.output)
}

func render_instruction_corpus([]language_sample samples) string {
    string out = ""
    int i = 0
    while i < len(samples) {
        string rendered = render_instruction_sample(samples[i])
        if trim(rendered) != "" {
            if out != "" {
                out = out + "\n\n"
            }
            out = out + rendered
        }
        i = i + 1
    }
    out
}

func load_text_sources([]string paths) string {
    string out = ""
    int i = 0
    while i < len(paths) {
        string path = trim(paths[i])
        if path != "" && neurx.runtime.io.runtime_file_exists(path) {
            string text = trim(neurx.runtime.io.runtime_read_text_file(path))
            if text != "" {
                if out != "" {
                    out = out + "\n\n"
                }
                out = out + text
            }
        }
        i = i + 1
    }
    out
}

func tokenize_language_text(string text) []int {
    []string vocab = build_vocab(text)
    encode_text(text, vocab)
}

func language_stage_target_steps(language_stage_config config, []int token_ids) int {
    dataloader_state loader = new_state(token_ids, config.batch_size, config.seq_len)
    int batches = batch_count(loader)
    if batches <= 0 || config.epochs <= 0 {
        return 0
    }
    batches * config.epochs
}

func new_language_stage_state(language_stage_config config, []int token_ids) language_stage_state {
    language_stage_state {
        config: config,
        token_ids: copy_ints(token_ids),
        pipeline: new_training_pipeline_state(token_ids, config.batch_size, config.seq_len),
        target_steps: language_stage_target_steps(config, token_ids),
        complete: false,
    }
}

func language_stage_should_continue(language_stage_state state) bool {
    if state.complete {
        return false
    }
    if state.target_steps <= 0 {
        return false
    }
    state.pipeline.loop.step < state.target_steps
}

func advance_language_stage(language_stage_state state, int steps) language_stage_state {
    if steps < 0 {
        steps = 0
    }
    training_pipeline_state pipeline = train_steps(state.pipeline, steps)
    bool complete = pipeline.loop.step >= state.target_steps
    language_stage_state {
        config: state.config,
        token_ids: copy_ints(state.token_ids),
        pipeline: pipeline,
        target_steps: state.target_steps,
        complete: complete,
    }
}

func build_pretrain_tokens([]string documents) []int {
    string corpus = render_pretrain_corpus(documents)
    tokenize_language_text(corpus)
}

func build_finetune_tokens([]language_sample samples) []int {
    string corpus = render_instruction_corpus(samples)
    tokenize_language_text(corpus)
}

func new_language_training_chain_state(language_training_plan plan, []string pretrain_documents, []language_sample finetune_samples) language_training_chain_state {
    []int pretrain_tokens = build_pretrain_tokens(pretrain_documents)
    []int finetune_tokens = build_finetune_tokens(finetune_samples)
    language_training_chain_state {
        plan: plan,
        pretrain: new_language_stage_state(plan.pretrain, pretrain_tokens),
        finetune: new_language_stage_state(plan.finetune, finetune_tokens),
        active_stage: 0,
        finished: false,
    }
}

func language_training_chain_active_stage(language_training_chain_state state) string {
    if state.finished {
        return "finished"
    }
    if state.active_stage == 0 {
        return state.plan.pretrain.name
    }
    state.plan.finetune.name
}

func language_training_chain_complete(language_training_chain_state state) bool {
    state.finished
}

func language_training_chain_step(language_training_chain_state state, int steps) language_training_chain_state {
    if state.finished {
        return state
    }
    if state.active_stage == 0 {
        language_stage_state next_pretrain = advance_language_stage(state.pretrain, steps)
        bool next_finished = next_pretrain.complete && !language_stage_should_continue(state.finetune)
        int next_stage = 0
        if next_pretrain.complete {
            next_stage = 1
        }
        language_training_chain_state {
            plan: state.plan,
            pretrain: next_pretrain,
            finetune: state.finetune,
            active_stage: next_stage,
            finished: next_finished,
        }
    } else {
        language_stage_state next_finetune = advance_language_stage(state.finetune, steps)
        bool next_finished = next_finetune.complete
        language_training_chain_state {
            plan: state.plan,
            pretrain: state.pretrain,
            finetune: next_finetune,
            active_stage: 1,
            finished: next_finished,
        }
    }
}

func language_training_chain_run(language_training_chain_state state, int steps) language_training_chain_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    language_training_chain_state current = state
    int i = 0
    while i < loops {
        current = language_training_chain_step(current, 1)
        i = i + 1
        if current.finished {
            return current
        }
    }
    current
}

func language_training_chain_state_metrics(language_training_chain_state state) training_pipeline_metrics {
    if state.active_stage == 0 {
        return training_pipeline_metrics(state.pretrain.pipeline)
    }
    training_pipeline_metrics(state.finetune.pipeline)
}

func language_training_chain_pretrain_state(language_training_chain_state state) language_stage_state {
    state.pretrain
}

func language_training_chain_finetune_state(language_training_chain_state state) language_stage_state {
    state.finetune
}