# Code Agent Workflow

`workflows/agent/code_agent/` packages a coding-focused agent profile on top of the base NeurX runtime.

This profile is intended to behave closer to Codex/Claude-style code agents:

- seed the runtime with a `code` route
- queue coding-oriented stages such as `git_status`, `repo`, `retrieve`, `code`, `build`, `test`, `git_diff`, `review`, `verify`, and `finalize`
- allow per-run build/test commands without changing global environment variables
- export report, trace, trajectory, and memory artifacts

## Entry Points

- `agent/code_agent.s`: autonomous CLI agent (`make code-agent` or `app/service/run_neurx_code_agent.sh`)
- `app/service/code_agent_runner.sh`: JSON envelope for Qt bridge / HTTP gateway
- `pipeline_runner.s`: callable workflow entry
- `pipeline/code_agent_pipeline.s`: simple static pipeline example
- `config/sample.yaml`: sample workflow parameters

## Quick start

```bash
# Package index (for S module resolution)
make s-package-index

# Run code agent on the repo (bash runtime; enables LLM edits when configured)
make code-agent TASK="inspect agent/runtime.s and summarize the step loop"

# Or directly
bash app/service/run_neurx_code_agent.sh --json --prompt "your task" --repo .

# Enable remote model (OpenAI-compatible)
export NEURX_CODE_AGENT_BASE_URL=https://api.example.com
export NEURX_CODE_AGENT_MODEL=your-model
export NEURX_API_KEY=sk-...
make code-agent TASK="fix the failing test in test/"
```

Set `NEURX_CODE_AGENT_USE_RUNTIME=1` on `code_agent_runner.sh` to force the NeurX runtime path.
Set `NEURX_CODE_AGENT_PREFER_S_RUNTIME=1` on `run_neurx_code_agent.sh` to prefer the S IR binary when the toolchain can build it.

## Notes

- If `model_path` is empty, the profile still runs, but the `code` and `review` stages are skipped because those tools are model-backed.
- `build_command` and `test_command` are stored in agent memory and used as defaults for the `build` and `test` tools.
- For an OpenAI-compatible backend such as SiliconFlow, `model_path` can be an endpoint descriptor:
  `backend=openai url=https://api.siliconflow.cn model=Qwen/Qwen2.5-7B-Instruct path=/v1/chat/completions`
- The runtime also auto-builds that descriptor from environment variables such as `NEURX_CODE_AGENT_BASE_URL`, `NEURX_CODE_AGENT_MODEL`, `NEURX_CODE_AGENT_CHAT_PATH`, `NEURX_LLM_BASE_URL`, `NEURX_LLM_MODEL`, `NEURX_LLM_CHAT_PATH`, and `NEURX_API_KEY`.
