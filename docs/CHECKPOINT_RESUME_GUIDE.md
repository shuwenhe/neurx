# English textconfigurationexplanation

## English text
`make pretrain` English textsupportEnglish text, trainingEnglish textmodelEnglish text `/home/shuwen/shuwen/train/neurx/artifacts/checkpoints` directoryEnglish text.

## English text

### 1. Makefile English text
- **outputdirectory**: `$(CURDIR_UNIX)/artifacts/checkpoints/gpt_large_pretrain` → `$(CURDIR_UNIX)/artifacts/checkpoints`
- **English text**: English text `NEURX_PRETRAIN_RESUME=1` English text
- **English text**: English text `run_large_pretrain.sh` English text `run_cuda_pretrain.sh`

### 2. run_large_pretrain.sh English text
- ✅ English textcheckpointEnglish text
- ✅ English text `latest_checkpoint.txt` recovertraining
- ✅ English text `resume_state.json` recovertrainingstate
- ✅ English text `NEURX_PRETRAIN_CHECKPOINT_PATH` English textrecoverEnglish text
- ✅ English text `NEURX_PRETRAIN_RESUME_STATE_FILE` English textrecoverstate

### 3. minimal_train.s English text
- ✅ English text `output_dir` English textsupport
- ✅ English text `save_interval` parameterconfiguration(default100)
- ✅ trainingEnglish textsavecheckpointEnglish text:
  - `final_model.neurx` - English textmodel
  - `best_model.neurx` - English textmodel(English text)
  - `latest_checkpoint.txt` - English textcheckpointpath
  - `resume_state.json` - trainingstateEnglish text

## outputdirectoryEnglish text

```
artifacts/checkpoints/
├── final_model.neurx              # English textmodelcheckpoint
├── best_model.neurx               # English textmodel(symlinkEnglish textfinal_model.neurx)
├── latest_checkpoint.txt           # English textcheckpointpath
├── resume_state.json               # recoverstate(JSONEnglish text)
└── checkpoint_info.json            # modelconfigurationinformation(English text)
```

## useEnglish text

### English texttraining
```bash
cd /home/shuwen/shuwen/train/neurx
make pretrain
```

trainingEnglish text:
1. English textoutputdirectory `artifacts/checkpoints`
2. English textcheckpoint, English textstarttraining
3. English textsavemodelEnglish text `artifacts/checkpoints/final_model.neurx`

### English text
```bash
# English textrunmakeEnglish text, English textcheckpointEnglish textrecover
cd /home/shuwen/shuwen/train/neurx
make pretrain
```

English text:
1. English text `artifacts/checkpoints/latest_checkpoint.txt` English textcheckpointpath
2. English text `artifacts/checkpoints/resume_state.json` recovertrainingstate
3. English texttraining

### English text(English textstart)
```bash
cd /home/shuwen/shuwen/train/neurx
NEURX_PRETRAIN_RESUME=0 make pretrain
```

## English textconfiguration

| English text | defaultEnglish text | explanation |
|------|--------|------|
| `NEURX_PRETRAIN_OUTPUT_DIR` | `artifacts/checkpoints` | modeloutputdirectory |
| `NEURX_PRETRAIN_RESUME` | `1` | English text(1=English text, 0=English text) |
| `NEURX_PRETRAIN_SAVE_INTERVAL` | `100` | checkpointsaveEnglish text(stepEnglish text) |
| `NEURX_PRETRAIN_CHECKPOINT_PATH` | English text | English textrecoverEnglish textcheckpointpath |
| `NEURX_PRETRAIN_RESUME_STATE_FILE` | English text | recoverstatefilepath |

## checkpointinformationEnglish text

### resume_state.json
```json
{
  "step": 430,
  "docs_seen": 2500,
  "tokens_seen": 320000,
  "loss": 2.814500,
  "last_shard": "/path/to/shard_00042.jsonl"
}
```

### latest_checkpoint.txt
```
/home/shuwen/shuwen/train/neurx/artifacts/checkpoints/final_model.neurx
```

