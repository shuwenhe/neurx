# CUDA English text Checkpoint recoverEnglish text - English text

## English text

English textDescriptionEnglish text NeurX GPU English texttrainingEnglish textcomplete checkpoint recoverEnglish text, English text CUDA English text, modelweightrecover, optimizeEnglish textstaterecoverEnglish text.

## English text

```
┌─────────────────────────────────────────────────────────────┐
│ Makefile: pretrain-gpu / pretrain-gpu-fresh                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ run-gpu-pretrain-s (Makefile target)                        │
│ - Compiles S launcher (pretrain_gpu.s)                      │
│ - Creates shard list                                         │
│ - Detects checkpoint state                                  │
│ - Sets NEURX_PRETRAIN_RESUME_FROM env var                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ neurx_cuda_train_bridge (CUDA Binary)                       │
│ - Reads NEURX_PRETRAIN_RESUME environment variable          │
│ - Loads checkpoint.state from NEURX_PRETRAIN_RESUME_FROM   │
│ - Restores model weights from checkpoint_step_<N>.f32      │
│ - Resumes optimizer state (Adam params)                     │
│ - Continues training from saved step                        │
│ - Periodically saves new checkpoints                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ checkpoint/NeurX-1.3/                                       │
│ ├── training_state.txt (S launcher metadata)                │
│ ├── checkpoint.state (CUDA bridge checkpoint)               │
│ └── checkpoint_step_<N>.weights.f32 (Model weights)         │
└─────────────────────────────────────────────────────────────┘
```

## fileEnglish text

### 1. S languageEnglish text (scripts/legacy/pretrain_gpu.s)

**English textfunction**:
- `find_latest_checkpoint_weights(dir, step)` - English textweightfile
- `create_cuda_resume_state(file, state, weights)` - English textCUDAEnglish textrecoverstatefile

**pipeline**:
```
Phase 1: English textcheckpointEnglish text
         └─> checkpoint_exists() → English texttraining_state.txt

Phase 2: initializeGPUEnglish text
         └─> English textNVIDIA GPUEnglish text

Phase 3: computerecoverparameter
         └─> find_latest_checkpoint_weights()
             create_cuda_resume_state()

Phase 4: English text
         └─> English textMakefile
             NEURX_PRETRAIN_RESUME
             NEURX_PRETRAIN_RESUME_FROM
```

### 2. Makefile English text (Makefile)

**English text**:
```makefile
NEURX_PRETRAIN_RESUME_FROM = $(CHECKPOINT_DIR)/checkpoint.state
```

**run-gpu-pretrain-s English text**:
- English textcheckpointstatefile
- English textNEURX_PRETRAIN_RESUMEEnglish text (0/1)
- English textNEURX_PRETRAIN_RESUME_FROMpathEnglish textCUDAEnglish text

### 3. CUDA English text (cuda/neurx_cuda_train_bridge.cu)

**English text**:
- `load_resume_state()` - English textcheckpoint.stateEnglish textstate
- `save_training_checkpoint()` - saveEnglish textcheckpoint
- `PairReader::restore()` - recoverdataEnglish text

**English text**:
```cpp
// main() functionEnglish text
ResumeState resume_state;
if (resume && std::filesystem::exists(resume_path)) {
    load_resume_state(resume_path, &resume_state);
    // English textresume_staterecover:
    // - start_step = resume_state.completed_step + 1
    // - h_w (weight) English textresume_state.weights_pathload
    // - reader.restore(resume_state.shard_index, ...)
}
```

## Checkpoint fileEnglish text

### training_state.txt (S English textgenerate)

```
step=1000 docs=5000 shards=3 loss=2.45
```

English text:
- `step` - English texttrainingstepEnglish text
- `docs` - English text
- `shards` - English text
- `loss` - English textlossEnglish text

### checkpoint.state (CUDA English textgenerate)

```
completed_step=1000
pairs_seen=500000
shard_index=3
line_in_shard=150
pending_offset=42
vocab_size=4096
batch_pairs=256
loss=2.45
weights=/path/to/checkpoint_step_1000.weights.f32
```

