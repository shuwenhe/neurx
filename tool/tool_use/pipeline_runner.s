package neurx.workflows.agent.tool_use.pipeline_runner

use neurx.agent
use neurx.runtime.io.{runtime_write_text_file}

func run_agent_tool_use_workflow(int max_steps, string output_dir, string tool_manifest, string model_name) int {
    int steps_per_input = max_steps
    if steps_per_input <= 0 {
        steps_per_input = 1
    }
    if steps_per_input > 8 {
        steps_per_input = 8
    }

    string report_path = output_dir + "/report.txt"
    string trace_path = output_dir + "/trace.txt"
    string traj_path = output_dir + "/trajectory.txt"
    string mem_path = output_dir + "/memory.txt"

    []string prompts = []string{cap: 4}
    prompts[0] = "search for the latest neurx release notes and summarize key changes"
    prompts[1] = "retrieve the implementation of the attention mechanism in model/llm"
    prompts[2] = "use the infer tool to run a forward pass on the vision encoder"
    prompts[3] = "search documentation then retrieve the optimizer config for pretrain"

    agent_runtime_state bench = new_default_agent("tool_use_benchmark")
    bench = run_agent_batch(bench, prompts, steps_per_input)

    agent_persist_memory(bench, mem_path)

    []string active_tools = agent_tool_list(bench)
    string tool_summary = agent_tool_summary(bench)
    int trace_count = agent_trace_entry_count(bench)
    string trace_summary = agent_trace_last_n_summary(bench, 20)
    runtime_write_text_file(trace_path, trace_summary)
    agent_export_trajectory(bench, traj_path)

    string mem_keys_str = string(len(agent_memory_keys(bench)))
    string report = "=== tool_use pipeline report ===\n"
    report = report + "tool_manifest=" + tool_manifest + "\n"
    report = report + "model_name=" + model_name + "\n"
    report = report + "steps_per_input=" + string(steps_per_input) + "\n\n"
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

    println("workflow=agent_tool_use")
    println("output_dir=" + output_dir)
    println("report=" + report_path)
    println("trace=" + trace_path)
    println("trajectory=" + traj_path)
    println("memory=" + mem_path)
    0
}
