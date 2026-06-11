use neurx.agent
use neurx.runtime.io.{runtime_write_text_file, runtime_file_exists}

// Config (mirrors config/sample.yaml)
// max_generations: 3 (full run uses 20)
// min_success_rate: 0.80
// retire_threshold: 0.20
// output_dir: artifacts/checkpoints/agent/skills

string out_prefix = "artifacts/checkpoints/agent/skills"
string snapshot_path = out_prefix + "/snapshot.txt"
string report_path   = out_prefix + "/report.txt"
string trace_path    = out_prefix + "/trace.txt"

// ─── Stage 1: Collect ────────────────────────────────────────────────────────
// 5 benchmark inputs covering: search / retrieve / analysis / verify / plan

[]string bench_inputs = []string{cap: 5}
bench_inputs[0] = "search for neurx framework agent documentation"
bench_inputs[1] = "retrieve code examples for tensor add operations"
bench_inputs[2] = "analyze the inference pipeline design and output shape"
bench_inputs[3] = "verify that computation output shape is [batch 512]"
bench_inputs[4] = "plan and execute a multi-step language model inference pipeline"

agent_runtime_state evolved = new_default_agent("skill_evolution_benchmark")

int gen = 0
int max_gen = 3
while gen < max_gen {
    evolved = run_agent_batch(evolved, bench_inputs, 8)

    string cur_task = agent_current_task(evolved)
    bool did_finish = agent_finished(evolved)
    evolved = agent_synthesize_skill(evolved, cur_task, did_finish)

    if agent_is_stalled(evolved) {
        evolved = agent_step_with_task(evolved, "plan", "re-evaluate skill strategy")
    }

    gen = gen + 1
}

// ─── Stage 2: Evaluate ───────────────────────────────────────────────────────

[]string promoted = agent_promoted_skill_names(evolved)
string eval_report = "promoted_count=" + string(len(promoted))
int ei = 0
while ei < len(promoted) {
    float sr = agent_skill_success_rate(evolved, promoted[ei])
    int sr_pct = int(sr * 100.0)
    eval_report = eval_report + "\n  skill=" + promoted[ei] + " success_rate=" + string(sr_pct) + "%"
    ei = ei + 1
}

// ─── Stage 3: Candidate report ───────────────────────────────────────────────

[]string all_names = agent_skill_names(evolved)
string candidate_report = "total_skills=" + string(len(all_names))
int ci = 0
while ci < len(all_names) {
    float sr2 = agent_skill_success_rate(evolved, all_names[ci])
    int sr2_pct = int(sr2 * 100.0)
    candidate_report = candidate_report + "\n  " + all_names[ci] + "=" + string(sr2_pct) + "%"
    ci = ci + 1
}

// ─── Stage 4: Monitor ────────────────────────────────────────────────────────
// Retire skills below retire_threshold (0.20), then prune retired records

int mi = 0
while mi < len(all_names) {
    float sr3 = agent_skill_success_rate(evolved, all_names[mi])
    if sr3 > 0.0 && sr3 < 0.20 {
        evolved = agent_skill_force_retire(evolved, all_names[mi])
    }
    mi = mi + 1
}
evolved = agent_prune_skills(evolved)

// ─── Stage 5: Persist ────────────────────────────────────────────────────────

agent_persist_skill_snapshot(evolved, snapshot_path)

string trace_summary = agent_trace_last_n_summary(evolved, 10)
runtime_write_text_file(trace_path, trace_summary)

// ─── Final report ────────────────────────────────────────────────────────────

string stall_str = "false"
if agent_is_stalled(evolved) {
    stall_str = "true"
}

string final_summary = agent_summary(evolved)
string report = "=== skills pipeline report ===\n"
report = report + final_summary + "\n\n"
report = report + "=== eval (promoted skills) ===\n" + eval_report + "\n\n"
report = report + "=== candidates ===\n" + candidate_report + "\n\n"
report = report + "=== monitor ===\nis_stalled=" + stall_str + "\n"
report = report + "tool_summary=\n" + agent_tool_summary(evolved)

runtime_write_text_file(report_path, report)
