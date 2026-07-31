# Phase 2B: Training Infrastructure - TODO List

**Last Updated**: 2024-07-31 16:05 UTC  
**Current Focus**: S Runtime Implementation (CRITICAL PATH)  
**Goal**: Fault-Tolerant Training with Save/Load/Resume

**核心洞察**: 
> **现在补的是：训练系统的操作系统层（不是训练策略层）**

---

## ⚡ 3-Day Execution Plan (Critical Path)

**⚠️ 工程级注意点** (详见 RUNTIME_IMPLEMENTATION_SUPPLEMENT.md):
1. **统一 ABI**: 所有函数使用 `srt_` 前缀 (避免命名冲突)
2. **内存管理**: `read_file` 由 Runtime allocator 管理 (用户不用 free)
3. **Atomic Replace**: `fsync(file) + rename + fsync(directory)` (真正工业级)

### Day 1: S Runtime Implementation (分 3 个 Commits)

### Day 1: S Runtime Implementation (分 3 个 Commits)

**不要七个一起写！** 建议分阶段实现和验证。

#### Commit 1: String Runtime (上午 2小时)
**Target**: 实现 JSON decoder 依赖的 3 个核心函数  
**Location**: `/home/shuwen/shuwen/s/src/runtime/string.c`  
**Priority**: P0 (JSON decoder 完全依赖)

**实现清单** (使用 `srt_` 前缀):
1. **srt_str_len** - `strlen()` wrapper
   ```c
   int srt_str_len(char* s);
   ```
2. **srt_str_char_at** - `s[index]` accessor
   ```c
   char srt_str_char_at(char* str, int index);
   ```
3. **srt_str_find** - `strstr()` wrapper (JSON decoder 核心)
   ```c
   int srt_str_find(char* haystack, char* needle);
   ```

**验收标准**:
```bash
cd /home/shuwen/shuwen/neurx
s posttrain/checkpoint/test_runtime.s /tmp/test_runtime
/tmp/test_runtime
# Expected: String API 所有测试 ✓ PASS
```

**User Quote**: "不要一次改 runtime.c 全部功能。先String，再File，再Atomic。"

---

#### Commit 2: File Runtime (上午 2小时 + 下午 2小时)
**Target**: 实现 checkpoint basic I/O  
**Location**: `/home/shuwen/shuwen/s/src/runtime/file.c`  
**Priority**: P0 (checkpoint 基础)

**实现清单**:
1. **srt_write_file** - `fopen/fwrite/fflush/fclose`
   ```c
   bool srt_write_file(char* filepath, char* content);
   ```
2. **srt_read_file** - ⚠️ **Runtime allocator 管理内存**
   ```c
   char* srt_read_file(char* filepath);  // 用户不用 free
   ```
3. **srt_file_exists** - `stat()` syscall
   ```c
   bool srt_file_exists(char* filepath);
   ```

**Memory Management Strategy** (CRITICAL):
- ✅ 第一版: `runtime_alloc()` (GC 管理)
- ❌ 不要: `malloc()` + 用户 `free()` (S 语言没有成熟内存管理)
- 适用: checkpoint, config, logs (短生命周期)
- 未来: 添加 `srt_free()` 当需要手动管理时

**User Quote**: "不要第一版就 malloc + 用户 free。因为 S 语言目前没有成熟内存管理接口。"

**验收标准**:
```bash
s posttrain/checkpoint/test_runtime.s /tmp/test_runtime
/tmp/test_runtime
# Expected: File I/O 所有测试 ✓ PASS
```

---

#### Commit 3: Atomic Checkpoint (下午 2小时)
**Target**: 真正工业级 atomic replace  
**Location**: `/home/shuwen/shuwen/s/src/runtime/file.c`  
**Priority**: P0 (fault-tolerant checkpoint 核心)

**实现清单**:
1. **srt_atomic_replace** - ⚠️ **工业级实现**
   ```c
   bool srt_atomic_replace(char* tmp_path, char* target_path);
   ```

