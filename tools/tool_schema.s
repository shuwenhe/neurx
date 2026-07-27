package neurx.tool.tool_schema
string PARAM_TYPE_STRING  = "string"
string PARAM_TYPE_INT     = "int"
string PARAM_TYPE_BOOL    = "bool"
string PARAM_TYPE_FLOAT   = "float"
string PARAM_TYPE_PATH    = "path"
string PARAM_TYPE_COMMAND = "command"
struct tool_param_schema {
    string name
    string param_type
    string description
    bool   required
    string default_value
}
struct tool_schema {
    string name
    string description
    []tool_param_schema params
    int param_count
}
struct tool_schema_registry {
    []tool_schema schemas
    int count
}
struct tool_schema_validate_result {
    bool   ok
    string error
    string tool_name
}
func new_tool_param(string name, string param_type, string description, bool required, string default_value) tool_param_schema {
    tool_param_schema {
        name:          name,
        param_type:    param_type,
        description:   description,
        required:      required,
        default_value: default_value,
    }
}
func new_tool_schema(string name, string description) tool_schema {
    tool_schema {
        name:        name,
        description: description,
        params:      []tool_param_schema{cap: 8},
        param_count: 0,
    }
}
func tool_schema_add_param(tool_schema schema, tool_param_schema param) tool_schema {
    int n = schema.param_count
    []tool_param_schema next = []tool_param_schema{cap: n + 1}
    int i = 0
    while i < n {
        next[i] = schema.params[i]
        i = i + 1
    }
    next[n] = param
    tool_schema {
        name:        schema.name,
        description: schema.description,
        params:      next,
        param_count: n + 1,
    }
}
func new_tool_schema_registry() tool_schema_registry {
    tool_schema_registry {
        schemas: []tool_schema{cap: 16},
        count:   0,
    }
}
func tool_schema_registry_register(tool_schema_registry reg, tool_schema schema) tool_schema_registry {
    int n = reg.count
    []tool_schema next = []tool_schema{cap: n + 1}
    int i = 0
    while i < n {
        next[i] = reg.schemas[i]
        i = i + 1
    }
    next[n] = schema
    tool_schema_registry {
        schemas: next,
        count:   n + 1,
    }
}
func tool_schema_registry_find(tool_schema_registry reg, string name) tool_schema {
    int i = 0
    while i < reg.count {
        if reg.schemas[i].name == name {
            return reg.schemas[i]
        }
        i = i + 1
    }
    new_tool_schema("", "")
}
func tool_schema_registry_has(tool_schema_registry reg, string name) bool {
    int i = 0
    while i < reg.count {
        if reg.schemas[i].name == name {
            return true
        }
        i = i + 1
    }
    false
}
func tool_schema_workspace_defaults() tool_schema_registry {
    tool_schema_registry reg = new_tool_schema_registry()
    tool_schema s_read = new_tool_schema("read", "Read the contents of a file at the given workspace path.")
    s_read = tool_schema_add_param(s_read, new_tool_param("path", PARAM_TYPE_PATH, "Workspace-relative file path to read.", true, ""))
    s_read = tool_schema_add_param(s_read, new_tool_param("max_lines", PARAM_TYPE_INT, "Maximum number of lines to return (0 = all).", false, "0"))
    reg = tool_schema_registry_register(reg, s_read)
    tool_schema s_write = new_tool_schema("write", "Write or overwrite a file at the given workspace path.")
    s_write = tool_schema_add_param(s_write, new_tool_param("path", PARAM_TYPE_PATH, "Workspace-relative file path to write.", true, ""))
    s_write = tool_schema_add_param(s_write, new_tool_param("content", PARAM_TYPE_STRING, "Full text content to write.", true, ""))
    reg = tool_schema_registry_register(reg, s_write)
    tool_schema s_patch = new_tool_schema("patch", "Replace an exact block of text in a file.")
    s_patch = tool_schema_add_param(s_patch, new_tool_param("path", PARAM_TYPE_PATH, "Workspace-relative file path.", true, ""))
    s_patch = tool_schema_add_param(s_patch, new_tool_param("old_text", PARAM_TYPE_STRING, "Exact existing text to replace.", true, ""))
    s_patch = tool_schema_add_param(s_patch, new_tool_param("new_text", PARAM_TYPE_STRING, "Replacement text.", true, ""))
    s_patch = tool_schema_add_param(s_patch, new_tool_param("replace_all", PARAM_TYPE_BOOL, "Replace all occurrences (default false).", false, "false"))
    reg = tool_schema_registry_register(reg, s_patch)
    tool_schema s_grep = new_tool_schema("grep", "Search for a pattern across workspace files.")
    s_grep = tool_schema_add_param(s_grep, new_tool_param("pattern", PARAM_TYPE_STRING, "Text or regex pattern to search for.", true, ""))
    s_grep = tool_schema_add_param(s_grep, new_tool_param("path", PARAM_TYPE_PATH, "Directory or file to search within (empty = workspace root).", false, ""))
    reg = tool_schema_registry_register(reg, s_grep)
    tool_schema s_find = new_tool_schema("find", "Find files by name glob pattern.")
    s_find = tool_schema_add_param(s_find, new_tool_param("pattern", PARAM_TYPE_STRING, "Glob pattern for file names.", true, ""))
    s_find = tool_schema_add_param(s_find, new_tool_param("path", PARAM_TYPE_PATH, "Root directory to search from.", false, ""))
    reg = tool_schema_registry_register(reg, s_find)
    tool_schema s_ls = new_tool_schema("list_dir", "List files and directories at a path.")
    s_ls = tool_schema_add_param(s_ls, new_tool_param("path", PARAM_TYPE_PATH, "Directory path to list.", true, ""))
    reg = tool_schema_registry_register(reg, s_ls)
    tool_schema s_shell = new_tool_schema("s", "Run a command in the workspace.")
    s_shell = tool_schema_add_param(s_shell, new_tool_param("command", PARAM_TYPE_COMMAND, "Command to execute.", true, ""))
    reg = tool_schema_registry_register(reg, s_shell)
    tool_schema s_del = new_tool_schema("delete", "Delete a file or empty directory.")
    s_del = tool_schema_add_param(s_del, new_tool_param("path", PARAM_TYPE_PATH, "Workspace-relative path to delete.", true, ""))
    reg = tool_schema_registry_register(reg, s_del)
    tool_schema s_mkdir = new_tool_schema("mkdir", "Create a directory (including parents).")
    s_mkdir = tool_schema_add_param(s_mkdir, new_tool_param("path", PARAM_TYPE_PATH, "Directory path to create.", true, ""))
    reg = tool_schema_registry_register(reg, s_mkdir)
    tool_schema s_gst = new_tool_schema("git_status", "Show working-tree status of the repository.")
    reg = tool_schema_registry_register(reg, s_gst)
    tool_schema s_gd = new_tool_schema("git_diff", "Show unstaged or staged diff.")
    s_gd = tool_schema_add_param(s_gd, new_tool_param("args", PARAM_TYPE_STRING, "Extra git diff arguments (e.g. '--staged').", false, ""))
    reg = tool_schema_registry_register(reg, s_gd)
    tool_schema s_gc = new_tool_schema("git_commit", "Stage all changes and create a commit.")
    s_gc = tool_schema_add_param(s_gc, new_tool_param("message", PARAM_TYPE_STRING, "Commit message.", true, ""))
    reg = tool_schema_registry_register(reg, s_gc)
    reg
}
func tool_schema_text_contains(string text, string pattern) bool {
    int tl = len(text)
    int pl = len(pattern)
    if pl == 0 {
        return true
    }
    if tl < pl {
        return false
    }
    int i = 0
    while i <= tl - pl {
        int j = 0
        bool match = true
        while j < pl {
            if text[i + j] != pattern[j] {
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
func tool_schema_validate(tool_schema_registry reg, string tool_name, string raw_input) tool_schema_validate_result {
    if !tool_schema_registry_has(reg, tool_name) {
        return tool_schema_validate_result {
            ok:        true,
            error:     "",
            tool_name: tool_name,
        }
    }
    tool_schema schema = tool_schema_registry_find(reg, tool_name)
    int i = 0
    while i < schema.param_count {
        tool_param_schema p = schema.params[i]
        if p.required {
            bool present = tool_schema_text_contains(raw_input, p.name)
            if !present {
                return tool_schema_validate_result {
                    ok:        false,
                    error:     "missing required param: " + p.name,
                    tool_name: tool_name,
                }
            }
        }
        i = i + 1
    }
    tool_schema_validate_result {
        ok:        true,
        error:     "",
        tool_name: tool_name,
    }
}
func tool_schema_to_prompt_block(tool_schema schema) string {
    string out = "tool: " + schema.name + "\n"
    out = out + "  description: " + schema.description + "\n"
    if schema.param_count > 0 {
        out = out + "  params:\n"
        int i = 0
        while i < schema.param_count {
            tool_param_schema p = schema.params[i]
            string req_str = "optional"
            if p.required {
                req_str = "required"
            }
            out = out + "    - " + p.name + " (" + p.param_type + ", " + req_str + "): " + p.description + "\n"
            i = i + 1
        }
    }
    out
}
func tool_schema_registry_to_prompt(tool_schema_registry reg) string {
    string out = "=== available tools ===\n"
    int i = 0
    while i < reg.count {
        out = out + tool_schema_to_prompt_block(reg.schemas[i])
        i = i + 1
    }
    out + "=== end tools ==="
}
func tool_schema_registry_summary(tool_schema_registry reg) string {
    "tool_schemas count=" + string(reg.count)
}