English text:
- `completed_step` - English texttrainingstepEnglish text
- `pairs_seen` - English text(input,target)English text
- `shard_index` - English text
- `line_in_shard` - English text
- `pending_offset` - English textdataEnglish text
- `vocab_size` - English text
- `batch_pairs` - English text
- `loss` - English textlossEnglish text
- `weights` - weightfilepath

### checkpoint_step_<N>.weights.f32 (CUDA English textgenerate)

English textfile, English text:
- English textmodelweightEnglish textdata
- English text = vocab_size × vocab_size × sizeof(float)
- English text: English text (row-major)

## English text

### S English text Makefile English text

```bash
NEURX_PRETRAIN_RESUME          # recoverEnglish text (0=English texttraining, 1=recover)
NEURX_PRETRAIN_RESUME_FROM     # checkpoint.state filepath
NEURX_PRETRAIN_OUTPUT_DIR      # output/checkpointdirectory
NEURX_PRETRAIN_STEPS           # English texttrainingstepEnglish text
NEURX_PRETRAIN_SAVE_INTERVAL   # saveEnglish text(stepEnglish text)
NEURX_PRETRAIN_LR              # learning rate
NEURX_PRETRAIN_MICRO_BATCH     # English text
NEURX_PRETRAIN_SEQ_LEN         # English text
```

### CUDA English text

```cpp
bool resume = env_int("NEURX_PRETRAIN_RESUME", 1) != 0;
std::string resume_path = env_str("NEURX_PRETRAIN_RESUME_FROM",
                                   output_dir + "/checkpoint.state");
```

## recoverpipeline

### stepEnglish text 1: English textphase (Makefile)

```bash
# English text checkpoint statefile
if [ -f "${CHECKPOINT_DIR}/checkpoint.state" ]; then
    RESUME_FLAG=1
else
    RESUME_FLAG=0
fi

# English text
export NEURX_PRETRAIN_RESUME="${RESUME_FLAG}"
export NEURX_PRETRAIN_RESUME_FROM="${CHECKPOINT_DIR}/checkpoint.state"
```

### stepEnglish text 2: staterecover (CUDA English text)

```cpp
// 1. English textstate
ResumeState resume_state;
load_resume_state(resume_path, &resume_state);

// 2. English textconfiguration
if (resume_state.vocab_size != vocab_size || ...) {
    error("checkpoint configuration mismatch");
}

// 3. loadweight
std::ifstream weights(resume_state.weights_path, std::ios::binary);
weights.read(reinterpret_cast<char*>(h_w.data()),
             h_w.size() * sizeof(float));

// 4. recoverdataEnglish text
reader.restore(resume_state.shard_index,
               resume_state.line_in_shard,
               resume_state.pending_offset);

// 5. English textstepEnglish text
int start_step = resume_state.completed_step + 1;
```

### stepEnglish text 3: trainingrecover

```cpp
// English text start_step starttrainingEnglish text
for (int step = start_step; step <= steps; ++step) {
    // ... trainingEnglish text ...

    if (step % save_interval == 0) {
        // saveEnglish textcheckpoint
        save_training_checkpoint(output_dir, d_w, &h_w,
                                 step, pairs_seen, vocab_size,
                                 batch_pairs, loss, reader);
    }
}
```

## useexample

### English texttraining

```bash
cd /home/shuwen/shuwen/train/neurx

# English textcheckpoint
rm -f checkpoint/NeurX-1.3/checkpoint.state

# starttraining
make pretrain-gpu
```

### recovertraining

```bash
# English textrun(English textcheckpoint)
make pretrain-gpu

# logoutput:
# [pretrain-gpu] checkpoint state found, resuming...
# [pretrain-gpu] launching native CUDA/cuBLAS trainer...
# [cuda-train] checkpoint-restored step=1000 next_step=1001 pairs=500000
```

### English texttraining

```bash
# English textcheckpoint
make pretrain-gpu-fresh

# English text
NEURX_PRETRAIN_RESUME=no make pretrain-gpu
```

## English texttest

### runtestEnglish text

```bash
make test-checkpoint-resume
```

### testpipeline

