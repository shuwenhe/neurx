package neurx.test_agent_skill_persistence_export

use neurx.agent.{new_default_agent, run_agent_once, agent_skill_snapshot, agent_trajectory_export, agent_persist_skill_snapshot, agent_export_trajectory}
use neurx.runtime.io.{runtime_read_text_file}

func contains(string text, string pattern) bool {
    string haystack = lower(text)
    string needle = lower(pattern)
    int hay_len = len(haystack)
    int nee_len = len(needle)
    if nee_len <= 0 {
        return true
    }
    if hay_len < nee_len {
        return false
    }
    int i = 0
    while i <= hay_len - nee_len {
        int j = 0
        bool match = true
        while j < nee_len {
            if haystack[i + j] != needle[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    false
}

func main() int {
    string prompt = "fix qml agent bug"
    string snapshot_path = "/tmp/neurx_agent_skill_snapshot.txt"
    string trajectory_path = "/tmp/neurx_agent_trajectory.txt"
    agent_runtime_state state = new_default_agent(prompt)

    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)
    state = run_agent_once(state, prompt)

    string snapshot = agent_skill_snapshot(state)
    if !contains(snapshot, "code_verify") || !contains(snapshot, "promoted") {
        println("agent skill snapshot missing promoted code_verify")
        return 1
    }

    string trajectory = agent_trajectory_export(state)
    if !contains(trajectory, "trace_count=4") || !contains(trajectory, "task[3]=verify") || !contains(trajectory, "active_skill[") {
        println("agent trajectory export missing expected trace lines")
        return 1
    }

    agent_persist_skill_snapshot(state, snapshot_path)
    agent_export_trajectory(state, trajectory_path)

    if !contains(runtime_read_text_file(snapshot_path), "code_verify") {
        println("persisted skill snapshot missing expected skill")
        return 1
    }
    if !contains(runtime_read_text_file(trajectory_path), "trace_count=4") || !contains(runtime_read_text_file(trajectory_path), "active_skill[") {
        println("persisted trajectory export missing expected trace count")
        return 1
    }

    println("agent skill persistence/export test passed")
    0
}