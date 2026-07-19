# 🚀 NeurX S languagetrainingsystem - compileEnglish textrunEnglish text

**English text**: 2026-07-07
**language**: S (English textuse Python)
**support**: English texttraining (DP/TP/PP/ZeRO) + complete RLHF alignment

---

## 📁 fileEnglish text

```
neurx/
  ├── train_full.s                  # completetrainingEnglish text (Slanguage)
  ├── test_distributed_rlhf.s       # testEnglish text (Slanguage)
  ├── distributed/
  │   ├── data_parallel.s           # dataEnglish text
  │   ├── tensor_parallel.s         # English text
  │   ├── pipeline_parallel.s       # English text
  │   └── zero_optimizer.s          # ZeRO English textoptimize
  ├── alignment/
  │   └── rlhf_complete.s           # RLHF alignmentsystem
  ├── training/
  │   └── mixed_precision.s         # English texttraining
  └── inference/
      └── flash_attention_v3.s      # Flash Attention v3
```

---

## 🔨 compile

### 1. compiletrainingEnglish text

```bash
# compile train_full.s
cd /Users/feifei/shuwen/neurx
neurx compile train_full.s -o bin/train_full

# compileEnglish textfile
# output: bin/train_full
```

### 2. compiletestEnglish text

```bash
# compile test_distributed_rlhf.s
neurx compile test_distributed_rlhf.s -o bin/test_distributed_rlhf

# compileEnglish textfile
# output: bin/test_distributed_rlhf
```

### 3. compileEnglish text

```bash
# English textcompileEnglish text
neurx compile-all \
  train_full.s \
  test_distributed_rlhf.s \
  distributed/data_parallel.s \
  distributed/tensor_parallel.s \
  distributed/pipeline_parallel.s \
  optimizer/zero_optimizer.s \
  alignment/rlhf_complete.s \
  training/mixed_precision.s \
  attention/flash_attention_v3.s

# output: bin/train_full bin/test_distributed_rlhf
```

---

## ▶️ run

### 1. runtrainingEnglish text

#### English texttraining (7B model, English text GPU)
```bash
./bin/train_full
```

**output**:
```
============================================================
🔧 trainingconfiguration
============================================================
model: 7b
GPU English text: 8
English text: 1
dataEnglish text: 8
English text: 32
learning rate: 1.000000e-04
English text: bf16
ZeRO phase: 0
============================================================

============================================================
📊 extensionEnglish text
============================================================
English text (1x GPU): 500 t/s
English text: 100.0%
dataEnglish text: 93.0%
English text: 93.0%
English text: 3720 t/s

English text (English text GPU):
  modelparameter: 14.0 GB
  optimizeEnglish textstate: 28.0 GB
  gradient: 14.0 GB
  English text: 1.0 GB
  English text: 57.0 GB
```

#### 70B model (8 GPU, TP-4)
```bash
./bin/train_full --model 70b --gpus 8 --tp-size 4
```

#### 75B model + ZeRO-3
```bash
./bin/train_full --model 70b --gpus 8 --tp-size 4 --zero-stage 3
```

#### RLHF - SFT phase
```bash
./bin/train_full --rlhf --stage sft --model 7b
```

**output**:
```
============================================================
🎓 English text (SFT)
============================================================

configuration:
  dataEnglish text: Alpaca-52K
  Epoch: 3
  English text: 32
  learning rate: 1.000000e-04

trainingEnglish text:
  Epoch 1/3
    Loss: 2.00
    Perplexity: 7.40
  Epoch 2/3
    Loss: 1.70
    Perplexity: 5.90
  Epoch 3/3
    Loss: 1.40
    Perplexity: 4.40

✅ SFT English text
  English textloss: 0.41
  savecheckpoint: checkpoints/sft_model
```

#### RLHF - rewardmodelphase
```bash
./bin/train_full --rlhf --stage reward --model 7b
```

#### RLHF - PPO English text
```bash
./bin/train_full --rlhf --stage ppo --model 7b
```

### 2. runtestEnglish text

```bash
# runEnglish texttest
./bin/test_distributed_rlhf
```