1. **Phase 1**: English texttraining (10 step)
   - English textcheckpoint
   - starttraining
   - English texttraining_state.txtEnglish textcheckpoint.state

2. **Phase 2**: recovertraining (20 stepEnglish text)
   - loadcheckpoint
   - English text10stepEnglish text
   - runEnglish text20step

3. **English text**:
   - stepEnglish text
   - CheckpointfileEnglish text
   - lossEnglish text
   - English text

### testresult

```
================================================
GPU Checkpoint Resume End-to-End Test
================================================

✓ Fresh training completed (10 steps)
✓ Checkpoint created at: checkpoint/NeurX-1.3-test
✓ Phase 1 final state: step=10, loss=2.45

✓ Resume training completed (10 more steps)
✓ Phase 2 final state: step=20, loss=2.12

✅ ALL TESTS PASSED
```

## English text

### Issue 1: checkpoint.state English textgenerate

**English text**: NEURX_PRETRAIN_RESUME_FROMEnglish textfileEnglish text

**English text**:
1. English textCUDAEnglish textsuccessrun
2. English textoutputdirectoryEnglish text: `ls -la checkpoint/NeurX-1.3/`
3. English textCUDAEnglish textlog: `tail -f artifacts/logs/run_gpu_pretrain_*.log`

### Issue 2: weightloadfailure

**English text**: "invalid checkpoint weights" error

**English text**:
1. English textweightfilecompleteEnglish text: `file checkpoint/NeurX-1.3/checkpoint_step_*.weights.f32`
2. English textfileEnglish text: `ls -lh checkpoint/NeurX-1.3/checkpoint_step_*.weights.f32`
3. English textvocab_sizeEnglish text: `NEURX_CUDA_VOCAB_SIZE=4096 make pretrain-gpu`

### Issue 3: dataEnglish textrecoverEnglish texterror

**English text**: startEnglish texterrorEnglish text

**English text**:
1. English textshard_indexEnglish textsave
2. English textgenerateshard_list.txt: `make run-gpu-pretrain-s`
3. English textstart: `make pretrain-gpu-fresh`

## English text

### Checkpoint English text
- weightfile: ~vocab_size² × 4 bytes
- example (vocab=4096): ~64 MB
- completecheckpoint: ~100 MB (English textmetadata)

### Checkpoint time
- weightsave: ~100-500 ms (English textGPU-CPUEnglish text)
- stateEnglish text: ~1 ms
- English text: English text (<1% trainingtime)

### recommendedEnglish text

```bash
# English textmodel/quicktest
NEURX_PRETRAIN_SAVE_INTERVAL=10

# English texttraining
NEURX_PRETRAIN_SAVE_INTERVAL=1000

# English textdataEnglish text
NEURX_PRETRAIN_SAVE_INTERVAL=10000
```

## English textsystemEnglish text

### English text pretrain_gpu.s English text

✅ SEnglish text:
- English textfilesystemEnglish textcheckpoint
- English texttraining_state.txt
- generatecheckpoint.stateEnglish textCUDAEnglish textuse

### English text Makefile English text

✅ MakefileEnglish text:
- compileSEnglish text
- English textcheckpointstate
- English text
- English textCUDAEnglish text

### English text CUDA English text

✅ CUDAEnglish text:
- loadcheckpoint.state
- recovermodelweight
- recoverdataEnglish text
- English texttrainingEnglish text

## English text

- [ ] supportEnglish textGPUEnglish textcheckpointEnglish textstep
- [ ] English textcheckpointEnglish textmanagement
- [ ] English textcheckpointsave
- [ ] CheckpointEnglish text
- [ ] English textcheckpointEnglish text

## English text

completeEnglish textcheckpointrecoversystemEnglish text:
- ✅ SEnglish text: stateEnglish text
- ✅ MakefileEnglish text: English textmanagement
- ✅ CUDAEnglish text: weightEnglish textstaterecover
- ✅ English texttest: completepipelineEnglish text

systemAllowedEnglish text:
1. savetrainingstate
2. English textloadcheckpoint
3. recovermodelweightEnglish textoptimizeEnglish textstate
4. English texttrainingEnglish textstart
