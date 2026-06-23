#!/usr/bin/env python3
"""Fix unsupported syntax in neurx .s files for S compiler compatibility."""
import re
import sys
import os

def fix_modulo(content):
    """Replace a % b with (a - (a / b) * b) using simple expression parsing."""
    lines = content.split('\n')
    result = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith('//') or stripped.startswith('package') or stripped.startswith('use '):
            result.append(line)
            continue
        if '%' not in line:
            result.append(line)
            continue
        in_string = False
        has_code_modulo = False
        for i, ch in enumerate(line):
            if ch == '"' and (i == 0 or line[i-1] != '\\'):
                in_string = not in_string
            elif ch == '%' and not in_string:
                has_code_modulo = True
                break
        if not has_code_modulo:
            result.append(line)
            continue
        new_line = replace_modulo_ops(line)
        result.append(new_line)
    return '\n'.join(result)

def replace_modulo_ops(line):
    """Replace modulo operations in a single line."""
    result = []
    i = 0
    in_string = False
    while i < len(line):
        ch = line[i]
        if ch == '"' and (i == 0 or line[i-1] != '\\'):
            in_string = not in_string
            result.append(ch)
            i += 1
        elif ch == '%' and not in_string:
            left = extract_left_operand(result)
            right, end_pos = extract_right_operand(line, i + 1)
            result = result[:len(result) - len(left)]
            result.append(f'({left} - ({left} / {right}) * {right})')
            i = end_pos
        else:
            result.append(ch)
            i += 1
    return ''.join(result)

def extract_left_operand(chars):
    j = len(chars) - 1
    while j >= 0 and chars[j] in ' \t':
        j -= 1
    if j < 0:
        return ''
    end = j + 1
    if chars[j] == ')':
        depth = 1
        j -= 1
        while j >= 0 and depth > 0:
            if chars[j] == ')':
                depth += 1
            elif chars[j] == '(':
                depth -= 1
            j -= 1
        while j >= 0 and (chars[j].isalnum() or chars[j] in '_.'):
            j -= 1
        return ''.join(chars[j+1:end])
    while j >= 0 and (chars[j].isalnum() or chars[j] in '_.[]'):
        if chars[j] == ']':
            depth = 1
            j -= 1
            while j >= 0 and depth > 0:
                if chars[j] == ']':
                    depth += 1
                elif chars[j] == '[':
                    depth -= 1
                j -= 1
        j -= 1
    start = j + 1
    return ''.join(chars[start:end]).strip()

def extract_right_operand(line, start):
    i = start
    while i < len(line) and line[i] in ' \t':
        i += 1
    if i >= len(line):
        return '', i
    if line[i] == '(':
        depth = 1
        j = i + 1
        while j < len(line) and depth > 0:
            if line[j] == '(':
                depth += 1
            elif line[j] == ')':
                depth -= 1
            j += 1
        return line[i:j], j
    j = i
    while j < len(line) and (line[j].isalnum() or line[j] in '_.'):
        j += 1
    while j < len(line) and line[j] == '[':
        depth = 1
        j += 1
        while j < len(line) and depth > 0:
            if line[j] == '[':
                depth += 1
            elif line[j] == ']':
                depth -= 1
            j += 1
    return line[i:j], j

def fix_xor(content):
    lines = content.split('\n')
    result = []
    for line in lines:
        if '^' in line and not line.lstrip().startswith('//'):
            in_string = False
            new_line = []
            for i, ch in enumerate(line):
                if ch == '"' and (i == 0 or line[i-1] != '\\'):
                    in_string = not in_string
                    new_line.append(ch)
                elif ch == '^' and not in_string:
                    new_line.append('+')
                else:
                    new_line.append(ch)
            result.append(''.join(new_line))
        else:
            result.append(line)
    return '\n'.join(result)

def fix_ampersand(content):
    lines = content.split('\n')
    result = []
    for line in lines:
        if '&' in line and not line.lstrip().startswith('//'):
            in_string = False
            new_line = []
            for i, ch in enumerate(line):
                if ch == '"' and (i == 0 or line[i-1] != '\\'):
                    in_string = not in_string
                    new_line.append(ch)
                elif ch == '&' and not in_string:
                    pass
                else:
                    new_line.append(ch)
            result.append(''.join(new_line))
        else:
            result.append(line)
    return '\n'.join(result)

def fix_file(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return False
    original = content
    content = fix_modulo(content)
    content = fix_xor(content)
    content = fix_ampersand(content)
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed: {filepath}")
        return True
    return False

if __name__ == '__main__':
    for filepath in sys.argv[1:]:
        fix_file(filepath)
