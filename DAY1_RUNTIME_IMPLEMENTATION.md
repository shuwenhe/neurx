# Day 1 Runtime Implementation - Quick Reference

**Date**: 2024-07-31  
**Location**: `/home/shuwen/shuwen/s/src/runtime/`  
**Goal**: Implement 7 runtime functions for checkpoint support

---

## ⚠️ 工程级注意点 (避免后期踩坑)

### 1. String Runtime 统一 ABI (CRITICAL)

**问题**: S 层函数签名必须稳定，避免命名冲突

**错误做法**:
```c
int str_len(char* str);           // ❌ 可能与系统库冲突
char* read_file(char* path);      // ❌ 未来膨胀时容易冲突
```

**正确做法**: 统一前缀 `srt_` (S Runtime)
```c
int srt_str_len(char* str);
int srt_str_find(char* src, char* target);
char srt_str_char_at(char* str, int index);
char* srt_read_file(char* path);
```

**原因**: 
- 未来 runtime 会膨胀: string, file, memory, thread, network, CUDA, NPU
- 类似 CPython C API (`Py_*`), Lua C API (`lua_*`)
- 清晰的模块边界

---

### 2. read_file 内存所有权 (最容易出问题)

**问题**: `char* content = read_file("state.json")` 这个字符串谁释放？

**错误做法**:
```c
// ❌ 第一版就让用户手动 free
char* content = malloc(size);
// 用户需要: free(content)  ← S 语言目前没有成熟内存管理接口
```

**正确做法**: Runtime 管理内存
```c
// ✅ 第一版由 Runtime allocator 管理
char* srt_read_file(char* filepath) {
    // ... read file ...
    
    // Runtime allocator (用户不用 free)
    char* buffer = runtime_alloc(size + 1);
    // 或者使用 GC 管理的内存池
    
    return buffer;
}
```

**适用场景**: checkpoint, config, logs (短生命周期)

**未来扩展**: 
```c
void srt_free(char* ptr);  // 当需要手动管理时再添加
```

**User Quote**: "不要第一版就 malloc + 用户 free。因为 S 语言目前没有成熟内存管理接口。"

---

### 3. rename_file 跨平台行为 (Atomic Checkpoint)

**问题**: Linux `rename(old, new)` 通常是 atomic，但不同文件系统行为略有差异

**错误做法**:
```c
// ❌ 简单 rename，可能不够原子
rename("checkpoint.json.tmp", "checkpoint.json");
```

**正确做法**: 真正工业级 atomic replace
```c
bool srt_atomic_replace(char* tmp, char* target) {
    // 1. fsync temp file (flush to disk)
    int fd = open(tmp, O_RDONLY);
    fsync(fd);
    close(fd);
    
    // 2. rename (atomic on POSIX)
    if (rename(tmp, target) != 0) {
        return false;
    }
    
    // 3. fsync directory (ensure metadata persisted)
    char* dir = dirname(target);
    fd = open(dir, O_RDONLY);
    fsync(fd);
    close(fd);
    
    return true;
}
```

**Why Critical**:
- 机器掉电时，只 rename 可能丢失 metadata
- `fsync(directory)` 确保目录项持久化
- 这才是真正工业 checkpoint (OpenAI/Anthropic/DeepMind 级别)

**User Quote**: "rename_file 要测试跨平台行为。这才是真正工业 checkpoint。"

---

## 📁 Runtime 目录结构 (推荐重构)

**当前** (可能):
```
s/src/runtime.c  # 所有函数堆在一起
```

**推荐** (工程化):
```
s/src/runtime/
├── runtime.h        # Public API declarations
├── runtime.c        # Core runtime initialization
├── string.c         # String functions (srt_str_*)
├── file.c           # File I/O functions (srt_file_*, srt_read_file, etc.)
├── memory.c         # Memory allocator (future)
└── tests/
    ├── test_string.c
    ├── test_file.c
    └── test_atomic.c
```

