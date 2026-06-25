package neurx.migration.runtime_interface

use neurx.strings
use neurx.runtime.io.{runtime_read_text_file, runtime_file_exists}

// Minimal S-side utilities to help migrate runtime features from legacy wrappers.
// This file provides basic IR manifest inspection helpers as a starting point.

func read_file(string path) string {
    runtime_read_text_file(path)
}

func list_ir_files() []string {
    // very small parser: read build/ir/manifest.json and extract lines with .ir
    string manifest = read_file("build/ir/manifest.json")
    if neurx.strings.strings_eq(manifest, "") {
        []string out = []string{cap: 0}
        return out
    }
    // Simple line-by-line parsing for .ir files mentioned in manifest
    []string res = []string{cap: 0}
    int n = len(manifest)
    string current_line = ""
    int i = 0
    while i < n {
        string ch = neurx.strings.substring(manifest, i, i + 1)
        int chi = int(string(ch))
        // '\n' ASCII is 10
        if chi == 10 {
            // process current_line
            string s = current_line
            bool has_dot_ir = false
            // check for ".ir" in string (simple search)
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
                // basic trimming - just remove quotes and commas if present
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
    // skip leading whitespace and quotes
    while start < end {
        string fc = neurx.strings.substring(s, start, start + 1)
        int fci = int(string(fc))
        // space=32, tab=9, "=34
        if fci == 32 || fci == 9 || fci == 34 {
            start = start + 1
        } else {
            break
        }
    }
    // skip trailing whitespace, quotes, commas
    while end > start {
        string lc = neurx.strings.substring(s, end - 1, end)
        int lci = int(string(lc))
        // comma=44
        if lci == 32 || lci == 9 || lci == 34 || lci == 44 {
            end = end - 1
        } else {
            break
        }
    }
    neurx.strings.substring(s, start, end)
}
