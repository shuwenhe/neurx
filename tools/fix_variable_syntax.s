package main
use neurx.runtime.io.{runtime_run_command, runtime_run_command_output}
func main() {
    print("========================================\n")
    print("NeurX Variable Syntax Fixer\n")
    print("Converting: name: type → type name\n")
    print("========================================\n\n")
    fix_variable_declarations()
    print("\n✓ 变量声明格式统一完成\n")
}
func fix_variable_declarations() {
    string cmd = `
find ./neurx -name "*.s" -type f | while read file; do
    sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\): \(int\|string\|bool\|float\|i32\|i64\|f32\|f64\)/\2 \1/g' "$file"
done
`
    create_fixer_script()
    run_fixer()
}
func create_fixer_script() {
    string script = `#!/usr/bin/env python3
import os
import re
import sys
def fix_file(filepath):
    """
    修复单个文件中的变量声明格式
    将 name: type 改为 type name
    保留 struct 字段定义
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except:
        return False
    original = content
    lines = content.split('\n')
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('
            continue
        if 'struct' in '\n'.join(lines[max(0, i-5):i]):
            indent = len(line) - len(line.lstrip())
            if indent > 0 and ': ' in line:
                continue
        pattern = r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*((?:int|string|bool|float|i32|i64|f32|f64|vector|map|option)\b|\[\](?:int|string|float|bool))'
        replacement = r'\2 \1'
        if 'func' in line or '(' in line:
            new_line = re.sub(pattern, replacement, line)
            lines[i] = new_line
    content = '\n'.join(lines)
    if content != original:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        except:
            return False
    return False
def main():
    root_dir = './neurx'
    count = 0
    fixed = 0
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.s'):
                filepath = os.path.join(root, file)
                count += 1
                if fix_file(filepath):
                    fixed += 1
                    print(f'✓ {filepath}')
    print(f'\n完成: {count} 个文件扫描, {fixed} 个文件修改')
if __name__ == '__main__':
    main()
`
    import_result := runtime_run_command_output(`cat > /tmp/fix_neurx_syntax.py << 'PYEOF'
` + script + `
PYEOF
`)
    if !import_result.ok {
        print("error: 无法创建 Python 脚本\n")
        return
    }
}
func run_fixer() {
    cd_result := runtime_run_command("cd /home/shuwen/shuwen && python3 /tmp/fix_neurx_syntax.py")
    if !cd_result.ok {
        print("error: 执行 Python 脚本失败\n")
        print("提示：请手动运行：python3 /tmp/fix_neurx_syntax.py\n")
        return
    }
    print("\n执行完成\n")
}
