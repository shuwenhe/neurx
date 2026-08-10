package neurx.strings

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func strings_eq(string a, string b) bool {
    if len(a) != len(b) {
        return false
    }
    bool eq = true
    int i = 0
    while i < len(a) {
        if a[i] != b[i] {
            eq = false
        }
        i = i + 1
    }
    eq
}

func string_at([]string arr, int idx) string {
    if idx < 0 || idx >= len(arr) {
        return ""
    }
    string val = arr[idx]
    val
}

func substring(string s, int start, int end) string {
    if start < 0 {
        start = 0
    }
    if end > len(s) {
        end = len(s)
    }
    if start >= end {
        return ""
    }
    int n = end - start
    string out = ""
    int i = 0
    while i < n {
        out = out + string(s[start + i])
        i = i + 1
    }
    out
}

func concat2(string a, string b) string {
    int n1 = len(a)
    int n2 = len(b)
    int total = n1 + n2
    string out = ""
    int i = 0
    while i < n1 {
        out = out + string(a[i])
        i = i + 1
    }
    i = 0
    while i < n2 {
        out = out + string(b[i])
        i = i + 1
    }
    out
}

func concat3(string a, string b, string c) string {
    concat2(concat2(a, b), c)
}

func concat4(string a, string b, string c, string d) string {
    concat2(concat3(a, b, c), d)
}

func concat5(string a, string b, string c, string d, string e) string {
    concat2(concat4(a, b, c, d), e)
}

func concat6(string a, string b, string c, string d, string e, string f) string {
    concat2(concat5(a, b, c, d, e), f)
}

func string_set_workaround() {

}