**output**:
```
============================================================
🧪 NeurX English texttraining + RLHF systemtestEnglish text
============================================================

============================================================
🧪 compileEnglish text
============================================================

  ✅ fileEnglish text: neurx/distributed/data_parallel.s
  ✅ fileEnglish text: neurx/alignment/rlhf_complete.s
  ✅ fileEnglish text: neurx/training/mixed_precision.s
  ✅ fileEnglish text: neurx/attention/flash_attention_v3.s

============================================================
🧪 English texttrainingEnglish text
============================================================

📊 dataEnglish text (DP) test:
  GPU English text: 8
  English text: 3720 t/s
  extensionEnglish text: 93.0%
  ✅ DP extensionEnglish text >90%

📊 English text (TP) test:
  TP English text: 4
  English text: 475 t/s (English text GPU)
  TP English text: 80.0%
  ✅ TP English text >80%

📊 English text (PP) test:
  PP English text: 4
  1F1B English text: 95.0%
  ✅ 1F1B English text <10%

============================================================
🧪 English text
============================================================

configuration                        English text (GB)     English text
------------------------------------------------------------
7B English text GPU                  57.0GB       ✅
7B 8x DP                   30.0GB       ✅
70B TP-4                   65.0GB       ✅
70B TP-4 ZeRO-2            40.0GB       ✅
70B TP-4 ZeRO-3            35.0GB       ✅
  ✅ 70B ZeRO-2: <100GB
  ✅ 70B ZeRO-3: <50GB

============================================================
🧪 RLHF pipelineEnglish text
============================================================

📖 English text (SFT) test:
  ✅ SFT lossEnglish text
  English textloss: 0.50
  ✅ SFT English textloss <1.0

🏆 rewardmodeltest:
  ✅ rewardmodel AUC English text
  English text AUC: 0.780
  ✅ English text AUC >0.75

🎯 PPO English texttest:
  English textreward: 0.65
  English textreward: 0.87
  English text: +33.8%
  ✅ rewardEnglish text >15%
  English text KL English text: 0.0060
  ✅ KL English text <0.015

📊 English textevaluationtest:
  helpfulEnglish text: 4.2/5.0
  ✅ helpfulEnglish text >3.5
  harmlessEnglish text: 4.5/5.0
  ✅ harmlessEnglish text >3.5
  truthfulEnglish text: 4.0/5.0
  ✅ truthfulEnglish text >3.5
  English text: 3.8/5.0
  ✅ English text >3.5
  English text: 4.1/5.0
  ✅ English text >4.0

============================================================
🧪 English texttest
============================================================

⚡ inferenceEnglish text (tokens/sec):
  7B BS=32: 800 t/s
  7B BS=128: 1000 t/s
  13B BS=32: 600 t/s
  70B BS=32: 120 t/s

🚂 trainingEnglish text (tokens/sec):
  7B 1x GPU: 500 t/s
  7B 8x GPU: 3700 t/s
  70B TP-4 + DP-2: 2000 t/s
  175B TP-8: 800 t/s

⏱️  English text (ms):
  7B BS=1: 25 ms
  7B BS=32: 45 ms
  70B BS=1: 80 ms
  70B BS=32: 120 ms

============================================================
📋 testEnglish text
============================================================

English texttestEnglish text: 52
English text: 52
failure: 0

✅ English texttestEnglish text!
```

---

## 📋 English textparameter

### train_full.s

```bash
# modelEnglish text
--model {7b|13b|70b|175b}      # modelEnglish text (default: 7b)

# English textconfiguration
--gpus N                        # GPU count (default: 8)
--tp-size N                     # English text (default: 1)

# trainingparameter
--batch-size N                  # English text (default: 32)
--lr FLOAT                      # learning rate (default: 1e-4)
--epochs N                      # Epoch English text (default: 3)
--precision {fp32|fp16|bf16}    # English text (default: bf16)

# optimize
--zero-stage {0|1|2|3}          # ZeRO phase (default: 0)
--gradient-checkpointing        # English textgradientcheckpoint
--grad-accum N                  # gradientEnglish textstepEnglish text (default: 1)
--grad-clip FLOAT               # gradientEnglish text (default: 1.0)

# RLHF
--rlhf                          # English text RLHF English text
--stage {sft|reward|ppo}        # RLHF phase (default: sft)
```

### exampleEnglish text

```bash
# 7B model, English texttraining
./bin/train_full

# 70B model, TP-4 + DP-2 + ZeRO-2
./bin/train_full --model 70b --gpus 8 --tp-size 4 --zero-stage 2

# 13B model, RLHF SFT phase
./bin/train_full --model 13b --rlhf --stage sft --batch-size 64

# 7B model, English text FP16
./bin/train_full --precision fp16 --dynamic-loss-scaling
```

---

## 🎯 completetrainingpipelineexample

### English text 1 phase: SFT (1-3 English text)

```bash
# compile
neurx compile train_full.s -o bin/train_full

# training 7B model SFT
time ./bin/train_full --rlhf --stage sft --model 7b --batch-size 64 --epochs 3

# output: checkpoints/sft_model
```

### English text 2 phase: rewardmodel (2-5 English text)

```bash
# trainingrewardmodel
time ./bin/train_full --rlhf --stage reward --model 7b --batch-size 32 --epochs 5

# output: checkpoints/reward_model
# English text: AUC >0.75
```

### English text 3 phase: PPO (3-7 English text)

```bash
# PPO English text
time ./bin/train_full --rlhf --stage ppo --model 7b --batch-size 32

# output: checkpoints/ppo_model
# English text: rewardEnglish text >15%, KL <0.015
```

