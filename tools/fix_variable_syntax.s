package main

use neurx.runtime.io.{runtime_run_command, runtime_run_command_output}

func main() {
    print("========================================\n")
    print("NeurX Variable Syntax Fixer\n")
    print("Converting: name: type → type name\n")
    print("========================================\n\n")
    
    // 执行修复脚本
    fix_variable_declarations()
    
    print("\n✓ 变量声明格式统一完成\n")
}

func fix_variable_declarations() {
    // 使用 sed 批量替换函数参数和变量声明
    // 策略：保留 struct 字段（行首带 tab），修改函数参数和变量声明
    
    string cmd = `
find ./neurx -name "*.s" -type f | while read file; do
    # 修复函数参数：(\w+): (type) → (type \w+)
    # 这个较为复杂，需要一个辅助脚本
    sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\): \(int\|string\|bool\|float\|i32\|i64\|f32\|f64\)/\2 \1/g' "$file"
done
`
    
    // 更好的方法：创建一个 Python 脚本
    create_fixer_script()
    
    // 执行 Python 脚本
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
        # 跳过注释和空行
        stripped = line.strip()
        if not stripped or stripped.startswith('//'):
            continue
        
        # 跳过 struct 字段定义（这些应该保留 name: type）
        # struct 字段通常有缩进且不包含 func 关键字
        if 'struct' in '\n'.join(lines[max(0, i-5):i]):
            indent = len(line) - len(line.lstrip())
            # 如果有缩进且是字段定义，跳过
            if indent > 0 and ': ' in line:
                continue
        
        # 修复函数参数：func name(..., param: type, ...)
        # 模式：word: (type) → type word
        # 但需要避免在 struct 中修改
        
        # 简单替换：identifier: type → type identifier
        # 支持的类型：int, string, bool, float, i32, i64, f32, f64, 
        # 以及复杂类型如 []int, []string 等
        
        pattern = r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*((?:int|string|bool|float|i32|i64|f32|f64|vector|map|option)\b|\[\](?:int|string|float|bool))'
        replacement = r'\2 \1'
        
        # 更智能的替换：只在函数声明中替换
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
    
    // 写入脚本
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
