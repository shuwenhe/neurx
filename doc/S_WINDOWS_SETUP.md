# S Windows Setup

This repo can now run the agent workflows from a Windows terminal, but the current `s` toolchain is still WSL-backed unless you later replace it with a real `s.exe`.

## Current supported layout

- `C:\Users\shuwen\s`
- `C:\Users\shuwen\s\bin\s.cmd`
- `C:\Users\shuwen\neurx`

The new workflow launchers will look for `s` in this order:

1. `S_BIN`
2. `PATH`
3. `S_ROOT\bin`
4. `%USERPROFILE%\s\bin`
5. `..\s\bin` next to the `neurx` repo

## Recommended Windows setup

1. Install Git for Windows.
2. Install WSL and one Linux distribution.
3. Keep the `s` repo at `C:\Users\shuwen\s`.
4. Add `C:\Users\shuwen\s\bin` to your Windows `PATH`.

Recommended validation commands in PowerShell:

```powershell
wsl --status
Get-Command C:\Users\shuwen\s\bin\s.cmd
```

## What `s.cmd` does

`s.cmd` now delegates to `s.ps1`, and `s.ps1`:

- checks that `wsl.exe` exists
- converts the Windows repo path to `/mnt/<drive>/...`
- exports `S_ROOT` inside WSL
- runs `$S_ROOT/bin/s`

So from PowerShell or `cmd.exe`, this should become the normal entrypoint:

```powershell
s --help
```

## Running NeurX agent workflows on Windows

Use the new PowerShell wrappers:

```powershell
powershell -ExecutionPolicy Bypass -File workflows/agent/memory/run/launch.ps1
powershell -ExecutionPolicy Bypass -File workflows/agent/skills/run/launch.ps1
powershell -ExecutionPolicy Bypass -File workflows/agent/tool_use/run/launch.ps1
```

Config-driven entrypoints also work:

```powershell
powershell -ExecutionPolicy Bypass -File workflows/agent/memory/run/run_with_config.ps1 -Config workflows/agent/memory/config/sample.yaml -Steps 4
powershell -ExecutionPolicy Bypass -File workflows/agent/skills/run/run_with_config.ps1 -Config workflows/agent/skills/config/sample.yaml -Generations 2
powershell -ExecutionPolicy Bypass -File workflows/agent/tool_use/run/run_with_config.ps1 -Config workflows/agent/tool_use/config/sample.yaml -Steps 4
```

## Notes

- The workflow launchers now compile runtime IR through `workflows/agent/common/compile_runtime.sh`, so they no longer depend on `make`.
- `make s-compile-runtime` is still available as a repo-level alias when you want the same compilation path outside the workflow wrappers.
- If you later produce a native Windows `s.exe`, set `S_BIN` to it and the same workflow wrappers will keep working.
- If WSL is not initialized yet, `s.cmd` will fail before compilation starts.
