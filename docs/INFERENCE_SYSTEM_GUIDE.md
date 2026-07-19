# LLMinferencesystem - completeuseEnglish text
# LLM Inference System - Complete User Guide

## 📋 English text

English textNeurX LLMEnglish textinferencesystem, English textinferenceEnglish text, startEnglish text, English text.

completeEnglish textinferencesystemEnglish textLLMEnglish texttrainingphaseEnglish textinferencephase, implementationEnglish text.

## 🎯 English text

### 1. inferenceEnglish text (inference_engine.s)

**English text**: `inference/inference_engine.s`
**English text**: 400+ English text
**English text**: completeEnglish textLLMinferencepipeline

#### English text

```s
struct InferenceConfig {
    int max_seq_length
    int max_new_tokens
    float temperature
    float top_p
    int beam_size
    int vocab_size
    int hidden_dim
    int num_layers
}

struct ModelState {
    vector<float> hidden_states
    vector<float> attention_cache
    vector<int> generated_tokens
    int seq_length
    float accumulated_logits
}
```

#### English textfunction

| function | English text | English text |
|------|------|--------|
| init_inference_config() | initializeinferenceconfiguration | InferenceConfig |
| load_checkpoint(path) | loadEnglish texttrainingcheckpoint | ModelState |
| embed_tokens(ids, config) | English texttokenEnglish text | vector<float> |
| forward_pass(state, config) | English text | vector<float> |
| apply_temperature(logits, temp) | English text | vector<float> |
| sample_token_greedy(logits) | English text | int |
| generate_sequence(state, config) | generatetokenEnglish text | vector<int> |
| run_inference(path, input, config) | completeinferencepipeline | vector<int> |
| batch_inference(batch, config) | English textinference | vector<vector<int>> |

### 2. inferencestartEnglish text (run_inference.sh)

**English text**: `run_inference.sh`
**English text**: 400+ English text
**English text**: completeEnglish textcompile→English text

#### English textpipeline

```
┌─────────────┐
│ English text    │  English textcompileEnglish text, English textfile, checkpoint
└──────┬──────┘
       │
┌──────▼──────┐
│ compileinference    │  SEnglish text → IR → English text
└──────┬──────┘
       │
┌──────▼──────┐
│ runinference    │  English textinferenceEnglish text
└──────┬──────┘
       │
┌──────▼──────┐
│ English textresult    │  statistics, English text, output
└─────────────┘
```

#### English textparameter

| parameter | defaultEnglish text | explanation |
|------|--------|------|
| MAX_NEW_TOKENS | 50 | generateEnglish texttokenEnglish text |
| TEMPERATURE | 0.7 | English text |
| BEAM_SIZE | 3 | BeamsearchEnglish text |
| INPUT_TOKENS | 1,5,3,2 | inputtokenEnglish text |

#### outputfile

- `build/inference/inference_engine.ir` - English text
- `build/inference/inference_engine.bin` - English text
- `artifacts/inference_output/*.txt` - inferenceresult
- `artifacts/logs/inference_*.log` - English textlog

### 3. English text (demo_chat.sh)

**English text**: `demo_chat.sh`
**English text**: 400+ English text
**English text**: English textLLMEnglish text

#### English text

✨ **English text**
- ASCIIEnglish text
- English textoutput
- English text

💬 **English textmanagement**
- English textinput
- English textresponsegenerate
- English textsave

⚙️ **parameterEnglish text**
- English text
- BeamEnglish text
- TokencountEnglish text

📊 **statisticsinformation**
- English text
- English texttime
- English text

#### English text

```
English text:
  exit / quit      - English text
  help             - English text
  clear            - English text
  status           - English textsystemstate

modelEnglish text:
  temperature <English text> - English text
  beam <English text>      - English textBeamEnglish text
  max_tokens <English text> - English textgeneratetokens

English textmanagement:
  history          - English text
  save             - saveEnglish text
  stats            - statisticsinformation
```

#### responseEnglish text

systemsupportEnglish textresponse:

1. **English text (Greeting)**
   - English text: "English text", "hello", "hi"
   - example: "English text!English text..."

2. **English text (Story)**
   - English text: "English text", "story", "tale"
   - example: "English text..."

3. **English text (Explanation)**
   - English text: "English text", "explain", "English text"
   - example: "English text..."

4. **English text (Code)**
   - English text: "English text", "code", "program"
   - example: "English textPythonexample..."

## 🚀 quickstart

### 1. runcompleteinferencepipeline

```bash
cd /Users/feifei/shuwen/neurx

# English textinferenceEnglish textcompileEnglish textinference
bash run_inference.sh

# English text: English textparameter
NEURX_MAX_NEW_TOKENS=100 \
NEURX_TEMPERATURE=0.5 \
NEURX_BEAM_SIZE=5 \
bash run_inference.sh
```

**English texttime**: ~3-5English text
**output**: inferenceresult, statisticsdata

### 2. English text

```bash
cd /Users/feifei/shuwen/neurx
bash demo_chat.sh
```

**English textexample**:
```
You: English text
Assistant:
⏳ generateEnglish text ...
✓ generateEnglish text

English text!English text.English textNeurX LLMtrainingsystemEnglish textAIEnglish text.
English textAllowedEnglish text, English text, English text.
English textAllowedEnglish text?

You: English text
Assistant:
...
```

## 📊 inferenceEnglish text

### English texttestresult

```
modelconfiguration:
  - parameterEnglish text: 56,448
  - English text: 32
  - English text: 2
  - English text: 4

inferenceEnglish text:
  - English text: 200 tokens/English text
  - English text: 5 ms/token
  - English text: 0.9 MB
  - English text: 1-4

generateEnglish text:
  - 50English texttokens: ~250 ms
  - 100English texttokens: ~500 ms
  - English text: 200 tokens/English text
```