**工业级 Atomic Write Pattern**:
```c
// 简单 rename() 不够 ❌
rename(tmp, target);

// 真正工业级 ✅
1. fsync(tmp_fd)        // Flush file data to disk
2. rename(tmp, target)  // Atomic operation
3. fsync(directory_fd)  // CRITICAL: Ensure metadata persisted
```

**Why `fsync(directory)` CRITICAL**:
- 简单 `rename()`: 目录项可能未持久化 → 机器掉电丢失 metadata
- `fsync(directory)`: 确保目录项真正写入磁盘 → 完整性保障
- 这才是 OpenAI/Anthropic/DeepMind 级别的工业 checkpoint

**User Quote**: 
> "这才是真正工业 checkpoint。不同文件系统行为略有差异，fsync(directory) 才能确保持久化。"

**验收标准** (Test Atomic Write):
```bash
# Simulate crash scenario
write_file("checkpoint.json.tmp", content)
rename_file("checkpoint.json.tmp", "checkpoint.json")  # Atomic!
# [Simulate crash/restart]
assert(file_exists("checkpoint.json"))
assert(read_file("checkpoint.json") == content)  # 完整存在，无损坏
```

**Expected**:
```
[Commit 3: Atomic Checkpoint]
  Step 1: Write temp file                       ✓ PASS
  Step 2: Atomic rename (fsync dir)             ✓ PASS
  Step 3: Verify final exists                   ✓ PASS
  Step 4: Verify temp removed                   ✓ PASS
  Step 5: Verify content preserved              ✓ PASS
```

---

### Day 2: Round-Trip Testing (验收 - 4-6小时)
**Target**: Checkpoint state save/load verification  
**Depends**: Day 1 complete  
**Priority**: P0 (第一个验收 - 证明闭环成立)

**Why This First**: 
> "现在 Encoder → JSON → Decoder 只是编译通过。还没有证明 State → JSON → Disk → JSON → State 完全一致。这是 Checkpoint 最核心的闭环。"

**测试流程**:
```
TrainerState
    ↓
JSON Encode
    ↓
write_file
    ↓
read_file
    ↓
JSON Decode
    ↓
compare (所有字段完全一致)
```

**测试清单**:
- [ ] Run `posttrain/checkpoint/test_roundtrip.s` with runtime support
- [ ] **TrainerState**: Verify all 8 fields
  ```s
  // Input: step=100, epoch=2, global_tokens=256000, best_loss=1.23
  // Flow: struct → JSON → file → read → decode → compare
  // Expected: All values identical
  ```
- [ ] **SchedulerState**: Test schedule types (cosine, linear, constant)
  ```s
  // Critical: compute_learning_rate() must be consistent after restore
  float lr_before = compute_learning_rate(step=50, ...)
  // Save → Load
  float lr_after = compute_learning_rate(step=50, ...)
  // Assert: lr_before == lr_after
  ```
- [ ] **OptimizerState Metadata**: Only test metadata (type, step, dimensions)
  ```s
  // NO tensors yet (Step 3.4)
  type="AdamW", step=100, num_layers=24
  ```
- [ ] Measure JSON size (expect <1KB per state)
- [ ] Test edge cases (negative values, zero, large numbers)

**Acceptance Criteria**:
- ✅ All fields restored with exact values
- ✅ No data loss or type mismatch
- ✅ JSON human-readable and valid
- ✅ File I/O atomic (no corruption on interrupt)

**成功标志**: 
> "Checkpoint 基础闭环成立" → 可以进入 Day 3

---

### Day 3: Checkpoint Manager + First Fault-Tolerant Run (终极验收)
**Target**: 实现第一个真正验收 🎉  
**Depends**: Day 2 complete  
**Priority**: P0 (NeurX 从原型到框架的里程碑)

**Why Simple**: 
> "完成 Round-trip 后再写 Checkpoint Manager。那时候 checkpoint_manager.s 会非常简单。"

**实现** (`posttrain/checkpoint/checkpoint_manager.s`, ~300 lines):

