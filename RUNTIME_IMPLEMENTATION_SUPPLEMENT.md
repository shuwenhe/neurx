# Runtime Implementation - Engineering Supplements

**这是 DAY1_RUNTIME_IMPLEMENTATION.md 的工程级补充说明**

---

## 📋 Complete Function Implementation Reference

### Commit 1: String Runtime (2小时)

#### srt_str_len
```c
// In s/src/runtime/string.c
int srt_str_len(char* s) {
    if (s == NULL) return 0;
    return strlen(s);
}

// In s/src/runtime/runtime.c - S binding
Value* builtin_str_len(Value** args, int argc) {
    if (argc != 1 || args[0]->type != VAL_STRING) {
        return make_int(0);
    }
    return make_int(srt_str_len(args[0]->str_val));
}
```

#### srt_str_char_at
```c
// In s/src/runtime/string.c
char srt_str_char_at(char* str, int index) {
    if (str == NULL) return '\0';
    int len = strlen(str);
    if (index < 0 || index >= len) return '\0';
    return str[index];
}

// In s/src/runtime/runtime.c - S binding
Value* builtin_str_char_at(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_INT) {
        return make_string("");
    }
    
    char ch = srt_str_char_at(args[0]->str_val, args[1]->int_val);
    if (ch == '\0') {
        return make_string("");
    }
    
    char result[2] = {ch, '\0'};
    return make_string(result);
}
```

#### srt_str_find
```c
// In s/src/runtime/string.c
int srt_str_find(char* haystack, char* needle) {
    if (haystack == NULL || needle == NULL) return -1;
    char* pos = strstr(haystack, needle);
    return (pos == NULL) ? -1 : (int)(pos - haystack);
}

// In s/src/runtime/runtime.c - S binding
Value* builtin_str_find(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_STRING) {
        return make_int(-1);
    }
    return make_int(srt_str_find(args[0]->str_val, args[1]->str_val));
}
```

---

### Commit 2: File Runtime (4小时)

#### srt_write_file
```c
// In s/src/runtime/file.c
bool srt_write_file(char* filepath, char* content) {
    if (filepath == NULL || content == NULL) return false;
    
    FILE* fp = fopen(filepath, "wb");
    if (fp == NULL) return false;
    
    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, fp);
    
    fflush(fp);  // CRITICAL: Flush for atomic write
    fclose(fp);
    
    return written == len;
}

// In s/src/runtime/runtime.c - S binding
Value* builtin_write_file(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_STRING) {
        return make_bool(false);
    }
    return make_bool(srt_write_file(args[0]->str_val, args[1]->str_val));
}
```

#### srt_read_file (内存管理重点)
```c
// In s/src/runtime/file.c
char* srt_read_file(char* filepath) {
    if (filepath == NULL) return NULL;
    
    FILE* fp = fopen(filepath, "rb");
    if (fp == NULL) return NULL;
    
    // Get file size
    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    if (size < 0) {
        fclose(fp);
        return NULL;
    }
    
    // OPTION 1 (Recommended): Runtime GC pool
    char* buffer = runtime_alloc(size + 1);  // GC manages lifetime
    
    // OPTION 2 (Temporary): Use malloc if no runtime_alloc yet
    // char* buffer = (char*)malloc(size + 1);
    
    if (buffer == NULL) {
        fclose(fp);
        return NULL;
    }
    
    size_t read_bytes = fread(buffer, 1, size, fp);
    buffer[read_bytes] = '\0';
    fclose(fp);
    
    return buffer;
}

// In s/src/runtime/runtime.c - S binding
Value* builtin_read_file(Value** args, int argc) {
    if (argc != 1 || args[0]->type != VAL_STRING) {
        return make_string("");
    }
    
    char* content = srt_read_file(args[0]->str_val);
    if (content == NULL) {
        return make_string("");
    }
    
    Value* result = make_string(content);  // make_string copies the data
    
    // If using malloc (OPTION 2), free here:
    // free(content);
    
    // If using runtime_alloc (OPTION 1), GC handles it
    
    return result;
}
```

**Memory Management Decision**:
- **First version**: Use runtime_alloc (GC manages memory)
- **Reason**: S language has no mature `free()` mechanism
- **适用场景**: checkpoint, config, logs (short lifetime)
- **Future**: Add `srt_free()` when manual management needed

#### srt_file_exists
```c
// In s/src/runtime/file.c
#include <sys/stat.h>

bool srt_file_exists(char* filepath) {
    if (filepath == NULL) return false;
    struct stat st;
    return stat(filepath, &st) == 0;
}

// In s/src/runtime/runtime.c - S binding
Value* builtin_file_exists(Value** args, int argc) {
    if (argc != 1 || args[0]->type != VAL_STRING) {
        return make_bool(false);
    }
    return make_bool(srt_file_exists(args[0]->str_val));
}
```

---

### Commit 3: Atomic Checkpoint (2小时)

