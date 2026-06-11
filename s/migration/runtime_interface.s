package neurx.migration.runtime_interface

// Minimal S-side utilities to help migrate runtime features from legacy wrappers.
// This file provides basic IR manifest inspection helpers as a starting point.

func read_file(string path) string {
    fp := open(path, "r")
    if fp == nil {
        return ""
    }
    defer fp.close()
    buf := []byte{}
    for {
        tmp := make([]byte, 4096)
        n := fp.read(tmp)
        if n <= 0 {
            break
        }
        buf = append(buf, tmp[:n]...)
    }
    return string(buf)
}

func list_ir_files() []string {
    // very small parser: read build/ir/manifest.json and extract lines with .ir
    manifest := read_file("build/ir/manifest.json")
    if manifest == "" {
        return []string{}
    }
    res := []string{}
    for _, line := range split_lines(manifest) {
        if contains(line, ".ir") {
            // strip quotes and commas
            s := trim(line)
            s = trim_prefix(s, "\"")
            s = trim_suffix(s, "\"")
            s = trim_suffix(s, ",")
            if s != "" {
                res = append(res, s)
            }
        }
    }
    return res
}

func split_lines(string s) []string

func contains(string s, string substr) bool

func trim(string s) string

func trim_prefix(string s, string p) string

func trim_suffix(string s, string p) string