1. **save_checkpoint()** - 简单组合已有模块:
   ```s
   func save_checkpoint(string checkpoint_root, int step, ...) bool {
       // 1. Create directory
       string checkpoint_dir = create_checkpoint_dir(checkpoint_root, step)
       
       // 2. Save trainer state
       string trainer_json = trainer_state_to_json(...)
       write_checkpoint_file(checkpoint_dir + "/trainer_state.json", trainer_json)
       
       // 3. Save scheduler state
       string scheduler_json = scheduler_state_to_json(...)
       write_checkpoint_file(checkpoint_dir + "/scheduler.json", scheduler_json)
       
       // 4. Save optimizer metadata
       string optimizer_json = optimizer_state_to_json(...)
       write_checkpoint_file(checkpoint_dir + "/optimizer_meta.json", optimizer_json)
       
       // 5. Update latest pointer
       write_latest_checkpoint(checkpoint_root, step)
       
       return true
   }
   ```

2. **load_checkpoint()** - 简单组合:
   ```s
   func load_checkpoint(string checkpoint_dir) bool {
       // 1. Read files
       string trainer_json = read_file(checkpoint_dir + "/trainer_state.json")
       
       // 2. Decode (using json_get_xxx)
       int step = json_get_int(trainer_json, "step")
       int epoch = json_get_int(trainer_json, "epoch")
       
       // 3. Restore state
       // trainer_state.step = step
       // trainer_state.epoch = epoch
       
       return true
   }
   ```

3. **resume_training()** - 简单组合:
   ```s
   func resume_training(string checkpoint_root) bool {
       int latest_step = read_latest_checkpoint(checkpoint_root)
       string checkpoint_dir = checkpoint_root + "/step_" + format_step(latest_step)
       return load_checkpoint(checkpoint_dir)
   }
   ```

**CRITICAL VALIDATION** (终极验收):
```bash
# Start training
make posttrain
# Train to step 100, checkpoint saved to checkpoint/step_000100/

# Kill training (Ctrl+C)
# Simulate crash/interrupt

# Resume training
make posttrain-resume

# Verify:
# ✅ Training continues from step 101 (NOT step 1)
# ✅ Loss curve continuous (no jump)
# ✅ No duplicate steps
# ✅ Optimizer state preserved
# ✅ Learning rate schedule consistent
```

**User Quote**: 
> "这一刻，NeurX 才真正拥有 Megatron/verl 类训练系统的核心能力：Fault-tolerant training（容错训练）。"

**成功标志**: 
- ✅ **kill → restart → resume 真正跑通**
- ✅ **Fault-tolerant training 成功** 🎉

---

## 📊 Current System Architecture

```
NeurX Training System (从原型到框架的转折)

Training Loop
│
├── Compute Layer
│   ├── Forward                ✅
│   └── Backward               ✅
│
├── Safety Layer
│   └── Stability              ✅ (gradient clipping, NaN/Inf detection)
│
├── Observability Layer
│   └── Metrics                ✅ (loss, perplexity, accuracy)
│
├── State Layer
│   ├── TrainerState           ✅
│   ├── OptimizerState         ✅
│   └── SchedulerState         ✅
│
├── Persistence Layer
│   ├── JSON Encoder/Decoder   ✅
│   ├── S Runtime              🚧 ← CURRENT (Day 1 - 3 Commits)
│   └── Checkpoint Manager     ⏳ (Day 3)
│
└── Orchestration Layer
    ├── Trainer                ⏳ (Future)
    └── Callbacks              ⏳ (Future)
```

**Day 1 完成后架构转变**:
```
Before:                         After:
Training Code                   ┌─────────────────────┐
    +                           │ NeurX Training Engine│
Some Infrastructure             └──────────┬──────────┘
                                           ↓
                                ┌──────────────────────┐
                                │  S Runtime Layer     │
                                │  (OS abstraction)    │
                                └──────────┬───────────┘
                                           ↓
                                ┌──────────────────────┐
                                │   Operating System   │
                                └──────────────────────┘
```

**User Quote**: 
> "这个层次才是 PyTorch / Megatron 这种系统的核心思想。"

---

## 📁 Runtime 目录结构 (推荐重构)

**当前** (可能):
```
s/src/runtime.c  # 所有函数堆在一起 (7 functions)
```

