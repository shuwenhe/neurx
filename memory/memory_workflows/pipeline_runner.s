package neurx.workflows.agent.memory.pipeline_runner
use neurx.agent
use neurx.runtime.io.{runtime_write_text_file}

func run_agent_memory_workflow(int max_steps, string output_dir, string dataset_manifest) int {
    int steps_per_input = max_steps
    if steps_per_input <= 0 {
        steps_per_input = 1
    }
    if steps_per_input > 8 {
        steps_per_input = 8
    }
    string mem_path = output_dir + "/memory.txt"
    string report_path = output_dir + "/report.txt"
    string trace_path = output_dir + "/trace.txt"
    []string phase1_inputs = []string{cap: 4}
    phase1_inputs[0] = "search and index neurx agent architecture overview"
    phase1_inputs[1] = "retrieve tensor operations documentation and store key facts"
    phase1_inputs[2] = "analyze model checkpoint structure and record format details"
    phase1_inputs[3] = "summarize the distributed training configuration defaults"
    agent_runtime_state phase1 = new_default_agent("memory_build_phase")
    phase1 = run_agent_batch(phase1, phase1_inputs, steps_per_input)
    int keys_after_phase1 = len(agent_memory_keys(phase1))
    agent_persist_memory(phase1, mem_path)
    string phase1_trace = agent_trace_last_n_summary(phase1, 8)
    agent_runtime_state phase2 = agent_warm_start(
        "memory_retrieval_phase",
        mem_path,
        "",
        ""
    )
    int keys_before_phase2 = len(agent_memory_keys(phase2))
    []string phase2_inputs = []string{cap: 3}
    phase2_inputs[0] = "what is the neurx agent architecture overview that was stored"
    phase2_inputs[1] = "recall the tensor operations documentation key facts"
    phase2_inputs[2] = "retrieve the distributed training configuration defaults"
    phase2 = run_agent_batch(phase2, phase2_inputs, steps_per_input)
    int keys_after_phase2 = len(agent_memory_keys(phase2))
    []string expected_keys = []string{cap: 3}
    expected_keys[0] = "agent_architecture"
    expected_keys[1] = "tensor_ops"
    expected_keys[2] = "distributed_config"
    int hit_count = 0
    string key_report = ""
    int ki = 0
    while ki < len(expected_keys) {
        bool found = agent_memory_has(phase2, expected_keys[ki])
        string hit_str = "miss"
        if found {
            hit_str = "hit"
            hit_count = hit_count + 1
        }
        key_report = key_report + "  key=" + expected_keys[ki] + " " + hit_str + "\n"
        ki = ki + 1
    }
    string stall_str = "false"
    if agent_is_stalled(phase2) {
        stall_str = "true"
    }
    string phase2_trace = agent_trace_last_n_summary(phase2, 8)
    runtime_write_text_file(trace_path, "=== phase1 ===\n" + phase1_trace + "\n\n=== phase2 ===\n" + phase2_trace)
    string report = "=== memory pipeline report ===\n\n"
    report = report + "dataset_manifest=" + dataset_manifest + "\n"
    report = report + "steps_per_input=" + string(steps_per_input) + "\n\n"
    report = report + "=== phase1 summary ===\n" + agent_summary(phase1) + "\n\n"
    report = report + "=== phase2 summary ===\n" + agent_summary(phase2) + "\n\n"
    report = report + "=== memory stats ===\n"
    report = report + "  keys_after_phase1=" + string(keys_after_phase1) + "\n"
    report = report + "  keys_restored_into_phase2=" + string(keys_before_phase2) + "\n"
    report = report + "  keys_after_phase2=" + string(keys_after_phase2) + "\n\n"
    report = report + "=== key retrieval eval ===\n"
    report = report + "  hit_count=" + string(hit_count) + "/" + string(len(expected_keys)) + "\n"
    report = report + key_report
    report = report + "\n=== stall_check ===\nis_stalled=" + stall_str + "\n"
    runtime_write_text_file(report_path, report)
    println("workflow=agent_memory")
    println("output_dir=" + output_dir)
    println("report=" + report_path)
    println("trace=" + trace_path)
    println("memory=" + mem_path)
    0
}