## English textexample

### English text1: English texttraining(1000step, 100stepEnglish text)
```bash
make pretrain NEURX_PRETRAIN_STEPS=1000 NEURX_PRETRAIN_SAVE_INTERVAL=100
# output: artifacts/checkpoints/final_model.neurx
```

### English text2: English text
```bash
# English text(Ctrl+C)English text, modelEnglish textsave:
# - artifacts/checkpoints/final_model.neurx
# - artifacts/checkpoints/resume_state.json
# - artifacts/checkpoints/latest_checkpoint.txt

# English textrunmake pretrain, English textrecover
make pretrain
# English textlatest_checkpoint.txtEnglish textcheckpointEnglish texttraining
```

### English text3: English texttrainingrecoverinformation
```bash
cat artifacts/checkpoints/latest_checkpoint.txt
cat artifacts/checkpoints/resume_state.json
```

## English text

### English textpipeline
1. **run_large_pretrain.sh** English text `latest_checkpoint.txt` English text
2. English textcheckpointfileEnglish text, English text `NEURX_PRETRAIN_CHECKPOINT_PATH`
3. English text `resume_state.json`, English text `NEURX_PRETRAIN_RESUME_STATE_FILE`
4. ScompileEnglish texttrainingEnglish text
5. minimal_train.s English texttrainingEnglish textsaveEnglish textcheckpoint

### checkpointsaveEnglish text
- **final_model.neurx**: English texttrainingEnglish text(English textweight)
- **best_model.neurx**: English textbestEnglish text(English textfinal_model)
- **latest_checkpoint.txt**: English textcheckpointEnglish textcompletepath
- **resume_state.json**: English texttrainingEnglish textdata(stepEnglish text, English text, lossEnglish text)

## English text

### English text: English textrecovercheckpoint
**English text**:
1. English text `latest_checkpoint.txt` English text:
   ```bash
   cat artifacts/checkpoints/latest_checkpoint.txt
   ```
2. English textfileEnglish text:
   ```bash
   ls -lah artifacts/checkpoints/
   ```

### English text: English textstarttraining
**English text**:
```bash
# English textcheckpoint
rm -f artifacts/checkpoints/latest_checkpoint.txt
rm -f artifacts/checkpoints/resume_state.json
# English textstarttraining
make pretrain
```

### English text: checkpointfileEnglish text
**English text**:
English textmodelfile `final_model.neurx` English text `latest_checkpoint.txt` English text:
```bash
# English textcheckpointEnglish text
rm -f artifacts/checkpoints/latest_checkpoint.txt
rm -f artifacts/checkpoints/resume_state.json
# English textstart
make pretrain
```

---

# GPU English texttrainingEnglish text (GPU Pretrain Checkpoint Resume)

## English text

NeurX GPUEnglish texttrainingEnglish textsupportcompleteEnglish text.trainingstatesaveEnglish text `checkpoint/NeurX-1.3/training_state.txt`, English textAllowedEnglish textsaveEnglish textstepEnglish texttraining.

## GPU English texttrainingEnglish text

### 1. English textrecoverEnglish text(recommended)- Auto Resume (Default)

```bash
# English texttraining - English textstepEnglish text0start
make pretrain-gpu

# English text - English textcheckpointEnglish textrecover
make pretrain-gpu
```

**English text**:
- English text `checkpoint/NeurX-1.3/training_state.txt`
- English text, English textsaveEnglish textstepEnglish text
- English text, English textstepEnglish text0startEnglish texttraining
- English text: `NEURX_PRETRAIN_RESUME=auto`(default)

### 2. English textrecoverEnglish text - Force Resume

```bash
NEURX_PRETRAIN_RESUME=yes make pretrain-gpu
```

**English textcheckpointrecover, English text**

### 3. English texttrainingEnglish text - Fresh Start

```bash
make pretrain-gpu-fresh
```

English textuseEnglish text:

```bash
NEURX_PRETRAIN_RESUME=no make pretrain-gpu
```