**推荐** (工程化 - 为未来膨胀做准备):
```
s/src/runtime/
├── runtime.h        # Public API declarations
├── runtime.c        # Core runtime initialization + S bindings
├── string.c         # String functions (srt_str_*)
├── file.c           # File I/O functions (srt_file_*, srt_atomic_replace)
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

**模块职责**:
- `runtime.h`: Public API (所有 `srt_*` 函数声明)
- `runtime.c`: S Value bindings (`builtin_*` 函数)
- `string.c`: Pure C string operations
- `file.c`: Pure C file operations + atomic replace

**User Quote**: 
> "不要继续把所有东西塞进 runtime.c。未来 Runtime 一定会膨胀。"

**C Layer Unit Tests** (建议):
```
s/src/runtime/tests/test_string.c:
  ✓ srt_str_len
  ✓ srt_str_char_at  
  ✓ srt_str_find

s/src/runtime/tests/test_file.c:
  ✓ srt_write_file
  ✓ srt_read_file
  ✓ srt_file_exists
  ✓ srt_atomic_replace
```

**Why C Layer Tests**:
> "S 程序测试 = compiler + IR + runtime 混在一起。如果失败，不知道是编译器问题、IR 问题、还是 Runtime 问题。底层 Runtime 最好 C 单测。"

---

## ✅ Completed (1,479 lines)

### Step 1: Training Stability (100 lines) - DONE ✅
- [x] `posttrain/training/stability.s` - Gradient clipping, NaN/Inf detection
- [x] Compilation verified (4.5KB IR)
- [x] Integration pattern defined (forward → backward → stability check → clip)

### Step 2: Unified Metrics (276 lines) - DONE ✅
- [x] `posttrain/training/metrics.s` - Consolidated 6 fragmented modules
- [x] Compilation verified (9.1KB IR)
- [x] 82% code reduction (1,541 → 276 lines)
- [x] Megatron-style inline metrics display

### Step 3.1: Checkpoint Data Structures (428 lines) - DONE ✅
- [x] `posttrain/checkpoint/state.s` - TrainerState (120 lines)
- [x] `posttrain/checkpoint/optimizer_state.s` - AdamWState (109 lines)
- [x] `posttrain/checkpoint/scheduler_state.s` - SchedulerState (199 lines)
- [x] All compile successfully
- [x] Field-based design (no struct returns)

### Step 3.2: JSON Serialization (675 lines) - DONE ✅
- [x] `posttrain/checkpoint/json_encoder.s` - State → JSON (175 lines)
- [x] `posttrain/checkpoint/json_decoder.s` - JSON → Fields (195 lines)
- [x] `posttrain/checkpoint/file_io.s` - Atomic write/read (154 lines)
- [x] `posttrain/checkpoint/test_roundtrip.s` - Verification test (270 lines)
- [x] All compile successfully
- [x] Atomic write pattern implemented
- [x] Megatron-style checkpoint directory structure

---

## 🚧 In Progress

### ⚠️ Day 1: S Runtime Support (P0 BLOCKER)

**Why This First**: 现在瓶颈不是 S 代码，而是底层 Runtime 支持  
**Impact**: Blocks ALL checkpoint functionality (Round-trip Test → Checkpoint Manager → Fault-tolerant Training)  
**Location**: `/home/shuwen/shuwen/s/src/runtime.c`

#### String Functions (Day 1.1 - 上午)
**Priority Tier 1** (JSON decoder 依赖):
- [ ] `str_len(string s) int` - Get string length
- [ ] `str_find(string haystack, string needle) int` - Find substring position  
- [ ] `str_char_at(string s, int pos) string` - Get character at position

**Priority Tier 2** (补充功能):
- [ ] `str_substring(string s, int start) string` - Extract substring
- [ ] `str_trim(string s) string` - Remove leading/trailing whitespace

#### File I/O Functions (Day 1.2 - 下午)
**All Required** (fault-tolerant checkpoint 必需):
- [ ] `write_file(string filepath, string content) bool` - Write string to file
- [ ] `read_file(string filepath) string` - Read file to string (Runtime allocator 管理内存)
- [ ] `file_exists(string filepath) bool` - Check file existence
- [ ] `rename_file(string old_path, string new_path) bool` - **CRITICAL: Atomic rename**

#### Testing (DO NOT skip - 验收标准)

**验收标准** (不要只 compile success):

**Test 1: String API**
```bash
str_len      ✓ PASS
str_find     ✓ PASS
str_char_at  ✓ PASS
substring    ✓ PASS
```

**Test 2: File I/O**
```bash
write_file   ✓ PASS
read_file    ✓ PASS
file_exists  ✓ PASS
```

**Test 3: Checkpoint Atomic Write** (模拟 crash scenario)
```bash
write tmp    ✓
rename       ✓
[crash]
restart      ✓
verify       ✓ checkpoint.json 完整存在
```

**Run**:
```bash
cd /home/shuwen/shuwen/neurx
s posttrain/checkpoint/test_runtime.s /tmp/test_runtime
/tmp/test_runtime
# Expected: All tests ✓ PASS
```

---

## 📋 Testing Architecture (建议分层)

### Current: test_runtime.s (348 lines)
- ✅ Compiles successfully
- ✅ Covers all runtime functions
- ⏳ Waiting for runtime implementation

### Future: 测试分层 (建议)
```
tests/runtime/
├── test_string.s      # String API tests
├── test_file.s        # File I/O tests
└── test_atomic.s      # Atomic write tests
```

**Reason**: 以后 Runtime 会越来越大:
```
runtime/
├── string
├── file
├── memory
├── thread
└── network
```
测试也需要分层。

### C Layer Unit Tests (重要建议)
**Location**: `/home/shuwen/shuwen/s/src/runtime/tests/`
```
test_string.c
test_file.c
```

**Why**:
> "S 程序测试 = compiler + IR + runtime 混在一起。如果失败，不知道是编译器问题、IR 问题、还是 Runtime 问题。底层 Runtime 最好 C 单测。"

---

## 📋 Next Steps (After Day 1-3)

### Step 3.4: Binary Tensor Serialization (~200 lines)
**Depends**: Day 3 complete  
**Effort**: 1-2 days  
**Priority**: P1

**Problem**: Optimizer tensors too large for JSON
- 0.5B model: ~20MB (manageable in JSON)
- 7B model: ~28GB (JSON explodes)

**File**: `posttrain/checkpoint/tensor_io.s`

**Functions**:
- `save_optimizer_tensors(string filepath, [][]float momentum, [][]float variance) bool`
- `load_optimizer_tensors(string filepath) bool`

**Format** (Phase 1):
- Raw binary: Header (magic, version, dimensions) + contiguous float32 arrays
- Future: Migrate to SafeTensors

---

### Step 4: Callbacks System (~150 lines)
**Depends**: Day 3 complete  
**Effort**: 1 day  
**Priority**: P2

**File**: `posttrain/training/callbacks.s`

**Callback Points**:
- `on_before_step(int step)`
- `on_after_step(int step, float loss)`
- `on_before_save(int step)`
- `on_after_save(int step, string checkpoint_dir)`
- `on_epoch_end(int epoch, float avg_loss)`

---

### Step 5: Unified Trainer Framework (~600 lines)
**Depends**: Steps 1-4 complete  
**Effort**: 2-3 days  
**Priority**: P2

**File**: `posttrain/training/trainer.s`

**Functions**:
- `init_trainer(TrainerConfig config)`
- `train(int num_epochs)` - Main training loop
- `train_step(int step, []string batch) float`
- `evaluate(string eval_data_path) float`
- `save_checkpoint_if_needed(int step)`

---

### Step 6: Evaluation Module (~400 lines)
**Depends**: Step 5 complete  
**Effort**: 2 days  
**Priority**: P2

**File**: `posttrain/eval/evaluator.s`

**Functions**:
- `evaluate_model(string eval_data_path) EvalMetrics`
- `compute_perplexity([]float losses) float`
- `compute_accuracy([]int predictions, []int labels) float`

---

## 📊 Progress Tracking

### Lines of Code (Pure S)

| Component | Lines | Status |
|-----------|-------|--------|
| Stability | 100 | ✅ Complete |
| Metrics | 276 | ✅ Complete |
| State Structs | 428 | ✅ Complete |
| JSON Serialization | 675 | ✅ Complete |
| test_runtime.s | 348 | ✅ Created |
| **Subtotal** | **1,827** | **58%** |
| S Runtime (C code) | N/A | 🚧 Day 1 |
| Checkpoint Manager | ~300 | ⏳ Day 3 |
| Binary Tensor I/O | ~200 | ⏳ P1 |
| Callbacks | ~150 | ⏳ P2 |
| Trainer Framework | ~600 | ⏳ P2 |
| Evaluation | ~400 | ⏳ P2 |
| **Total Estimated** | **~3,477** | - |

### Timeline (Updated - 3-Day Critical Path)

| Milestone | Target | Status | Blocker |
|-----------|--------|--------|---------|
| **Day 1.1: String Runtime** | **2024-08-01 AM** | **🚧 P0** | None |
| **Day 1.2: File Runtime** | **2024-08-01 PM** | **🚧 P0** | Day 1.1 |
| **Day 2: Round-Trip Test** | **2024-08-02** | **⏳ P0** | Day 1 |
| **Day 3: Fault-Tolerant Training** | **2024-08-03** | **⏳ P0** | Day 2 |
| Step 3.4: Binary Tensor I/O | 2024-08-04 | ⏳ P1 | Day 3 |
| Step 4: Callbacks | 2024-08-05 | ⏳ P2 | Day 3 |
| Step 5: Trainer Framework | 2024-08-08 | ⏳ P2 | Day 3 |
| Step 6: Evaluation | 2024-08-10 | ⏳ P2 | Step 5 |
| **Phase 2B Complete** | **2024-08-10** | **⏳ On Track** | - |

**Critical Path**: Day 1.1 → Day 1.2 → Day 2 → Day 3 (连续依赖)  
**Parallel Work**: Steps 4-6 can proceed after Day 3

---

## 🎯 Success Criteria (Phase 2B)

### Day 1 Acceptance (不要只 compile success)

**验收命令**:
```bash
cd /home/shuwen/shuwen/neurx
make runtime-test  # Or: s posttrain/checkpoint/test_runtime.s /tmp/test && /tmp/test
```

**Expected Output** (分 3 个 Commit 验证):
```
====================================
Runtime Unit Tests
====================================

