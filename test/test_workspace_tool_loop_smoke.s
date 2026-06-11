package neurx.test_workspace_tool_loop_smoke

use neurx.agent.action_schema
use neurx.agent.workspace_tools
use neurx.runtime.io.{runtime_env_get}

func main() int {
    string root = trim(runtime_env_get("NEURX_AGENT_WORKSPACE_ROOT", "."))
    if root == "" {
        println("workspace root missing")
        return 1
    }

    string raw = "{\"action\":\"write_file\",\"path\":\"notes.txt\"}\n---BEGIN CONTENT---\nhello world\n---END CONTENT---\n"
    agent_action_state parsed = agent_action_parse(raw, "general")
    if parsed.tool != "write" {
        println("action parser did not normalize write_file")
        return 1
    }
    if parsed.path != "notes.txt" {
        println("action parser did not extract path")
        return 1
    }
    if parsed.content != "hello world" {
        println("action parser did not extract content block")
        return 1
    }

    agent_workspace_result write_result = agent_workspace_write_file(parsed.path, parsed.content)
    if !write_result.ok {
        println("write_file failed: ", write_result.observation)
        return 1
    }

    agent_workspace_result read_result = agent_workspace_read_file("notes.txt", 1, 20, 400)
    if !read_result.ok {
        println("read_file failed: ", read_result.observation)
        return 1
    }
    if !agent_workspace_text_contains(read_result.observation, "hello world") {
        println("read_file output missing written content")
        return 1
    }

    agent_workspace_patch_result patch_result = agent_workspace_patch_file("notes.txt", "hello world", "hello s world", false)
    if !patch_result.ok {
        println("patch failed: ", patch_result.observation)
        return 1
    }

    agent_workspace_result search_result = agent_workspace_search_files("hello s world", 10)
    if !search_result.ok {
        println("search_files failed: ", search_result.observation)
        return 1
    }
    if !agent_workspace_text_contains(search_result.observation, "notes.txt") {
        println("search_files did not report the edited file")
        return 1
    }

    agent_workspace_result mkdir_result = agent_workspace_mkdir("nested/dir")
    if !mkdir_result.ok {
        println("mkdir failed: ", mkdir_result.observation)
        return 1
    }

    println("workspace tool loop smoke test passed")
    0
}
