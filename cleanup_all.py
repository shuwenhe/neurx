#!/usr/bin/env python3
import os
import re

def remove_comments_and_clean(content):
    """Remove comments and extra blank lines"""
    lines = content.split('\n')
    result = []
    in_multiline = False

    for line in lines:
        # Handle multiline comments
        if in_multiline:
            if '*/' in line:
                idx = line.index('*/')
                line = line[idx+2:]
                in_multiline = False
            else:
                continue

        # Start multiline comment
        if '/*' in line:
            idx = line.index('/*')
            before = line[:idx]
            rest = line[idx+2:]
            if '*/' in rest:
                end_idx = rest.index('*/')
                line = before + rest[end_idx+2:]
            else:
                line = before
                in_multiline = True

        # Remove line comments
        if '//' in line:
            idx = line.index('//')
            line = line[:idx]

        result.append(line)

    # Remove extra blank lines
    content = '\n'.join(result)
    lines = content.split('\n')
    result = []
    blank_count = 0

    for line in lines:
        if line.strip() == '':
            blank_count += 1
            if blank_count <= 1:
                result.append('')
        else:
            blank_count = 0
            result.append(line)

    # Ensure spacing between func/struct
    content = '\n'.join(result)
    lines = content.split('\n')
    result = []

    for i, line in enumerate(lines):
        result.append(line)
        if i < len(lines) - 1:
            trimmed = line.strip()
            next_trimmed = lines[i+1].strip() if i+1 < len(lines) else ''

            is_func = trimmed.startswith('func ') and trimmed.endswith('{')
            is_struct = trimmed.startswith('struct ') and trimmed.endswith('{')
            next_is_decl = (next_trimmed.startswith('func ') or next_trimmed.startswith('struct ')) and next_trimmed

            if (is_func or is_struct) and next_is_decl:
                result.append('')

    content = '\n'.join(result)
    content = re.sub(r'\n\n+', '\n', content)
    content = content.rstrip() + '\n'

    return content

def process_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        cleaned = remove_comments_and_clean(content)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(cleaned)

        return True
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    root = '.'
    count = 0
    for dirpath, dirnames, filenames in os.walk(root):
        if '.git' in dirnames:
            dirnames.remove('.git')

        for filename in filenames:
            if filename.endswith('.s'):
                filepath = os.path.join(dirpath, filename)
                print(f"Cleaning: {filepath}")
                if process_file(filepath):
                    count += 1

    print(f"\nCleanup completed! Processed {count} files.")

if __name__ == '__main__':
    main()
