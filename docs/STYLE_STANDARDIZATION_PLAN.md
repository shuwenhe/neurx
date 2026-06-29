# S Language Code Style Standardization - Execution Plan

**Objective**: Standardize all S code in NeurX to follow Go-style syntax
**Target**: All enterprise modules (Priority 1-2)

## Current Issues

### Issue 1: Structure Definition Syntax
```
WRONG (current in new files):
structure flash_attention_config {
    block_size_q: int
    block_size_kv: int
}

CORRECT (Go-style standard):
struct flash_attention_config {
    int block_size_q
    int block_size_kv
}
```

### Issue 2: Function Definition Syntax
```
WRONG:
fn new_flash_attention_config(): flash_attention_config {

CORRECT:
func new_flash_attention_config() flash_attention_config {
```

### Issue 3: Variable Declaration Syntax
```
WRONG:
var state: flash_attention_state

CORRECT:
flash_attention_state state
```

### Issue 4: Return Type Syntax
```
WRONG:
): (vector, vector, vector) {

CORRECT:
) (vector, vector, vector) {
```

## Files to Fix (Priority Order)

| # | File | Lines | Status |
|---|------|-------|--------|
| 1 | compute/flash_attention.s | 800 | PENDING |
| 2 | train/mixed_precision.s | 700 | PENDING |
| 3 | distributed/fault_recovery.s | 850 | PENDING |
| 4 | monitoring/distributed_metrics.s | 750 | PENDING |
| 5 | quantization/quantizer.s | 650 | PENDING |
| 6 | bin/train_enterprise_2t.s | 800 | PENDING |

## Transformation Rules

### Rule 1: Structures
- Replace: `structure NAME {` → `struct NAME {`
- Replace: `FIELD: TYPE` → `TYPE FIELD`
- Pattern: `[a-z_]+: [a-z\[\]]+` → `TYPE NAME`

### Rule 2: Functions  
- Replace: `fn ` → `func `
- Replace: `): RETURN_TYPE {` → `) RETURN_TYPE {`
- Replace: `): (TYPE1, TYPE2) {` → `) (TYPE1, TYPE2) {`

### Rule 3: Variables in Functions
- Replace: `var NAME: TYPE = value` → `TYPE NAME = value`
- Replace: `var NAME: TYPE` → `TYPE NAME`

### Rule 4: Type Annotations in Parameters
- Already correct: `name: TYPE` format in parameters (keep as is)
- For local vars: convert to prefix style

## Transformation Examples

### Before (Wrong)
```s
structure tensor_parallel_config {
    tp_degree: int
    tp_rank: int
    tp_group: vector
}

fn new_tensor_parallel_config(degree: int): tensor_parallel_config {
    var config: tensor_parallel_config
    config.tp_degree = degree
    return config
}
```

### After (Correct)
```s
struct tensor_parallel_config {
    int tp_degree
    int tp_rank
    vector tp_group
}

func new_tensor_parallel_config(int degree) tensor_parallel_config {
    tensor_parallel_config config
    config.tp_degree = degree
    return config
}
```

## Execution Steps

1. ✅ Identify all affected files
2. ⏳ Transform structure definitions
3. ⏳ Transform function signatures
4. ⏳ Transform variable declarations
5. ⏳ Verify consistency
6. ⏳ Document changes

## Status Tracking

- Total files: 6
- Files fixed: 0/6
- Completion: 0%

Start with compute/flash_attention.s next...
