package neurx.agent.workspace_search
use neurx.agent.workspace_tools.{agent_workspace_read, agent_workspace_text_contains, agent_workspace_clip, agent_workspace_root}
use neurx.runtime.io.{runtime_run_command_output, runtime_shell_escape}
struct agent_search_hit {
    string path
    string snippet
    bool matched
}

struct agent_search_result {
    bool ok
    string query
    int hit_count
    string observation
}

func agent_search_observation(string status, string query, string details) string {
    string obs = "search:status=" + status + ";query=" + query
    if trim(details) != "" {
        obs = obs + ";" + details
    }
    obs
}

func agent_search_count_lines(string text) int {
    string trimmed = trim(text)
    if trimmed == "" {
        return 0
    }
    int count = 1
    int i = 0
    while i < len(trimmed) {
        if string(trimmed[i]) == "\n" {
            count = count + 1
        }
        i = i + 1
    }
    count
}

func agent_search_candidate_paths(string route) []string {
    []string paths = []string{cap: 12}
    paths.push("agent/runtime.s")
    paths.push("executor/executor.s")
    paths.push("task/planner.s")
    paths.push("memory/memory.s")
    paths.push("tool/workspace_tools.s")
    paths.push("action/action_schema.s")
    paths.push("README.md")
    if route == "sql" {
        paths.push("sql/neurx_init.s")
    }
    if route == "repo" || route == "code" {
        paths.push("app/README.md")
        paths.push("doc/AGENT_CAPABILITY_GAP.md")
    }
    paths
}

func agent_search_make_hit(string path, string query, int max_chars) agent_search_hit {
    agent_workspace_result read_result = agent_workspace_read(path, max_chars)
    bool matched = false
    string snippet = ""
    if read_result.ok {
        matched = query == "" || agent_workspace_text_contains(read_result.observation, query)
        if matched {
            snippet = agent_workspace_clip(read_result.observation, max_chars)
        }
    }
    agent_search_hit {
        path: path,
        snippet: snippet,
        matched: matched,
    }
}

func agent_search_workspace(string query, string route, int max_hits, int max_chars_per_hit) agent_search_result {
    string q = trim(query)
    int limit = max_hits
    if limit <= 0 {
        limit = 3
    }
    int clip = max_chars_per_hit
    if clip <= 0 {
        clip = 512
    }
    string root = agent_workspace_root()
    if q != "" {
        string limit_str = string(limit)
        string scan_cmd = "if command -v rg >/dev/null 2>&1; then rg -n --hidden --glob '!app/build/**' --glob '!.git/**' --glob '!build/**' " + runtime_shell_escape(q) + " " + runtime_shell_escape(root) + " | head -" + limit_str + "; else grep -RIn --exclude-dir=.git --exclude-dir=build " + runtime_shell_escape(q) + " " + runtime_shell_escape(root) + " | head -" + limit_str + "; fi"
        string output = trim(runtime_run_command_output(scan_cmd))
        if output != "" {
            int hit_count = agent_search_count_lines(output)
            return agent_search_result {
                ok: true,
                query: q,
                hit_count: hit_count,
                observation: agent_search_observation("ok", q, "backend=workspace_scan;hit_count=" + string(hit_count)) + "\n" + agent_workspace_clip(output, clip * limit),
            }
        }
    }
    []string paths = agent_search_candidate_paths(route)
    string obs = agent_search_observation("ok", q, "backend=candidate_scan")
    int hits = 0
    int i = 0
    while i < len(paths) && hits < limit {
        agent_search_hit hit = agent_search_make_hit(paths[i], q, clip)
        if hit.matched {
            obs = obs + "\nhit[" + string(hits) + "].path=" + hit.path
            obs = obs + "\nhit[" + string(hits) + "].snippet=" + hit.snippet
            hits = hits + 1
        }
        i = i + 1
    }
    if hits == 0 {
        obs = agent_search_observation("no_progress", q, "backend=candidate_scan;hits=0")
    } else {
        obs = obs + "\nhit_count=" + string(hits)
    }
    agent_search_result {
        ok: hits > 0,
        query: q,
        hit_count: hits,
        observation: obs,
    }
}
