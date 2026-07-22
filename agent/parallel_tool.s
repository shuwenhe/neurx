package neurx.agent.parallel_tool





use neurx.agent.tool_registry
use neurx.agent.memory
use neurx.tool.workspace_tools



struct parallel_tool_call {
    string id
    string tool_name
    string input
}

struct parallel_tool_result {
    string id
    string tool_name
    bool   ok
    string observation
}

struct parallel_tool_batch {
    []parallel_tool_call calls
    int count
}

struct parallel_tool_batch_result {
    []parallel_tool_result results
    int count
    int ok_count
    int fail_count
}



func new_parallel_tool_call(string id, string tool_name, string input) parallel_tool_call {
    parallel_tool_call {
        id:        id,
        tool_name: tool_name,
        input:     input,
    }
}

func new_parallel_tool_batch() parallel_tool_batch {
    parallel_tool_batch {
        calls: []parallel_tool_call{cap: 8},
        count: 0,
    }
}

func parallel_tool_batch_add(parallel_tool_batch batch, string tool_name, string input) parallel_tool_batch {
    int n = batch.count
    []parallel_tool_call next = []parallel_tool_call{cap: n + 1}
    int i = 0
    while i < n {
        next[i] = batch.calls[i]
        i = i + 1
    }
    string call_id = "call_" + string(n)
    next[n] = new_parallel_tool_call(call_id, tool_name, input)
    parallel_tool_batch {
        calls: next,
        count: n + 1,
    }
}

func new_parallel_tool_batch_result() parallel_tool_batch_result {
    parallel_tool_batch_result {
        results:    []parallel_tool_result{cap: 8},
        count:      0,
        ok_count:   0,
        fail_count: 0,
    }
}




func parallel_tool_dispatch_one(parallel_tool_call call, agent_tool_registry_state tools) parallel_tool_result {
    bool enabled = agent_tool_registry_has_enabled(tools, call.tool_name)
    if !enabled {
        return parallel_tool_result {
            id:          call.id,
            tool_name:   call.tool_name,
            ok:          false,
            observation: "tool_disabled:" + call.tool_name,
        }
    }

    string obs = ""
    bool ok = true

    if call.tool_name == "read" {
        agent_workspace_result r = agent_workspace_read(call.input)
        obs = r.observation
        ok = r.ok
    } else if call.tool_name == "grep" {
        agent_workspace_result r = agent_workspace_grep(call.input, "")
        obs = r.observation
        ok = r.ok
    } else if call.tool_name == "find" {
        agent_workspace_result r = agent_workspace_find(call.input, "")
        obs = r.observation
        ok = r.ok
    } else if call.tool_name == "list_dir" {
        agent_workspace_result r = agent_workspace_list_dir(call.input)
        obs = r.observation
        ok = r.ok
    } else if call.tool_name == "git_status" {
        agent_workspace_result r = agent_workspace_git_status()
        obs = r.observation
        ok = r.ok
    } else if call.tool_name == "s" {
        agent_workspace_command_result r = agent_workspace_s(call.input)
        obs = r.observation
        ok = r.ok
    } else {
        obs = "unknown_tool:" + call.tool_name
        ok = false
    }

    parallel_tool_result {
        id:          call.id,
        tool_name:   call.tool_name,
        ok:          ok,
        observation: obs,
    }
}


func parallel_tool_dispatch(parallel_tool_batch batch, agent_tool_registry_state tools) parallel_tool_batch_result {
    int n = batch.count
    []parallel_tool_result results = []parallel_tool_result{cap: n}
    int ok_count = 0
    int fail_count = 0
    int i = 0
    while i < n {
        parallel_tool_result r = parallel_tool_dispatch_one(batch.calls[i], tools)
        results[i] = r
        if r.ok {
            ok_count = ok_count + 1
        } else {
            fail_count = fail_count + 1
        }
        i = i + 1
    }
    parallel_tool_batch_result {
        results:    results,
        count:      n,
        ok_count:   ok_count,
        fail_count: fail_count,
    }
}




func parallel_tool_merge_observations(parallel_tool_batch_result batch_result) string {
    string merged = ""
    int i = 0
    while i < batch_result.count {
        parallel_tool_result r = batch_result.results[i]
        string status = "ok"
        if !r.ok {
            status = "fail"
        }
        string entry = "[" + r.id + "|" + r.tool_name + "|" + status + "] " + r.observation
        if i == 0 {
            merged = entry
        } else {
            merged = merged + "\n" + entry
        }
        i = i + 1
    }
    merged
}


func parallel_tool_store_results(parallel_tool_batch_result batch_result, agent_memory_state memory) agent_memory_state {
    agent_memory_state m = memory
    int i = 0
    while i < batch_result.count {
        parallel_tool_result r = batch_result.results[i]
        m = agent_memory_write_short(m, "tool_result_" + r.id, r.observation)
        i = i + 1
    }
    m
}



func parallel_tool_batch_summary(parallel_tool_batch_result batch_result) string {
    "parallel_tools count=" + string(batch_result.count) +
    " ok=" + string(batch_result.ok_count) +
    " fail=" + string(batch_result.fail_count)
}