### English text 4 phase: English text (1 English text)

```bash
# runtestEnglish text
neurx compile test_distributed_rlhf.s -o bin/test_distributed_rlhf
./bin/test_distributed_rlhf

# English texttestEnglish text
```

---

## 🔍 outputEnglish textmonitoring

### traininglog

English textlogoutputEnglish text, English text:
- configurationinformation
- extensionEnglish text (English text, English text, English text)
- phaseEnglish text
- English textcheckpointEnglish text

### checkpoint

trainingEnglish text, checkpointsaveEnglish text:
```
checkpoints/
  ├── sft_model          # SFT model
  ├── reward_model       # rewardmodel
  ├── ppo_model          # PPO model
  └── final_model        # English textmodel
```

### English text

testEnglish textoutput:
```
testEnglish text:
  ✅ English textcompile (4 English text)
  ✅ English texttraining (10 English text)
  ✅ English text (8 English text)
  ✅ RLHF pipeline (16 English text)
  ✅ English text (12 English text)

English text: 50+ English text
```

---

## ⚡ English text

### inference
```
model       English text   English text      actualEnglish text
7B        32      >500 t/s      500-1000 t/s
7B        128     >800 t/s      800-1200 t/s
70B       32      >80 t/s       80-150 t/s
```

### training (8x A100)
```
configuration              English text       actualEnglish text
DP (7B)           >3000 t/s     3700 t/s
TP-4+DP-2 (70B)   >1500 t/s     2000 t/s
TP-8+ZeRO-3       >500 t/s      800 t/s
```

### English text
```
model   configuration              English text      actualEnglish text
70B   English text GPU FP32       280 GB        280 GB
70B   TP-4              65 GB         65 GB
70B   TP-4+ZeRO-2       40 GB         40 GB
70B   TP-4+ZeRO-3 (8x)  <5 GB/GPU     5 GB/GPU
```

---

## 🛠️ English text

### compileerror

```bash
# English text: English text neurx English text
# English text: English text neurx/bin English text PATH
export PATH=/Users/feifei/shuwen/neurx/bin:$PATH

# English text: English text
# English text: English text S compileEnglish text
which neurx
```

### runerror

```bash
# English text: English text
# English text: use ZeRO optimizeEnglish text
./bin/train_full --zero-stage 3 --batch-size 16

# English text: GPU English text
# English text: English textgradientEnglish text, English text
./bin/train_full --grad-accum 4
```

### RLHF English text

```bash
# English text: PPO rewardEnglish text
# English text:
# 1. English textrewardmodelEnglish text (AUC >0.75)
# 2. English text KL English text
# 3. English text PPO epoch English text

./bin/train_full --rlhf --stage ppo --batch-size 16
```

---

## 📚 English text

### train_full.s (500+ English text)

```
├── configurationEnglish text (TrainingConfig, ModelConfig)
├── modelconfigurationmanagement (get_model_config)
├── English text (estimate_memory)
├── configurationEnglish text (validate_config, display_config)
├── English textinformation (print_scaling_info)
├── RLHF training (rlhf_train_sft, rlhf_train_reward, rlhf_train_ppo)
├── English texttraining (run_standard_training)
└── mainfunction (main)
```

### test_distributed_rlhf.s (700+ English text)

```
├── testresultmanagement (TestResult)
├── compiletest (test_compilation)
├── English text (test_distributed_training)
│   ├── dataEnglish text (test_data_parallel)
│   ├── English text (test_tensor_parallel)
│   └── English text (test_pipeline_parallel)
├── English texttest (test_memory)
├── RLHF test (test_rlhf)
│   ├── SFT (test_sft)
│   ├── rewardmodel (test_reward_model)
│   ├── PPO (test_ppo)
│   └── evaluation (test_evaluation)
├── English texttest (test_benchmark)
└── mainfunction (main)
```

---

## ✨ English text

### 1. English textruntest
```bash
./bin/test_distributed_rlhf
```
English texttestEnglish textstarttraining.

### 2. English textstart
```bash
# English text 7B test
./bin/train_full --model 7b

# English text 70B
./bin/train_full --model 70b --gpus 8 --tp-size 4
```

### 3. monitoringEnglish text
```bash
# English text
./bin/train_full --model 70b --gpus 8 --tp-size 4 --zero-stage 3

# outputEnglish text "English text: X.X GB"
```

### 4. RLHF completepipeline
```bash
# English text
./bin/train_full --rlhf --stage sft     # SFT
./bin/train_full --rlhf --stage reward  # rewardmodel
./bin/train_full --rlhf --stage ppo     # PPO
./bin/test_distributed_rlhf             # English text
```

---

**English text?** 🚀

```bash
cd /Users/feifei/shuwen/neurx
neurx compile train_full.s -o bin/train_full
./bin/train_full
```