**原因**:
- 现在: 7 functions
- 未来: String, File, Memory, Thread, Network, CUDA, NPU
- 一定会膨胀，不要继续塞进 runtime.c

**User Quote**: "不要继续把所有东西塞进 runtime.c。未来 Runtime 一定会膨胀。"

---

## 🎯 Day 1 实现顺序 (分 3 个 Commits)

**不要七个一起写！** 建议分阶段实现和验证。

### Commit 1: String Runtime (上午 2小时)

**实现**:
```c
// In s/src/runtime/string.c
int srt_str_len(char* str);
char srt_str_char_at(char* str, int index);
int srt_str_find(char* src, char* target);
```

**测试**:
```bash
s posttrain/checkpoint/test_string.s /tmp/test_string
/tmp/test_string
# Expected: String API 所有测试 ✓ PASS
```

**验收**: String tests PASS → 进入文件 I/O

---

### Commit 2: File Runtime (上午 2小时 + 下午 2小时)

**实现**:
```c
// In s/src/runtime/file.c
bool srt_write_file(char* filepath, char* content);
char* srt_read_file(char* filepath);  // Runtime allocator 管理内存
bool srt_file_exists(char* filepath);
```

**测试**:
```bash
s posttrain/checkpoint/test_file.s /tmp/test_file
/tmp/test_file
# Expected: File I/O 所有测试 ✓ PASS
```

**验收**: File I/O tests PASS → 进入 atomic rename

---

### Commit 3: Atomic Checkpoint (下午 2小时)

**实现**:
```c
// In s/src/runtime/file.c
bool srt_atomic_replace(char* tmp_path, char* target_path);
// Or alias: bool srt_rename_file(char* old, char* new);
```

**测试**:
```bash
s posttrain/checkpoint/test_atomic.s /tmp/test_atomic
/tmp/test_atomic
# Expected: Atomic rename test ✓ PASS
```

**验收**: Atomic tests PASS → Day 1 完成

---

## Day 1.1: String Runtime (上午 4小时)

### 1. str_len - 最基础

**Signature**:
```c
Value* builtin_str_len(Value** args, int argc) {
    if (argc != 1 || args[0]->type != VAL_STRING) {
        return make_int(0);
    }
    return make_int(strlen(args[0]->str_val));
}
```

**Test**:
```s
str_len("hello") → 5
str_len("checkpoint_step_000100") → 22
str_len("") → 0
```

**Usage**: JSON 字符串长度检查

---

### 2. str_char_at - JSON parser 逐字符扫描

**Signature**:
```c
Value* builtin_str_char_at(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_INT) {
        return make_string("");
    }
    
    char* str = args[0]->str_val;
    int index = args[1]->int_val;
    int len = strlen(str);
    
    if (index < 0 || index >= len) {
        return make_string("");
    }
    
    // Create single-character string
    char result[2] = {str[index], '\0'};
    return make_string(result);
}
```

**Test**:
```s
str_char_at("abc", 0) → "a"
str_char_at("abc", 1) → "b"
str_char_at("checkpoint", 5) → "p"
str_char_at("test", -1) → ""  // Out of bounds
str_char_at("test", 100) → ""  // Out of bounds
```

**Usage**: JSON parser 逐字符解析 `"{step:100}"`

---

### 3. str_find - JSON decoder 核心

**Signature**:
```c
Value* builtin_str_find(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_STRING) {
        return make_int(-1);
    }
    
    char* haystack = args[0]->str_val;
    char* needle = args[1]->str_val;
    
    char* pos = strstr(haystack, needle);
    if (pos == NULL) {
        return make_int(-1);
    }
    
    return make_int(pos - haystack);
}
```

**Test**:
```s
str_find("checkpoint_step_000100", "step") → 11
str_find("step=100", "step") → 0
str_find("hello world", "world") → 6
str_find("test", "xyz") → -1  // Not found
str_find("", "x") → -1  // Empty haystack
```

