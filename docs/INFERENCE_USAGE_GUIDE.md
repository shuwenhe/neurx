# NeurX S inferenceEnglish textuseEnglish text

## quickstart

### runinference
```bash
cd /home/shuwen/shuwen/train/neurx
bash scripts/legacy/run_inference_llm.sh
```

### English textoutput
```
✅ inferencepipelineEnglish text

inferenceresult:
================================================
NeurX S Inference Engine (Simplified)
================================================
Model: llm_s
Device: cpu
...
```

## English textconfiguration

English textsupportEnglish textconfiguration, English textIRrunEnglish text, English text**English text**.useEnglish textconfiguration:

### English text1: English text(recommended)
English text `inference/production_inference.s` English textdefaultEnglish text:
```s
string model_name = trim(runtime_env_get("NEURX_INFER_MODEL_NAME", "llm_s"))
// English text (English textdefaultEnglish text):
string model_name = trim(runtime_env_get("NEURX_INFER_MODEL_NAME", "your_model"))
```

### English text2: English text
English text `scripts/legacy/run_inference_llm.sh` English textdefaultEnglish text:
```bash
MODEL_NAME="${NEURX_INFER_MODEL_NAME:-llm_s}"
# English text:
MODEL_NAME="${NEURX_INFER_MODEL_NAME:-your_model}"
```

## supportEnglish text

✅ **English textimplementation**
- compileSEnglish text(IR)
- English textIRrunEnglish textinferenceEnglish text
- outputsystemconfigurationinformation
- English texterrorEnglish text
- English textSlanguageEnglish text(English textCEnglish text)

❌ **English textimplementation** (IRrunEnglish text)
- actualEnglish textmodelload
- modelinferencecompute
- filesystemEnglish text
- English text
- English text

## English text

### IRrunEnglish textsupportEnglish text
1. **English text**: English textIRrunEnglish text
2. **English textfunction**: std.env.get, std.fs.*, std.process.* English textIREnglish textuse
3. **English textfunctionEnglish text**: English textCEnglish textfunction(English text)
4. **fileI/O**: English textfile

## recovercompleteEnglish text

### English text1: compileEnglish text
```bash
# English text "s ir", use "s build":
/home/shuwen/s/bin/s build inference/production_inference.s -o build/inference_native

# runEnglish text(supportEnglish text):
./build/inference_native
```

### English text2: English textIRrunEnglish text
English textScompileEnglish textIRrunEnglish textfunctionEnglish textsupport.

### English text3: English textextension
English textRequiredEnglish text, AllowedextensionIRrunEnglish textimplementation.

## fileEnglish text

- **English text**: `inference/production_inference.s`
- **compileoutput**: `build/inference/inference.ir`
- **runEnglish text**: `build/inference/inference_runner`
- **output**: `artifacts/inference_output/inference_*.txt`
- **log**: `artifacts/logs/inference_*.log`
- **English text**: `inference/production_inference.s.backup`

## English text

### error: `unknown return value` English text `unknown function`
English textcompileEnglish textIRrunEnglish textsupportEnglish textfunction.English text.

### error: `compiled /path/.../inference.ir` + errorinformation
English textcompileEnglish textphaseEnglish text.English text:
- ScompileEnglish text
- English textfileEnglish text
- English textuseEnglish textsupportEnglish textlanguageEnglish text

### English textrecoverEnglish text
```bash
# recoverEnglish text(English textIREnglish textrun)
cp inference/production_inference.s.backup inference/production_inference.s
```

## English text

```
Source Code (S)
    ↓
S Compiler (s ir)
    ↓
Intermediate Representation (IR)
    ↓
IR Runner (seed runtime)
    ↓
Output
```

## English text

- **compiletime**: < 1English text
- **English texttime**: < 1English text
- **IRfileEnglish text**: 5.6K(English textoptimize, English text42K)
- **English text**: English text(IRrunEnglish text)

## English textstepEnglish text

1. English textcompileEnglish textrunpipeline
2. implementationmodelload(RequiredextensionIRrunEnglish textuseEnglish text)
3. English textmonitoringEnglish textlogEnglish text
4. optimizeIREnglish textgenerate

## English text

English text, English text:
- INFERENCE_FIX_SUMMARY.md - English text
- production_inference.s - English textimplementation
