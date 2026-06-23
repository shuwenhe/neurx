package neurx.strings

// copy_strings: creates a deep copy of a string array
func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

// strings_eq: compares two strings for equality
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

// string_at: safely get string at index, returns empty string if out of bounds
func string_at([]string arr, int idx) string {
    if idx < 0 || idx >= len(arr) {
        return ""
    }
    // Workaround: manually copy each string character by character
    string val = arr[idx]
    val
}

// substring: extract substring from start to end (exclusive)
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

// concat2: concatenate two strings
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

// concat3: concatenate three strings
func concat3(string a, string b, string c) string {
    concat2(concat2(a, b), c)
}

// concat4: concatenate four strings
func concat4(string a, string b, string c, string d) string {
    concat2(concat3(a, b, c), d)
}

// concat5: concatenate five strings
func concat5(string a, string b, string c, string d, string e) string {
    concat2(concat4(a, b, c, d), e)
}

// concat6: concatenate six strings
func concat6(string a, string b, string c, string d, string e, string f) string {
    concat2(concat5(a, b, c, d, e), f)
}

// string_set: set element at index in string array (workaround for assignment issues)
// Note: S compiler may not support mut parameters, so this function may need adjustment
// For now, it's defined but the actual implementation depends on S language capabilities
func string_set_workaround() {
    // Placeholder - string array mutation is handled inline in calling code
}
