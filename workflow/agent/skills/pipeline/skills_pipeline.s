use neurx.agent
use neurx.runtime.io.{runtime_write_text_file, runtime_file_exists}
string out_prefix = "artifact/checkpoints/agent/skills"
string snapshot_path = out_prefix + "/snapshot.txt"
string report_path   = out_prefix + "/report.txt"
string trace_path    = out_prefix + "/trace.txt"
string[] bench_inputs = string[]{cap: 5}
bench_inputs[0] = "search for neurx framework agent documentation"
bench_inputs[1] = "retrieve code examples for tensor add operations"
bench_inputs[2] = "analyze the inference pipeline design and output shape"
bench_inputs[3] = "verify that computation output shape is [batch 512]"
bench_inputs[4] = "plan and execute a multi-step language model inference pipeline"
agent_runtime_state evolved = new_default_agent("skill_evolution_benchmark")
int gen = 0
int max_gen = 3
for gen < max_gen {
    evolved = run_agent_batch(evolved, bench_inputs, 8)
    string cur_task = agent_current_task(evolved)
    bool did_finish = agent_finished(evolved)
    evolved = agent_synthesize_skill(evolved, cur_task, did_finish)
    if agent_is_stalled(evolved) {
        evolved = agent_step_with_task(evolved, "plan", "re-evaluate skill strategy")
    }
    gen = gen + 1
}
string[] promoted = agent_promoted_skill_names(evolved)
string eval_report = neurx.strings.concat2("promoted_count=", string(len(promoted)))
int ei = 0
for ei < len(promoted) {
    float sr = agent_skill_success_rate(evolved, promoted[ei])
    int sr_pct = int(sr * 100.0)
    eval_report = neurx.strings.concat6(eval_report, "\n  skill=", neurx.strings.string_at(promoted, ei), " success_rate=", string(sr_pct), "%")
    ei = ei + 1
}
string[] all_names = agent_skill_names(evolved)
string candidate_report = neurx.strings.concat2("total_skills=", string(len(all_names)))
int ci = 0
for ci < len(all_names) {
    float sr2 = agent_skill_success_rate(evolved, all_names[ci])
    int sr2_pct = int(sr2 * 100.0)
    candidate_report = neurx.strings.concat6(candidate_report, "\n  ", neurx.strings.string_at(all_names, ci), "=", string(sr2_pct), "%")
    ci = ci + 1
}
int mi = 0
for mi < len(all_names) {
    float sr3 = agent_skill_success_rate(evolved, all_names[mi])
    if sr3 > 0.0 && sr3 < 0.20 {
        evolved = agent_skill_force_retire(evolved, all_names[mi])
    }
    mi = mi + 1
}
evolved = agent_prune_skills(evolved)
agent_persist_skill_snapshot(evolved, snapshot_path)
string trace_summary = agent_trace_last_n_summary(evolved, 10)
runtime_write_text_file(trace_path, trace_summary)
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