**Usage**: JSON key 查找 `"step":` 在 JSON 字符串中的位置

---

## Day 1.2: File Runtime (下午 4小时)

### 4. write_file - 支持 atomic write pattern

**Signature**:
```c
Value* builtin_write_file(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_STRING) {
        return make_bool(false);
    }
    
    char* filepath = args[0]->str_val;
    char* content = args[1]->str_val;
    
    FILE* fp = fopen(filepath, "wb");  // Binary mode
    if (fp == NULL) {
        return make_bool(false);
    }
    
    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, fp);
    
    fflush(fp);  // IMPORTANT: Flush to disk for atomic write
    fclose(fp);
    
    return make_bool(written == len);
}
```

**Test**:
```s
write_file("/tmp/test.txt", "hello world") → true
write_file("/invalid/path/test.txt", "fail") → false
write_file("/tmp/checkpoint.json.tmp", "{\"step\": 100}") → true
```

**Usage**: 写 `checkpoint.json.tmp` (配合 rename_file 实现原子写入)

---

### 5. read_file - Runtime allocator 管理内存

**Signature**:
```c
Value* builtin_read_file(Value** args, int argc) {
    if (argc != 1 || args[0]->type != VAL_STRING) {
        return make_string("");
    }
    
    char* filepath = args[0]->str_val;
    
    FILE* fp = fopen(filepath, "rb");  // Binary mode
    if (fp == NULL) {
        return make_string("");
    }
    
    // Get file size
    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    // Allocate buffer (Runtime allocator manages memory)
    char* buffer = (char*)malloc(size + 1);
    if (buffer == NULL) {
        fclose(fp);
        return make_string("");
    }
    
    // Read file
    size_t read_bytes = fread(buffer, 1, size, fp);
    buffer[read_bytes] = '\0';
    fclose(fp);
    
    // Create S string value
    Value* result = make_string(buffer);
    free(buffer);  // Free temp buffer after making Value
    
    return result;
}
```

**Test**:
```s
write_file("/tmp/test.txt", "hello")
read_file("/tmp/test.txt") → "hello"
read_file("/nonexistent.txt") → ""
```

**Usage**: 读 checkpoint JSON 文件

**注意**: Runtime allocator 管理内存，不要让 malloc/free 散落在用户代码

---

### 6. file_exists - checkpoint 判断存在

**Signature**:
```c
Value* builtin_file_exists(Value** args, int argc) {
    if (argc != 1 || args[0]->type != VAL_STRING) {
        return make_bool(false);
    }
    
    char* filepath = args[0]->str_val;
    
    struct stat st;
    return make_bool(stat(filepath, &st) == 0);
}
```

**Test**:
```s
write_file("/tmp/test.txt", "hello")
file_exists("/tmp/test.txt") → true
file_exists("/nonexistent.txt") → false
```

**Usage**: 判断 `checkpoint/latest_checkpoint.txt` 是否存在

---

### 7. rename_file - ⚠️ CRITICAL: Atomic rename

**Signature**:
```c
Value* builtin_rename_file(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_STRING) {
        return make_bool(false);
    }
    
    char* old_path = args[0]->str_val;
    char* new_path = args[1]->str_val;
    
    // rename() is atomic on POSIX systems
    return make_bool(rename(old_path, new_path) == 0);
}
```

**Test**:
```s
write_file("/tmp/checkpoint.json.tmp", "{\"step\": 100}")
rename_file("/tmp/checkpoint.json.tmp", "/tmp/checkpoint.json") → true
file_exists("/tmp/checkpoint.json") → true
file_exists("/tmp/checkpoint.json.tmp") → false  // Old file gone
```

**Usage**: Atomic checkpoint save pattern

**Atomic Write Pattern**:
```
1. write_file("checkpoint.json.tmp", content)
2. fflush() / fsync()
3. rename("checkpoint.json.tmp", "checkpoint.json")  // Atomic!
   - Either completes fully or not at all
   - No half-written checkpoint.json
   - Safe even if machine crashes
```