**English textcheckpointEnglish textstepEnglish text0startEnglish texttraining**

### 4. English textrecoverEnglish text - Explicit Resume

```bash
make pretrain-gpu-resume
```

**English text `make pretrain-gpu`, English text**

## GPU English texttraining Checkpoint English text

```
checkpoint/NeurX-1.3/
├── training_state.txt      # trainingstate(stepEnglish text, English text, English text, loss)
├── transformer_v2.ckpt     # modelweightcheckpoint
├── NeurX-1.3.neurx         # modelEnglish textdata
└── ...                     # English textcheckpointfile
```

### training_state.txt English text

```
step=1000 docs=5000 shards=3 loss=2.45
```

**English textexplanation**:
- `step`: English texttrainingstepEnglish text
- `docs`: English text
- `shards`: English textdataEnglish text
- `loss`: English textlossEnglish text

## GPU English texttrainingEnglish text

| English text | explanation | defaultEnglish text | English text |
|------|------|--------|--------|
| `NEURX_PRETRAIN_RESUME` | recoverEnglish text | `auto` | `auto` / `yes` / `no` |
| `NEURX_PRETRAIN_OUTPUT_DIR` | checkpointsavedirectory | `checkpoint/NeurX-1.3` | English textpath |
| `NEURX_PRETRAIN_STEPS` | English texttrainingstepEnglish text | `1000000000` | English text |
| `NEURX_NUM_GPUS` | GPUcount | English text | English text (1-8) |

## advancedEnglish text (Advanced Usage)

### English textcheckpointdirectory

```bash
NEURX_PRETRAIN_OUTPUT_DIR=/custom/checkpoint/path make pretrain-gpu
```

### English texttrainingstepEnglish textrecover

```bash
NEURX_PRETRAIN_STEPS=10000 NEURX_PRETRAIN_RESUME=yes make pretrain-gpu
```

### English textGPUtrainingEnglish textrecover

```bash
NEURX_NUM_GPUS=4 make pretrain-gpu
```

### English textcheckpointstate

```bash
cat checkpoint/NeurX-1.3/training_state.txt
```

### English textcheckpointstate(advanced)

```bash
# English texttraining_state.txt(English textuse)
echo "step=5000 docs=25000 shards=15 loss=2.10" > checkpoint/NeurX-1.3/training_state.txt
```

## GPU English texttrainingEnglish textexample

### English text1: English textGPUEnglish texttraining

```bash
cd /home/shuwen/shuwen/train/neurx
make pretrain-gpu

# logoutput:
# [Phase 1] Checking for existing checkpoint...
# [Phase 1] No existing checkpoint found, starting fresh training
# [Phase 2] Setting up GPU environment
# [Phase 3] Starting training from step 0
```

### English text2: English textrecover

```bash
# trainingEnglish text(English text1000step)
# English text Ctrl+C English text

# English textcheckpointstate
cat checkpoint/NeurX-1.3/training_state.txt
# output: step=1000 docs=5000 shards=3 loss=2.45

# English textrun - English textrecover
make pretrain-gpu
# logoutput:
# [Phase 1] Existing checkpoint found
# [Phase 1] Loaded state: step=1000 docs=5000 shards=3 loss=2.45
# [Phase 3] Starting training from step 1000
```

### English text3: English textcheckpointstart

```bash
# English textcheckpointEnglish textstart
make pretrain-gpu-fresh

# English text:
NEURX_PRETRAIN_RESUME=no make pretrain-gpu
```

### English text4: English textGPUEnglish textrecovertraining

```bash
# English texttrainingEnglish text4English textGPUEnglish text
NEURX_NUM_GPUS=4 make pretrain-gpu

# English text, English text4English textGPUEnglish textrecover
NEURX_NUM_GPUS=4 make pretrain-gpu
```

## logEnglish textmonitoring

### English texttraininglog

```bash
# English textlog
tail -f artifacts/logs/pretrain_gpu_*.log

# English textlog
ls -lh artifacts/logs/pretrain_gpu_*.log

# searchEnglish textinformation
grep "checkpoint" artifacts/logs/pretrain_gpu_*.log
grep "resume" artifacts/logs/pretrain_gpu_*.log
```