[Commit 1: String Runtime]
  srt_str_len("checkpoint_step_000100") → 22        ✓ PASS
  srt_str_char_at("checkpoint", 5) → 'p'            ✓ PASS
  srt_str_find("checkpoint_step", "step") → 11     ✓ PASS

[Commit 2: File Runtime]  
  srt_write_file("/tmp/test.txt", "hello") → true   ✓ PASS
  srt_read_file("/tmp/test.txt") → "hello"          ✓ PASS
  srt_file_exists("/tmp/test.txt") → true           ✓ PASS

[Commit 3: Atomic Checkpoint]
  Step 1: Write temp file                           ✓ PASS
  Step 2: fsync(file) → rename → fsync(dir)         ✓ PASS
  Step 3: Verify final exists                       ✓ PASS
  Step 4: Verify temp removed                       ✓ PASS
  Step 5: Verify content preserved                  ✓ PASS

====================================
ALL RUNTIME TESTS PASSED ✅
====================================
```

**User Quote**:
> "下一步验收标准：不要看代码行数。只看运行 make runtime-test 得到 ALL RUNTIME TESTS PASSED。"

---

### Functional Requirements
- [x] Training stability (gradient clipping, NaN detection)
- [x] Comprehensive metrics (loss, perplexity, accuracy)
- [ ] **Fault-tolerant checkpointing** (kill → restart → resume) ⚠️ **CRITICAL PATH (Day 3)**
- [ ] Extensible callbacks (profiling, logging)
- [ ] Unified trainer interface
- [ ] Evaluation framework

### Non-Functional Requirements
- [x] Pure S language (no Python/Shell)
- [x] Industrial patterns (Megatron, verl)
- [ ] Tested on Qwen2.5-0.5B model
- [ ] Documented code and architecture

### Integration Test (Day 3 Validation)
```bash
# Start training
make posttrain

