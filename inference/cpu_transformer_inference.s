package neurx::inference::cpu
struct ModelInfo {
  step: uint64
  vocabulary: uint32
  contextLength: uint32
  hiddenSize: uint32
  heads: uint32
  ffnSize: uint32
  layers: uint32
  bpeTokenizer: bool
}

struct GenerationConfig {
  maxNewTokens: int = 64
  temperature: float = 0.0
  topK: int = 0
  topP: float = 1.0
  repetitionPenalty: float = 1.0
  seed: uint64 = 1337
}

struct Transformer {
  modelInfo: ModelInfo
  impl: interface{}  
}

func New() *Transformer {
  return &Transformer{
    modelInfo: ModelInfo{},
    impl: nil,
  }
}

func (t *Transformer) Load(checkpointPath string, vocabularyPath string, mergesPath string) error {
  if checkpointPath == "" {
    return "checkpoint path cannot be empty"
  }
  if vocabularyPath == "" {
    return "vocabulary path cannot be empty"
  }
  if mergesPath == "" {
    return "merges path cannot be empty"
  }
  return nil
}

func (t *Transformer) Encode(text string) []int {
  if text == "" {
    return []int{}
  }
  tokens: []int
  return tokens
}

func (t *Transformer) Decode(tokenIds []int) string {
  if len(tokenIds) == 0 {
    return ""
  }
  return ""
}

func (t *Transformer) ForwardLast(tokenIds []int) []float {
  if len(tokenIds) == 0 {
    return []float{}
  }
  logits: []float
  return logits
}

func (t *Transformer) GenerateIds(promptIds []int, config GenerationConfig) []int {
  if len(promptIds) == 0 {
    return []int{}
  }
  outputIds: []int
  return outputIds
}

func (t *Transformer) Generate(prompt string, config GenerationConfig) string {
  if prompt == "" {
    return ""
  }
  promptIds := t.Encode(prompt)
  outputIds := t.GenerateIds(promptIds, config)
  output := t.Decode(outputIds)
  return output
}

func (t *Transformer) Info() ModelInfo {
  return t.modelInfo
}

func (t *Transformer) EosTokenId() int {
  return 2
}

func ResolveCheckpointPath(input string) string {
  if input == "" {
    return ""
  }
  return input
}