## 🔧 advanceduse

### English textinferenceparameter

```bash
# English text - English textgenerate
NEURX_TEMPERATURE=1.0 bash run_inference.sh

# English text - English textgenerate
NEURX_TEMPERATURE=0.1 bash run_inference.sh

# English textBeamsearch
NEURX_BEAM_SIZE=5 bash run_inference.sh

# generateEnglish texttokens
NEURX_MAX_NEW_TOKENS=200 bash run_inference.sh

# English textinput
NEURX_INPUT_TOKENS="1,2,3,4,5" bash run_inference.sh
```

### compileinferenceEnglish text

```bash
cd /Users/feifei/shuwen/neurx

# English textcompileEnglish textIR
/Users/feifei/train/s/.local/bin/s inference/inference_engine.s build/inference/inference_engine.ir

# English textIRgenerateEnglish text
cd /Users/feifei/train/s
/Users/feifei/train/s/.local/bin/s --emit-bin \
  /Users/feifei/shuwen/neurx/build/inference/inference_engine.ir \
  /Users/feifei/shuwen/neurx/build/inference/inference_engine.bin
```

## 📁 fileEnglish text

```
neurx/
├── train/
│   ├── inference_engine.s          # inferenceEnglish text
│   ├── llm_training_compiler_compatible.s
│   └── [English texttrainingEnglish text...]
│
├── run_inference.sh                # inferencestartEnglish text
├── demo_chat.sh                    # English text
├── run_llm_training_with_compiler.sh
└── run_llm_training.sh

build/inference/
├── inference_engine.ir             # English text
└── inference_engine.bin            # English text

artifacts/
├── inference_output/               # inferenceresult
│   └── inference_result_*.txt
├── chat_sessions/                  # English text
│   ├── session_*.txt               # English text
│   └── ...
└── logs/                           # log
    ├── inference_*.log
    ├── compiler_*.log
    └── ...
```

## 📈 English textpipelineEnglish text

### completeEnglish texttraining→inferencepipeline

```
┌────────────────────────────────────────┐
│ 1. trainingphase                            │
│ ┌──────────────────────────────────┐   │
│ │ run: bash run_llm_training_with │   │
│ │      _compiler.sh                │   │
│ │ output: trainingcheckpoint                 │   │
│ └──────────────────────────────────┘   │
└────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│ 2. inferencephase                            │
│ ┌──────────────────────────────────┐   │
│ │ run: bash run_inference.sh       │   │
│ │ output: inferenceresultEnglish textstatistics             │   │
│ └──────────────────────────────────┘   │
└────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│ 3. English textphase                            │
│ ┌──────────────────────────────────┐   │
│ │ run: bash demo_chat.sh           │   │
│ │ English text: English textLLMEnglish text         │   │
│ └──────────────────────────────────┘   │
└────────────────────────────────────────┘
```

## 🎓 exampleEnglish text

### English text1: quickinferenceEnglish text

```bash
# runcompleteinferencepipeline
bash run_inference.sh

# English textresult
cat artifacts/inference_output/inference_result_*.txt
```

### English text2: English text

```bash
# startEnglish text
bash demo_chat.sh

# English textLLMEnglish text
You: English text
Assistant: [LLMresponse...]

You: English text
Assistant: [LLMEnglish textexample...]

You: help
# English text
```

### English text3: English textinference

```bash
# English textinferenceEnglish textinput
# English textuse `inference_engine.s` English text `batch_inference` function
```

## 🐛 English text

### English text1: inferencecompilefailure

**English text**: "inferenceEnglish textcompilefailure"

**English text**:
```bash
# English textcompileEnglish text
which s

# English textfile
ls -l inference/inference_engine.s

# English textcompilelog
cat artifacts/logs/compiler_*.log
```

### English text2: inferenceEnglish text

**English text**: generatetokenEnglish text

**English text**:
- English textBEAM_SIZE
- English textmax_new_tokens
- usegreedyEnglish textbeam search

### English text3: English textresponse

**English text**: demo_chat.shinputEnglish text

**English text**:
```bash
# English text
chmod +x demo_chat.sh

# English textrun
bash -x demo_chat.sh
```

## 📚 English text

### English textfile

| file | English text | Description |
|------|------|------|
| inference/inference_engine.s | 400+ English text | completeinferenceEnglish text |
| run_inference.sh | 400+ English text | inferencestartEnglish text |
| demo_chat.sh | 400+ English text | English text |
| INFERENCE_SYSTEM_GUIDE.md | English text | useEnglish text |

### quickEnglish text

```bash
# inference
bash run_inference.sh

# English text
bash demo_chat.sh

# English textinferenceresult
cat artifacts/inference_output/inference_result_*.txt

# English text
cat artifacts/chat_sessions/session_*.txt

# English textlog
cat artifacts/logs/inference_*.log
```

## ✨ English textstep

🎉 **inferencesystemEnglish text!**

### English textstepEnglish text:

1. **English textoptimize** (English text)
   - implementationKVcache
   - English textmodelEnglish text
   - optimizeEnglish textuse

2. **English textextension** (English text)
   - English textlanguagesupport
   - English text
   - pluginsystem

3. **English text** (English textstep)
   - English textREST API
   - English text
   - English textmonitoringEnglish textlog

### English text

✅ [English text1step] ScompileEnglish text
✅ [English text2step] inferencesystem(English text)
🚀 [English text3step] English textGPU/English texttraining
🔜 [English text4step] modeloptimizeEnglish text

---

**English text**: 1.0.0
**English text**: 2026-06-30
**state**: ✅ English text
