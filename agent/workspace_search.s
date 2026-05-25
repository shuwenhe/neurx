package neurx.agent.workspace_search

use neurx.agent.workspace_tools.{agent_workspace_read, agent_workspace_text_contains, agent_workspace_clip}

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

func agent_search_candidate_paths(string route) []string {
    []string paths = []string{cap: 12}
    paths.push("agent/runtime.s")
    paths.push("agent/executor.s")
    paths.push("agent/planner.s")
    paths.push("agent/memory.s")
    paths.push("agent/workspace_tools.s")
    paths.push("agent/action_schema.s")
    paths.push("README.md")
    paths.push("doc/AGENT_CAPABILITY_GAP.md")
    if route == "sql" {
        paths.push("sql/neurx_init.sql")
    }
    if route == "repo" {
        paths.push("app/README.md")
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

    []string paths = agent_search_candidate_paths(route)
    string obs = "search:query=" + q
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
        obs = obs + "\nhits=0"
    }
    agent_search_result {
        ok: hits > 0,
        query: q,
        hit_count: hits,
        observation: obs,
    }
}
