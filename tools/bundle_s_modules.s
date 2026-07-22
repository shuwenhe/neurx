package main

use std.io
use std.os
use std.path
use std.strings

func stripPackageAndImports(content string) string {
    lines := strings.Split(content, "\n")
    result := []string{}
    
    for _, line := range lines {
        trimmed := strings.TrimSpace(line)
        if strings.HasPrefix(trimmed, "package ") {
            continue
        }
        if strings.HasPrefix(trimmed, "use neurx.moe.core") {
            continue
        }
        if strings.HasPrefix(trimmed, "use neurx.attention.nda") {
            continue
        }
        result = append(result, line)
    }
    
    return strings.Join(result, "\n")
}

func main() {
    if len(os.Args) < 4 {
        os.Stderr.WriteString("usage: " + os.Args[0] + " <output.s> <entry.s> <dependency.s>...\n")
        os.Exit(2)
    }
    
    output := os.Args[1]
    entry := os.Args[2]
    dependencies := os.Args[3:]
    
    os.MkdirAll(path.Dir(output), 0755)
    
    bundled := "package main\n\n"
    
    for _, source := range dependencies {
        content, err := os.ReadFile(source)
        if err != nil {
            os.Stderr.WriteString("error reading " + source + ": " + err.Error() + "\n")
            os.Exit(1)
        }
        
        processed := stripPackageAndImports(string(content))
        bundled += processed + "\n\n"
    }
    
    entryContent, err := os.ReadFile(entry)
    if err != nil {
        os.Stderr.WriteString("error reading " + entry + ": " + err.Error() + "\n")
        os.Exit(1)
    }
    
    processed := stripPackageAndImports(string(entryContent))
    bundled += processed
    
    err = os.WriteFile(output, []byte(bundled), 0644)
    if err != nil {
        os.Stderr.WriteString("error writing " + output + ": " + err.Error() + "\n")
        os.Exit(1)
    }
}