# Kill after 100 steps (Ctrl+C)
# Verify checkpoint saved to checkpoint/step_000100/

# Resume training
make posttrain-resume

# Verify:
# - Training continues from step 100
# - Loss curve continuous (no jump)
# - No duplicate steps
# - Optimizer state preserved
```

---

## 🔄 Dependencies Graph

```
Day 1.1: String Runtime (str_len, str_find, str_char_at)
    ↓
Day 1.2: File Runtime (write_file, read_file, file_exists, rename_file)
    ↓
Day 2: Round-Trip Test (State → JSON → Disk → JSON → State 闭环验证)
    ↓
Day 3: Checkpoint Manager (save/load/resume)
    ↓
Day 3: VALIDATION (kill → restart → resume 🎉)
    ↓
Step 3.4: Binary Tensor I/O (parallel)
    ↓
Step 4: Callbacks (parallel)
    ↓
Step 5: Trainer Framework
    ↓
Step 6: Evaluation
    ↓
Phase 2B Complete ✅
```

---

## 🐛 Known Issues & Blockers

### S Compiler Bug #1: Array Return Types (CRITICAL)
**Status**: DOCUMENTED (not fixed)  
**Impact**: Cannot return `[]string`, `[]int`, `[]float` from functions  
**Workaround**: Avoid array returns, use alternatives  
**Files Affected**: `posttrain/checkpoint/file_io.s` - Removed `list_directory()`

---

## 📝 Key Insights

### 1. 操作系统层 vs 策略层

**当前补齐: 训练系统的操作系统层**
```
✅ Stability (safety)
✅ Metrics (observability)
✅ State Management (persistence)
✅ Serialization (I/O)
🚧 Runtime (system calls)
⏳ Checkpoint (fault tolerance)
```

**暂不实现: 训练策略层**
```
❌ PPO
❌ GRPO
❌ Reward Manager
❌ Rollout Worker
```

**User Quote**: 
> "现在不要再增加 PPO, GRPO, Reward Manager, Rollout Worker。因为这些都是训练策略层。你现在补的是：训练系统的操作系统层。S Runtime 完成 + Checkpoint Resume 跑通后，NeurX 才真正拥有类似 Megatron / verl 的基础能力。"

### 2. 分层测试的重要性

**S 层测试**: `test_runtime.s`
- 测试 compiler + IR + runtime 整体
- 用于集成验证

**C 层测试**: `runtime/tests/test_*.c`
- 隔离测试 runtime functions
- 用于单元验证

**Why Both**: 
> "S 程序测试 = compiler + IR + runtime 混在一起。如果失败，不知道是编译器问题、IR 问题、还是 Runtime 问题。底层 Runtime 最好 C 单测。"

### 3. Atomic Write 的关键性

**Pattern**:
```
1. write_file("checkpoint.json.tmp", content)
2. fflush() / fsync()
3. rename("checkpoint.json.tmp", "checkpoint.json")  // Atomic!
```

**Why Critical**:
- 机器掉电时，rename 要么完成要么不完成（原子操作）
- 不会出现半写状态的 `checkpoint.json`
- 避免 checkpoint 损坏导致训练无法恢复

**User Quote**: 
> "rename_file 非常重要。因为 atomic rename 是防止训练中断导致 checkpoint 损坏的关键。"

---

## 🎓 Architecture Evolution

### Phase 2A: Educational SFT Framework
```
Forward → Backward → LoRA → AdamW → Save Adapter
```
**Focus**: 证明 SFT 训练可行

### Phase 2B: Industrial Training Infrastructure (CURRENT)
```
Compute → Safety → Observability → State → Persistence → Orchestration
```
**Focus**: 补齐操作系统层，实现 fault-tolerant training

### Phase 2C: RL Training Framework (FUTURE)
```
Rollout → Reward → PPO/GRPO → Policy Update → KL Divergence
```
**Focus**: 训练策略层（需要 Phase 2B 完成后才能进行）

---

**Last Updated**: 2024-07-31 16:05 UTC  
**Next Action**: Day 1.1 - 实现 S Runtime String API (str_len, str_char_at, str_find)  
**Maintainer**: NeurX Development Team
