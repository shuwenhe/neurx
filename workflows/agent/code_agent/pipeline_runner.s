package neurx.workflows.agent.code_agent.pipeline_runner

use neurx.agent
use neurx.runtime.io.{runtime_write_text_file}

func run_agent_code_workflow(
    string goal,
    string task_input,
    int max_steps,
    string output_dir,
    string model_path,
    string build_command,
    string test_command
) int {
    int steps_per_task = max_steps
    if steps_per_task <= 0 {
        steps_per_task = 12
    }

    string report_path = output_dir + "/report.txt"
    string trace_path = output_dir + "/trace.txt"
    string traj_path = output_dir + "/trajectory.txt"
    string mem_path = output_dir + "/memory.txt"

    agent_runtime_state code_agent = new_code_agent_with_model(goal, steps_per_task, model_path, build_command, test_command)
    code_agent = run_agent(code_agent, task_input, steps_per_task)

    agent_persist_memory(code_agent, mem_path)
    agent_export_trajectory(code_agent, traj_path)
    runtime_write_text_file(trace_path, agent_trace_last_n_summary(code_agent, 40))

    string report = "=== code_agent report ===\n"
    report = report + "goal=" + goal + "\n"
    report = report + "input=" + task_input + "\n"
    report = report + "model_path=" + model_path + "\n"
    report = report + "build_command=" + build_command + "\n"
    report = report + "test_command=" + test_command + "\n"
    report = report + "max_steps=" + string(steps_per_task) + "\n\n"
    report = report + agent_summary(code_agent) + "\n\n"
    report = report + "=== tools ===\n" + agent_tool_summary(code_agent) + "\n\n"
    report = report + "=== final_observation ===\n" + agent_last_observation(code_agent) + "\n\n"
    report = report + "=== trajectory_tail ===\n" + agent_trace_last_n_summary(code_agent, 20)

    runtime_write_text_file(report_path, report)

    println("workflow=agent_code")
    println("output_dir=" + output_dir)
    println("report=" + report_path)
    println("trace=" + trace_path)
    println("trajectory=" + traj_path)
    println("memory=" + mem_path)
    0
}
