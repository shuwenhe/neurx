use neurx.agent
use neurx.runtime.io.{runtime_write_text_file}

// Config (mirrors config/sample.yaml)
// max_steps: 200 (per input capped to 8 per step budget)
// output_dir: artifacts/checkpoints/agent/tool_use

string out_prefix  = "artifacts/checkpoints/agent/tool_use"
string report_path = out_prefix + "/report.txt"
string trace_path  = out_prefix + "/trace.txt"
string traj_path   = out_prefix + "/trajectory.txt"

// ─── Stage 1: Dataset ────────────────────────────────────────────────────────
// Prompt manifest: 4 tool-intensive prompts that exercise search/retrieve/infer

[]string prompts = []string{cap: 4}
prompts[0] = "search for the latest neurx release notes and summarize key changes"
prompts[1] = "retrieve the implementation of the attention mechanism in model/llm"
prompts[2] = "use the infer tool to run a forward pass on the vision encoder"
prompts[3] = "search documentation then retrieve the optimizer config for pretrain"

// ─── Stage 2: Policy ─────────────────────────────────────────────────────────
// Run each prompt through a fresh agent; accumulate results in one batch state

agent_runtime_state bench = new_default_agent("tool_use_benchmark")
bench = run_agent_batch(bench, prompts, 8)

// ─── Stage 3: Memory snapshot ────────────────────────────────────────────────
// Persist memory so downstream stages can inspect retrieval hits

agent_persist_memory(bench, out_prefix + "/memory.txt")

// ─── Stage 4: Evaluator ──────────────────────────────────────────────────────
// Score tool coverage: how many enabled tools were actively referenced in trace

[]string active_tools = agent_tool_list(bench)
string tool_summary = agent_tool_summary(bench)

int trace_count = agent_trace_entry_count(bench)
string trace_summary = agent_trace_last_n_summary(bench, 20)
runtime_write_text_file(trace_path, trace_summary)

// Export trajectory for offline analysis
agent_export_trajectory(bench, traj_path)

// ─── Build report ────────────────────────────────────────────────────────────

string finished_str = "false"
if agent_finished(bench) {
    finished_str = "true"
}

string mem_keys_str = string(len(agent_memory_keys(bench)))

string report = "=== tool_use pipeline report ===\n"
report = report + agent_summary(bench) + "\n\n"
report = report + "=== tools ===\n" + tool_summary + "\n\n"
report = report + "=== active_tool_count=" + string(len(active_tools)) + " ===\n"
int ti = 0
while ti < len(active_tools) {
    report = report + "  " + active_tools[ti] + "\n"
    ti = ti + 1
}
report = report + "\n=== trace_entries=" + string(trace_count) + " ===\n"
report = report + "=== memory_keys=" + mem_keys_str + " ===\n"
report = report + "=== last_obs ===\n" + agent_last_observation(bench)

runtime_write_text_file(report_path, report)
