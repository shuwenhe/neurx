use neurx.agent
use neurx.runtime.io.{runtime_write_text_file}
string out_prefix = "artifacts/checkpoints/agent/code_agent"
string report_path = out_prefix + "/report.txt"
string trace_path = out_prefix + "/trace.txt"
string traj_path = out_prefix + "/trajectory.txt"
string mem_path = out_prefix + "/memory.txt"
string goal = "implement a Codex-style code agent in NeurX"
string input = "Inspect the repository, update the agent runtime for coding tasks, and verify the result."
string model_path = ""
string build_command = "make s-compile-runtime"
string test_command = "make test"
agent_runtime_state code_agent = new_code_agent_with_model(goal, 16, model_path, build_command, test_command)
code_agent = run_agent(code_agent, input, 16)
agent_persist_memory(code_agent, mem_path)
agent_export_trajectory(code_agent, traj_path)
runtime_write_text_file(trace_path, agent_trace_last_n_summary(code_agent, 40))
string report = "=== code_agent pipeline report ===\n"
report = report + agent_summary(code_agent) + "\n\n"
report = report + "=== tools ===\n" + agent_tool_summary(code_agent) + "\n\n"
report = report + "=== final_observation ===\n" + agent_last_observation(code_agent)
runtime_write_text_file(report_path, report)