#### srt_atomic_replace (工业级实现)
```c
// In s/src/runtime/file.c
#include <fcntl.h>
#include <unistd.h>
#include <libgen.h>

bool srt_atomic_replace(char* tmp_path, char* target_path) {
    if (tmp_path == NULL || target_path == NULL) return false;
    
    // ═══════════════════════════════════════════════════════════
    // Step 1: fsync temp file (flush data to disk)
    // ═══════════════════════════════════════════════════════════
    int fd = open(tmp_path, O_RDONLY);
    if (fd < 0) return false;
    
    if (fsync(fd) != 0) {
        close(fd);
        return false;
    }
    close(fd);
    
    // ═══════════════════════════════════════════════════════════
    // Step 2: rename (atomic operation on POSIX)
    // ═══════════════════════════════════════════════════════════
    if (rename(tmp_path, target_path) != 0) {
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════
    // Step 3: fsync directory (CRITICAL - ensure metadata persisted)
    // ═══════════════════════════════════════════════════════════
    // 这一步确保目录项真正写入磁盘，防止机器掉电时丢失 metadata
    char* target_copy = strdup(target_path);
    char* dir = dirname(target_copy);
    
    fd = open(dir, O_RDONLY);
    if (fd >= 0) {
        fsync(fd);  // Best effort, don't fail if this fails
        close(fd);
    }
    free(target_copy);
    
    return true;
}

// Alias for backwards compatibility
bool srt_rename_file(char* old_path, char* new_path) {
    return srt_atomic_replace(old_path, new_path);
}

// In s/src/runtime/runtime.c - S binding
Value* builtin_rename_file(Value** args, int argc) {
    if (argc != 2 || args[0]->type != VAL_STRING || args[1]->type != VAL_STRING) {
        return make_bool(false);
    }
    return make_bool(srt_atomic_replace(args[0]->str_val, args[1]->str_val));
}
```

**Why `fsync(directory)` is CRITICAL**:
```
简单 rename():
  checkpoint.json.tmp → checkpoint.json (in memory)
  ↓ [机器掉电]
  ❌ 目录项可能未持久化 → 文件丢失

真正 atomic replace:
  1. fsync(tmp_file)     ← 数据落盘
  2. rename()            ← 原子操作
  3. fsync(directory)    ← 目录项落盘 ✅
  ↓ [机器掉电]
  ✅ 文件完整存在
```

**User Quote**: 
> "这才是真正工业 checkpoint。不同文件系统行为略有差异，fsync(directory) 才能确保持久化。"

---

## 📦 Runtime Registration

After implementing functions, register them in S runtime:

```c
// In s/src/runtime/runtime.c - Initialization function
void init_runtime_builtins() {
    // String functions
    register_builtin("str_len", builtin_str_len);
    register_builtin("str_char_at", builtin_str_char_at);
    register_builtin("str_find", builtin_str_find);
    
    // File functions
    register_builtin("write_file", builtin_write_file);
    register_builtin("read_file", builtin_read_file);
    register_builtin("file_exists", builtin_file_exists);
    register_builtin("rename_file", builtin_rename_file);  // Uses srt_atomic_replace internally
}
```

---

## 🧪 Verification Strategy

### Day 1 Complete Test Suite

```bash
# After all 3 commits
cd /home/shuwen/shuwen/neurx
s posttrain/checkpoint/test_runtime.s /tmp/test_runtime
/tmp/test_runtime
```

**Expected Output**:
```
====================================
Runtime Unit Tests
====================================

[Commit 1: String Runtime]
  str_len("checkpoint_step_000100") → 22        ✓ PASS
  str_char_at("checkpoint", 5) → 'p'            ✓ PASS
  str_find("checkpoint_step", "step") → 11     ✓ PASS

[Commit 2: File Runtime]  
  write_file("/tmp/test.txt", "hello") → true   ✓ PASS
  read_file("/tmp/test.txt") → "hello"          ✓ PASS
  file_exists("/tmp/test.txt") → true           ✓ PASS

[Commit 3: Atomic Checkpoint]
  Step 1: Write temp file                       ✓ PASS
  Step 2: Atomic rename                         ✓ PASS
  Step 3: Verify final exists                   ✓ PASS
  Step 4: Verify temp removed                   ✓ PASS
  Step 5: Verify content preserved              ✓ PASS

====================================
ALL RUNTIME TESTS PASSED ✅
====================================
```

---

## 🎯 Acceptance Criteria (验收标准)

### 不要只看 compile success

**Minimum Requirements**:
- ✅ All 7 functions implemented with `srt_` prefix
- ✅ Runtime structure modular (string.c, file.c)
- ✅ Memory management: runtime_alloc (no user free)
- ✅ Atomic replace: fsync(file) + rename + fsync(dir)
- ✅ All tests in test_runtime.s PASS

### Milestone Achievement

**When Day 1 complete**:
```
NeurX 架构转变

Before:
  Training Code + Some Infrastructure

After:
  ┌────────────────────────────┐
  │   NeurX Training Engine    │
  └────────────────────────────┘
              ↓
  ┌────────────────────────────┐
  │    S Runtime Layer         │
  │  (string, file, atomic)    │
  └────────────────────────────┘
              ↓
  ┌────────────────────────────┐
  │      Operating System      │
  └────────────────────────────┘
```

**User Quote**:
> "这个层次才是 PyTorch / Megatron 这种系统的核心思想。"

---

## 🚀 Next Steps After Day 1

### Day 2: Round-Trip Test
```bash
cd /home/shuwen/shuwen/neurx
s posttrain/checkpoint/test_roundtrip.s /tmp/test_roundtrip
/tmp/test_roundtrip
# Expected: State → JSON → Disk → JSON → State 完全一致
```

### Day 3: Fault-Tolerant Training
```bash
make posttrain        # Train to step 100
# Ctrl+C (kill)
make posttrain-resume # Continue from step 101 ✅
```

**Final Milestone**: kill → restart → resume 真正跑通 🎉

---

**Status**: Ready for Day 1.1 implementation  
**Next**: Implement string.c with srt_* prefix