**Why Critical**: 
- 机器掉电时，rename 要么完成要么不完成（原子操作）
- 不会出现半写状态的 `checkpoint.json`
- 避免 checkpoint 损坏导致训练无法恢复

---

## Registration in S Runtime

After implementing functions, register them in S runtime symbol table:

```c
// In runtime initialization
register_builtin("str_len", builtin_str_len);
register_builtin("str_char_at", builtin_str_char_at);
register_builtin("str_find", builtin_str_find);
register_builtin("write_file", builtin_write_file);
register_builtin("read_file", builtin_read_file);
register_builtin("file_exists", builtin_file_exists);
register_builtin("rename_file", builtin_rename_file);
```

---

## Verification

### Run S Runtime Tests
```bash
cd /home/shuwen/shuwen/neurx
s posttrain/checkpoint/test_runtime.s /tmp/test_runtime
/tmp/test_runtime
```

**Expected Output**:
```
====================================
[Test] str_len()
====================================
Input: 'checkpoint_step_000100'
Length: 22
Expected: 22  ✓ PASS

====================================
[Test] str_find()
====================================
Haystack: 'checkpoint_step_000100'
Needle: 'step'
Position: 11
Expected: 11  ✓ PASS

====================================
[Test] File I/O
====================================
Writing to: /tmp/neurx_test_runtime.txt
Content: 'hello world'
write_file() result: ✓ PASS
Reading from: /tmp/neurx_test_runtime.txt
read_file() result: 'hello world'
Expected: 'hello world'  ✓ PASS

====================================
[Test] Atomic Rename (CRITICAL)
====================================
Step 1: Write to temp file
  ✓ /tmp/neurx_test.json.tmp
Step 2: Atomic rename (防止 checkpoint 损坏)
  rename_file() result: ✓ PASS
Step 3: Verify final file exists
  Final file exists: ✓ PASS
  Temp file removed: ✓ PASS
Step 4: Verify content preserved
  Content: '{"step": 100}'
  Expected: '{"step": 100}'  ✓ PASS

====================================
Runtime Unit Tests Complete
====================================
```

---

## C Layer Unit Tests (Optional but Recommended)

**Location**: `/home/shuwen/shuwen/s/src/runtime/tests/`

**test_string.c**:
```c
#include <assert.h>
#include <string.h>

void test_str_len() {
    assert(runtime_str_len("hello") == 5);
    assert(runtime_str_len("") == 0);
    printf("✓ str_len tests passed\n");
}

void test_str_find() {
    assert(runtime_str_find("checkpoint_step", "step") == 11);
    assert(runtime_str_find("test", "xyz") == -1);
    printf("✓ str_find tests passed\n");
}

int main() {
    test_str_len();
    test_str_find();
    return 0;
}
```

**Compile & Run**:
```bash
cd /home/shuwen/shuwen/s/src/runtime/tests
gcc test_string.c -o test_string
./test_string
```

**Why C Layer Tests**:
> "S 程序测试 = compiler + IR + runtime 混在一起。如果失败，不知道是编译器问题、IR 问题、还是 Runtime 问题。底层 Runtime 最好 C 单测。"

---

## Next Steps After Day 1

### Day 2: Round-Trip Test
```bash
cd /home/shuwen/shuwen/neurx
s posttrain/checkpoint/test_roundtrip.s /tmp/test_roundtrip
/tmp/test_roundtrip
# Expected: State → JSON → Disk → JSON → State 完全一致
```

### Day 3: Checkpoint Manager
```bash
make posttrain        # Train to step 100
# Ctrl+C
make posttrain-resume # Continue from step 101
```

---

**Status**: ✅ Ready for Day 1.1 (String Runtime Implementation)  
**Next**: Implement `str_len`, `str_char_at`, `str_find` in `/home/shuwen/shuwen/s/src/runtime.c`
