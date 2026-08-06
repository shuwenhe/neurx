package neurx.migration.runtime_interface
use neurx.strings
use neurx.runtime.io.{runtime_read_text_file, runtime_file_exists}

func read_file(string path) string {
    runtime_read_text_file(path)
}

func list_ir_files() []string {
    string manifest = read_file("build/ir/manifest.json")
    if neurx.strings.strings_eq(manifest, "") {
        []string out = []string{cap: 0}
        return out
    }
    []string res = []string{cap: 0}
    int n = len(manifest)
    string current_line = ""
    int i = 0
    while i < n {
        string ch = neurx.strings.substring(manifest, i, i + 1)
        int chi = int(string(ch))
        if chi == 10 {
            string s = current_line
            bool has_dot_ir = false
            int slen = len(s)
            int k = 0
            while k < slen - 2 {
                string c1 = neurx.strings.substring(s, k, k + 1)
                string c2 = neurx.strings.substring(s, k + 1, k + 2)
                string c3 = neurx.strings.substring(s, k + 2, k + 3)
                if neurx.strings.strings_eq(c1, ".") && neurx.strings.strings_eq(c2, "i") && neurx.strings.strings_eq(c3, "r") {
                    has_dot_ir = true
                    k = slen
                }
                k = k + 1
            }
            if has_dot_ir {
                s = trim_simple(s)
                if !neurx.strings.strings_eq(s, "") {
                    res.push(s)
                }
            }
            current_line = ""
        } else {
            current_line = neurx.strings.concat2(current_line, ch)
        }
        i = i + 1
    }
    res
}

func trim_simple(string s) string {
    int n = len(s)
    if n == 0 {
        return ""
    }
    int start = 0
    int end = n
    while start < end {
        string fc = neurx.strings.substring(s, start, start + 1)
        int fci = int(string(fc))
        if fci == 32 || fci == 9 || fci == 34 {
            start = start + 1
        } else {
            break
        }
    }
    while end > start {
        string lc = neurx.strings.substring(s, end - 1, end)
        int lci = int(string(lc))
        if lci == 32 || lci == 9 || lci == 34 || lci == 44 {
            end = end - 1
        } else {
            break
        }
    }
    neurx.strings.substring(s, start, end)
}