### English textmonitoringtrainingstate

```bash
# English textstate
watch -n 1 'cat checkpoint/NeurX-1.3/training_state.txt'

# English textusetail -fEnglish textmonitoring
tail -f checkpoint/NeurX-1.3/training_state.txt
```

## English text

### English text1: English textcheckpoint
**English text**: English text "No existing checkpoint found" English textrecover

**English text**:
```bash
# English textdirectoryEnglish text
ls -la checkpoint/NeurX-1.3/

# English texttraining_state.txt
cat checkpoint/NeurX-1.3/training_state.txt

# English textfileEnglish text, English textstart
make pretrain-gpu-fresh
```

### English text2: checkpointEnglish text
**English text**: recoverfailureEnglish textparseerror

**English text**:
```bash
# English textcheckpoint
cp checkpoint/NeurX-1.3/training_state.txt checkpoint/NeurX-1.3/training_state.txt.bak

# English textcheckpointstart
make pretrain-gpu-fresh
```

### English text3: GPUEnglish text
**English text**: CUDAerrorEnglish textGPUEnglish textfailure

**English text**:
```bash
# English textGPU
nvidia-smi

# English textGPUcountEnglish text0(CPUEnglish text)
NEURX_NUM_GPUS=0 make pretrain-gpu

# English textuseCPUEnglish texttraining
make pretrain
```

### English text4: English textconfiguration

**English text**: English textcheckpointdirectory
```bash
# English textA: useEnglish textoutputdirectory
NEURX_PRETRAIN_OUTPUT_DIR=checkpoint/NeurX-1.3-v2 make pretrain-gpu

# English textB: English textcheckpoint
mv checkpoint/NeurX-1.3 checkpoint/NeurX-1.3-prod
make pretrain-gpu-fresh
```

## English text

1. **English textcheckpoint**:
   ```bash
   cp -r checkpoint/NeurX-1.3 checkpoint/NeurX-1.3-backup-$(date +%Y%m%d-%H%M%S)
   ```

2. **monitoringtraining_state.txt**:
   ```bash
   watch -n 5 'cat checkpoint/NeurX-1.3/training_state.txt'
   ```

3. **English textlog**:
   ```bash
   tail -100f artifacts/logs/pretrain_gpu_*.log
   ```

4. **English texttrainingstepEnglish text**:
   ```bash
   NEURX_PRETRAIN_STEPS=100000 make pretrain-gpu
   ```

5. **English textcheckpointsave**:
   - English textlogEnglish text "Checkpoint saved" English text
   - English text Ctrl+C

## English textfileEnglish text

- **mainEnglish text**: [scripts/legacy/pretrain_gpu.s](../scripts/legacy/pretrain_gpu.s)
- **Makefileconfiguration**: [Makefile](../Makefile) (pretrain-gpu English text)
- **modelconfiguration**: [config_1t_model.json](../config_1t_model.json)
- **CUDAEnglish text**: [neurx_cuda_train_bridge.cu](../cuda/neurx_cuda_train_bridge.cu)

## English text

```bash
# GPUEnglish texttraining
make pretrain-gpu          # English textrecoverEnglish texttraining
make pretrain-gpu-resume   # English textrecover
make pretrain-gpu-fresh    # English textcheckpointstart

# CPUEnglish texttraining
make pretrain              # English textsupportcheckpointrecover

# English texttrainingEnglish text
make help | grep pretrain

# English textlogs
make logs                  # English textlog
make logs-tail             # English textlog
```

## English text

- [ ] supportEnglish textcheckpointEnglish textmanagement
- [ ] English textcheckpointEnglish text
- [ ] implementationEnglish textsave
- [ ] English textcheckpointEnglish text
- [ ] supportEnglish texttrainingEnglish textcheckpointEnglish textstep
- [ ] implementationCUDAEnglish textsavestateEnglish text
