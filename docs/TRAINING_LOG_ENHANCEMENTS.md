# traininglogEnglish textimplementationEnglish text

## English text
English text NeurX English texttrainingEnglish texttraininglogEnglish text, English text, English textinformationEnglish textuseEnglish text.

## English textcontent

### 1. English textextension
**file**: `pretrain/pretraining_pipeline.s`

English text `pretrain_state` English text `performance` English text:

```s
struct performance {
    float tokens_per_second          // English text
    float gpu_memory_utilization    // GPUEnglish text (GB)
    float gpu_compute_utilization   // GPUcomputeEnglish text
    float communication_overhead_pct // English text
    float gradient_norm              // gradientEnglish text ⭐ NEW
    float forward_time_ms           // Forward pass English text (English text) ⭐ NEW
    float backward_time_ms          // Backward pass English text (English text) ⭐ NEW
    float optimizer_time_ms         // Optimizer step English text (English text) ⭐ NEW
    int samples_per_step            // English textstepEnglish text ⭐ NEW
}
```

### 2. trainingstepEnglish text
**function**: `train_step()`

#### English textGPUEnglish text
```s
# English textGPUEnglish textuseEnglish text(English text10stepEnglish text, English text)
if state.current_step % 10 == 0:
    float gpu_mem_gb = get_gpu_memory_usage() / 1024.0
    state.performance.gpu_memory_utilization = gpu_mem_gb
```

#### gradientEnglish textcompute
```s
# English textGradient Accumulation & Updatephase
float grad_norm = clip_grad_norm_(model.parameters(), cfg.max_grad_norm)
state.performance.gradient_norm = grad_norm
```

#### English text
```s
# English textphaseEnglish text(English text)
state.performance.forward_time_ms = timer.get_elapsed("forward") * 1000.0
state.performance.backward_time_ms = timer.get_elapsed("backward") * 1000.0
state.performance.optimizer_time_ms = timer.get_elapsed("optimizer") * 1000.0
```

### 3. logfunctionEnglish text
**function**: `log_training_progress()`

English textlogEnglish text, English text10English text:

#### English text: English texttrainingEnglish text
```
[Step     430/500000] Loss:   2.8100 | LR: 2.00e-04 | GradNorm:   4.28 | Tokens:    110,080
```
- English textstepEnglish text / English textstepEnglish text
- lossEnglish text
- learning rate
- gradientEnglish text
- English texttokensEnglish text

#### English text: English text
```
         Throughput: 18500 tok/s | Samples:  430 | Forward: 32.0ms | Backward: 48.0ms | Optimizer:  6.0ms | GPU Mem: 18.4GB
```
- English text(tokens/English text)
- English text
- Forward passEnglish text
- Backward passEnglish text
- Optimizer stepEnglish text
- GPUEnglish textuse

#### English text: English texttimeinformation
```
         Task:    CLM | RunLoss:   2.7850 | Elapsed:    2m 15s | ETA:   45d 12h
```
- English text
- English textloss
- English texttime
- English texttime

### 4. helperfunctionEnglish text
**function**: `get_gpu_memory_usage()`

```s
func get_gpu_memory_usage() -> float {
    """
    English textGPUEnglish textuseEnglish text(English text: MB)
    English textfloatEnglish text, English textuseEnglish textGPUEnglish text(MB)
    example: English text19353.6, English text19.4GB
    """
    float gpu_mem_mb = 18400.0  // exampleEnglish text: 18.4GB = 18400MB
    return gpu_mem_mb
}
```

**English text**: English textexampleimplementation, English textactualGPUframework(PyTorch CUDA, TensorFlowEnglish text)English textimplementation.

## examplelogoutput

### stepEnglish text 430 English textcompletelog
```
[Step     430/500000] Loss:   2.8100 | LR: 2.00e-04 | GradNorm:   4.28 | Tokens:    110,080
         Throughput: 18500 tok/s | Samples:  430 | Forward: 32.0ms | Backward: 48.0ms | Optimizer:  6.0ms | GPU Mem: 18.4GB
         Task:    CLM | RunLoss:   2.7850 | Elapsed:    2m 15s | ETA:   45d 12h
```

## English textexplanation

| English text | English text | explanation | example |
|------|------|------|------|
| step | - | English texttrainingstepEnglish text | 430 |
| loss | - | English textstepEnglish textlossEnglish text | 2.81 |
| lr | - | English textlearning rate | 2e-4 |
| GradNorm | - | gradientEnglish text(gradientEnglish textL2English text) | 4.28 |
| Tokens | - | English texttokensEnglish text | 110,080 |
| Throughput | tokens/s | English text, English texttokensEnglish text | 18,500 |
| Samples | - | English textstepEnglish text | 430 |
| Forward | ms | Forward passEnglish texttime | 32.0 |
| Backward | ms | Backward passEnglish texttime | 48.0 |
| Optimizer | ms | Optimizer stepEnglish texttime | 6.0 |
| GPU Mem | GB | GPUEnglish textuseEnglish text | 18.4 |
| Task | - | English text(CLM/MLM/PreLM) | CLM |
| RunLoss | - | English textlossEnglish text | 2.785 |
| Elapsed | - | English texttrainingstartEnglish texttime | 2m 15s |
| ETA | - | English texttime | 45d 12h |

## implementationEnglish text

✅ **English text**: GPUEnglish text10stepEnglish text, English text
✅ **English text**: English textforward, backwardEnglish textoptimizerstepEnglish text
✅ **gradientmonitoring**: English textgradientEnglish textgradientEnglish text/English text
✅ **English textlog**: English text, informationEnglish text
✅ **English textextension**: English text, English text

## English text

1. **GPUEnglish textqueryimplementation**: English textactualuseEnglish textframework(PyTorch/TensorFlow)implementation `get_gpu_memory_usage()`
2. **English texttrainingEnglish text**: English textAll-ReduceEnglish texttime, English text
3. **English text**: English texttrainingphaseEnglish text
4. **English text**: English textlogEnglish textsaveEnglish textfileEnglish textTensorBoardEnglish text
5. **English text**: English textgradientEnglish text, lossEnglish texttrainingEnglish text

## fileEnglish textstatistics

- **English textfile**: 1English text (`pretrain/pretraining_pipeline.s`)
- **English textfunction**: 1English text (`get_gpu_memory_usage()`)
- **English textfunction**: 2English text (`log_training_progress()`, `train_step()`)
- **English text**: 5English text (English textperformanceEnglish text)
- **English text**: English text150English text

## testEnglish text

1. **English texttest**: English textcomputeEnglish text
2. **English texttest**: English textcompletetrainingEnglish textlogoutputEnglish text
3. **English texttest**: English textlogEnglish texttrainingEnglish text
4. **English texttest**: English textGPU/English text

---

**English texttime**: 2025English text1English text
**English textfile**: `/home/shuwen/shuwen/train/neurx/pretrain/pretraining_pipeline.s`
