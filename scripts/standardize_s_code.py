#!/usr/bin/env python3
"""
S Language Code Style Standardizer
Converts S code from modern style (structure/fn) to Go style (struct/func)

Usage:
    python3 standardize.py <file.s>
    python3 standardize.py --all
"""

import re
import sys
from pathlib import Path

def standardize_s_code(content):
    """Convert S code from modern to Go style"""
    
    # Rule 1: Convert structure to struct
    content = re.sub(r'\bstructure\s+(\w+)\s*\{', r'struct \1 {', content)
    
    # Rule 2: Convert function definitions
    # fn name(param: type): ReturnType { → func name(param: type) ReturnType {
    content = re.sub(
        r'\bfn\s+(\w+)\s*\((.*?)\)\s*:\s*(\w+(?:\[[^\]]*\])?(?:\s*,\s*\w+(?:\[[^\]]*\])?)*)\s*\{',
        r'func \1(\2) \3 {',
        content,
        flags=re.DOTALL
    )
    
    # Rule 3: Convert simple function returns
    # fn name(): Type { → func name() Type {
    content = re.sub(
        r'\bfn\s+(\w+)\s*\(\s*\)\s*:\s*(\w+(?:\[[^\]]*\])?)\s*\{',
        r'func \1() \2 {',
        content
    )
    
    # Rule 4: Convert tuple returns
    # ): (Type1, Type2) { → ) (Type1, Type2) {
    content = re.sub(
        r'\)\s*:\s*\((.*?)\)\s*\{',
        r') (\1) {',
        content,
        flags=re.DOTALL
    )
    
    # Rule 5: Convert structure field definitions
    # field: type → type field
    # This is tricky because we need to be inside struct definitions only
    # Look for pattern inside struct blocks
    def convert_fields(match):
        struct_body = match.group(2)
        # Convert each line: field: type → type field
        lines = struct_body.split('\n')
        converted_lines = []
        
        for line in lines:
            # Skip comments and empty lines
            if line.strip().startswith('//') or not line.strip():
                converted_lines.append(line)
                continue
            
            # Match field: type patterns (not inside comments)
            # Handle cases like: name: int, items: vector, etc.
            match_field = re.match(r'(\s*)(\w+)\s*:\s*(\[?\]?\w+(?:\[.*?\])?)\s*(//.*)?$', line)
            if match_field:
                indent, field_name, field_type, comment = match_field.groups()
                comment = comment if comment else ''
                converted_lines.append(f'{indent}{field_type} {field_name} {comment}'.rstrip() + ('  ' + comment if comment else ''))
            else:
                converted_lines.append(line)
        
        return match.group(1) + 'struct ' + match.group(3) + ' {' + '\n' + '\n'.join(converted_lines) + '\n' + match.group(4)
    
    content = re.sub(
        r'(^|\n)(\s*)struct\s+(\w+)\s*\{\n(.*?)\n(\s*)\}',
        convert_fields,
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    # Rule 6: Convert variable declarations
    # var name: type = value → type name = value
    content = re.sub(
        r'\bvar\s+(\w+)\s*:\s*(\w+(?:\[[^\]]*\])?)\s*=',
        r'\2 \1 =',
        content
    )
    
    # Rule 7: Convert standalone variable declarations
    # var name: type → type name
    # But be careful not to convert inside comments
    lines = content.split('\n')
    result_lines = []
    
    for line in lines:
        if '//' in line:
            code_part, comment_part = line.split('//', 1)
            code_part = re.sub(r'\bvar\s+(\w+)\s*:\s*(\w+(?:\[[^\]]*\])?)\b', r'\2 \1', code_part)
            result_lines.append(code_part + '//' + comment_part)
        else:
            line = re.sub(r'\bvar\s+(\w+)\s*:\s*(\w+(?:\[[^\]]*\])?)\b', r'\2 \1', line)
            result_lines.append(line)
    
    content = '\n'.join(result_lines)
    
    return content

def process_file(filepath):
    """Process a single S file"""
    print(f"Processing {filepath}...")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        original = f.read()
    
    converted = standardize_s_code(original)
    
    if original != converted:
        # Create backup
        backup_path = filepath + '.bak'
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(original)
        
        # Write converted
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(converted)
        
        print(f"  ✓ Converted (backup: {backup_path})")
        return True
    else:
        print(f"  - No changes needed")
        return False

def find_neurx_s_files():
    """Find all .s files in neurx directory"""
    base_path = Path('/Users/feifei/train/neurx')
    return list(base_path.glob('**/*.s'))

def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--all':
        # Process all .s files in neurx
        files = find_neurx_s_files()
        # Filter for enterprise modules only
        enterprise_files = [
            f for f in files if any(x in str(f) for x in [
                'compute/flash_attention',
                'optimization/mixed_precision',
                'distributed/fault_recovery',
                'monitoring/distributed_metrics',
                'quantization/quantizer',
                'bin/train_enterprise_2t'
            ])
        ]
    elif len(sys.argv) > 1:
        files = [Path(sys.argv[1])]
    else:
        print("Usage: python3 standardize.py <file.s> or python3 standardize.py --all")
        sys.exit(1)
    
    total = len(files)
    converted = 0
    
    for filepath in files:
        if process_file(filepath):
            converted += 1
    
    print(f"\n📊 Summary: {converted}/{total} files converted")

if __name__ == '__main__':
    main()
