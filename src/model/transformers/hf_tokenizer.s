package neurx.transformers_utils.hf_tokenizer
struct hf_tokenizer {
    string tokenizer_class
    string vocab_file
    string merges_file
    int vocab_size
    int bos_token_id
    int eos_token_id
    int pad_token_id
    int unk_token_id
    int cls_token_id
    int sep_token_id
    int mask_token_id
    string[] special_tokens
    string padding_side
    string truncation_side
    int max_length
    bool do_lower_case
    string model_max_length
}

func create_llama_tokenizer() hf_tokenizer {
    hf_tokenizer {
        tokenizer_class: "LlamaTokenizer",
        vocab_file: "tokenizer.model",
        merges_file: "",
        vocab_size: 32000,
        bos_token_id: 1,
        eos_token_id: 2,
        pad_token_id: 0,
        unk_token_id: 0,
        cls_token_id: -1,
        sep_token_id: -1,
        mask_token_id: -1,
        special_tokens: ["<unk>", "<s>", "</s>", "<pad>"],
        padding_side: "right",
        truncation_side: "right",
        max_length: 4096,
        do_lower_case: false,
        model_max_length: "4096",
    }
}

func create_qwen_tokenizer() hf_tokenizer {
    hf_tokenizer {
        tokenizer_class: "Qwen2Tokenizer",
        vocab_file: "vocab.json",
        merges_file: "merges.txt",
        vocab_size: 152064,
        bos_token_id: 151657,
        eos_token_id: 151643,
        pad_token_id: 151643,
        unk_token_id: 151659,
        cls_token_id: -1,
        sep_token_id: -1,
        mask_token_id: -1,
        special_tokens: ["<|endoftext|>", "<|im_start|>", "<|im_end|>"],
        padding_side: "right",
        truncation_side: "right",
        max_length: 32768,
        do_lower_case: false,
        model_max_length: "32768",
    }
}

func create_mistral_tokenizer() hf_tokenizer {
    hf_tokenizer {
        tokenizer_class: "MistralTokenizer",
        vocab_file: "tokenizer.model",
        merges_file: "",
        vocab_size: 32000,
        bos_token_id: 1,
        eos_token_id: 2,
        pad_token_id: 0,
        unk_token_id: 0,
        cls_token_id: -1,
        sep_token_id: -1,
        mask_token_id: -1,
        special_tokens: ["<unk>", "<s>", "</s>", "<pad>"],
        padding_side: "right",
        truncation_side: "right",
        max_length: 32768,
        do_lower_case: false,
        model_max_length: "32768",
    }
}

func create_deepseek_tokenizer() hf_tokenizer {
    hf_tokenizer {
        tokenizer_class: "DeepSeekTokenizer",
        vocab_file: "vocab.json",
        merges_file: "merges.txt",
        vocab_size: 102400,
        bos_token_id: 100000,
        eos_token_id: 100001,
        pad_token_id: 0,
        unk_token_id: 20001,
        cls_token_id: -1,
        sep_token_id: -1,
        mask_token_id: -1,
        special_tokens: ["<unk>", "<s>", "</s>", "<pad>"],
        padding_side: "right",
        truncation_side: "right",
        max_length: 4096,
        do_lower_case: false,
        model_max_length: "4096",
    }
}

struct token_ids {
    int[] ids
    int[] attention_mask
    int[] token_type_ids
}

func tokenize_text(string text, hf_tokenizer tokenizer) string[] {
    string[] tokens
    string current_token = ""
    for char in text {
        if char == ' ' || char == '\n' || char == '\t' {
            if current_token != "" {
                tokens.append(current_token)
                current_token = ""
            }
        } else if char == '.' || char == ',' || char == '!' || char == '' {
            if current_token != "" {
                tokens.append(current_token)
                current_token = ""
            }
            tokens.append(string(char))
        } else {
            current_token = current_token + string(char)
        }
    }
    if current_token != "" {
        tokens.append(current_token)
    }
    tokens
}

func apply_chat_template(
    messages: string[],
    tokenizer: hf_tokenizer,
    bool add_generation_prompt
) string {
    string formatted = ""
    for msg in messages {
        formatted = formatted + msg + "\n"
    }
    if add_generation_prompt {
        formatted = formatted + "<|assistant|>\n"
    }
    formatted
}

func get_token_from_tokenizer(string tokenizer_class, string model_id) hf_tokenizer {
    if tokenizer_class == "LlamaTokenizer" {
        return create_llama_tokenizer()
    }
    if tokenizer_class == "Qwen2Tokenizer" {
        return create_qwen_tokenizer()
    }
    if tokenizer_class == "MistralTokenizer" {
        return create_mistral_tokenizer()
    }
    if tokenizer_class == "DeepSeekTokenizer" {
        return create_deepseek_tokenizer()
    }
    create_llama_tokenizer()
}
