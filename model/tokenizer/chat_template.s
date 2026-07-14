package neurx.model.tokenizer.chat_template

// ============================================================================
// Chat Template — 对话格式化
//
// 工业级 LLM 微调需要统一的对话格式把 messages 转换为 token 序列。
// 不同模型使用不同格式：
//
//   ChatML (主流模型):
//     <|im_start|>system\n{content}<|im_end|>\n
//     <|im_start|>user\n{content}<|im_end|>\n
//     <|im_start|>assistant\n
//
//   LLaMA-2 Chat:
//     [INST] <<SYS>>\n{system}\n<</SYS>>\n\n{user} [/INST] {assistant}
//
//   LLaMA-3 / Mistral:
//     <|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{content}<|eot_id|>
//     <|start_header_id|>user<|end_header_id|>\n\n{content}<|eot_id|>
//     <|start_header_id|>assistant<|end_header_id|>\n\n
//
//   NeurX-R1:
//     <｜begin▁of▁sentence｜>{system}<｜User｜>{user}<｜Assistant｜><think>\n
//
//   Gemma:
//     <start_of_turn>user\n{content}<end_of_turn>\n<start_of_turn>model\n
//
// ============================================================================

// ============================================================================
// 1. 消息角色 & 对话结构
// ============================================================================

struct chat_message {
    string role       // "system" | "user" | "assistant" | "tool"
    string content    // 消息内容
    string name       // 可选: function/tool 名称
}

struct chat_conversation {
    []chat_message messages
    bool add_generation_prompt  // 是否追加模型生成提示 (训练时 false, 推理时 true)
    string system_prompt        // 默认系统 prompt (若 messages 中没有)
}

func new_conversation([]chat_message msgs, bool gen_prompt) chat_conversation {
    chat_conversation {
        messages: msgs,
        add_generation_prompt: gen_prompt,
        system_prompt: "",
    }
}

// ============================================================================
// 2. 模板格式枚举 & 配置
// ============================================================================

struct template_config {
    string format           // "chatml" | "llama2" | "llama3" | "neurx_r1" | "gemma" | "alpaca"
    string system_token     // 系统提示标记
    string user_token       // 用户标记
    string assistant_token  // 助手标记
    string end_token        // 对话结束标记
    string bos_token        // 序列开始
    string eos_token        // 序列结束
    string nl               // 换行符 (通常 "\n")
    bool add_bos            // 是否添加 BOS
    bool add_eos_turn       // 每轮结束是否加 EOS
}

func chatml_config() template_config {
    template_config {
        format: "chatml",
        system_token: "<|im_start|>system",
        user_token: "<|im_start|>user",
        assistant_token: "<|im_start|>assistant",
        end_token: "<|im_end|>",
        bos_token: "",
        eos_token: "<|im_end|>",
        nl: "\n",
        add_bos: false,
        add_eos_turn: true,
    }
}

func llama2_config() template_config {
    template_config {
        format: "llama2",
        system_token: "[INST] <<SYS>>\n",
        user_token: "[INST]",
        assistant_token: "",
        end_token: "[/INST]",
        bos_token: "<s>",
        eos_token: "</s>",
        nl: "\n",
        add_bos: true,
        add_eos_turn: true,
    }
}

func llama3_config() template_config {
    template_config {
        format: "llama3",
        system_token: "<|start_header_id|>system<|end_header_id|>\n\n",
        user_token: "<|start_header_id|>user<|end_header_id|>\n\n",
        assistant_token: "<|start_header_id|>assistant<|end_header_id|>\n\n",
        end_token: "<|eot_id|>",
        bos_token: "<|begin_of_text|>",
        eos_token: "<|eot_id|>",
        nl: "\n",
        add_bos: true,
        add_eos_turn: true,
    }
}

func neurx_r1_config() template_config {
    template_config {
        format: "neurx_r1",
        system_token: "",
        user_token: "<｜User｜>",
        assistant_token: "<｜Assistant｜>",
        end_token: "<｜end▁of▁sentence｜>",
        bos_token: "<｜begin▁of▁sentence｜>",
        eos_token: "<｜end▁of▁sentence｜>",
        nl: "\n",
        add_bos: true,
        add_eos_turn: true,
    }
}

func gemma_config() template_config {
    template_config {
        format: "gemma",
        system_token: "",
        user_token: "<start_of_turn>user\n",
        assistant_token: "<start_of_turn>model\n",
        end_token: "<end_of_turn>\n",
        bos_token: "<bos>",
        eos_token: "<eos>",
        nl: "\n",
        add_bos: true,
        add_eos_turn: true,
    }
}

func alpaca_config() template_config {
    template_config {
        format: "alpaca",
        system_token: "### System:\n",
        user_token: "### Instruction:\n",
        assistant_token: "### Response:\n",
        end_token: "\n\n",
        bos_token: "",
        eos_token: "</s>",
        nl: "\n",
        add_bos: false,
        add_eos_turn: false,
    }
}

// ============================================================================
// 3. 格式化函数
// ============================================================================

// 格式化整个对话
func apply_chat_template(chat_conversation conv, template_config tmpl) string {
    string result = ""

    // BOS
    if tmpl.add_bos {
        result = str_cat(result, tmpl.bos_token)
    }

    int i = 0
    for i < len(conv.messages) {
        chat_message msg = conv.messages[i]
        string turn = format_turn(msg, tmpl, i == 0, conv.system_prompt)
        result = str_cat(result, turn)
        i = i + 1
    }

    // 追加生成提示 (推理时: 告诉模型开始生成)
    if conv.add_generation_prompt {
        result = str_cat(result, format_generation_prompt(tmpl))
    }

    result
}

func format_turn(chat_message msg, template_config tmpl, bool is_first, string default_system) string {
    string content = msg.content

    if msg.role == "system" {
        return format_system(content, tmpl)
    }

    if msg.role == "user" {
        string result = ""
        // 若是第一轮用户消息且有默认系统 prompt, 注入 system
        if is_first && str_len(default_system) > 0 {
            result = str_cat(result, format_system(default_system, tmpl))
        }
        return str_cat(result, format_user(content, tmpl))
    }

    if msg.role == "assistant" {
        return format_assistant(content, tmpl, true)
    }

    // tool / function
    format_tool(msg.name, content, tmpl)
}

func format_system(string content, template_config tmpl) string {
    if tmpl.format == "chatml" {
        // <|im_start|>system\n{content}<|im_end|>\n
        string r = str_cat(tmpl.system_token, tmpl.nl)
        r = str_cat(r, content)
        r = str_cat(r, tmpl.end_token)
        return str_cat(r, tmpl.nl)
    }

    if tmpl.format == "llama2" {
        // [INST] <<SYS>>\n{content}\n<</SYS>>\n\n
        string r = "[INST] <<SYS>>\n"
        r = str_cat(r, content)
        r = str_cat(r, "\n<</SYS>>\n\n")
        return r
    }

    if tmpl.format == "llama3" {
        string r = str_cat(tmpl.system_token, content)
        r = str_cat(r, tmpl.end_token)
        return str_cat(r, tmpl.nl)
    }

    if tmpl.format == "neurx_r1" {
        // 系统 prompt 直接拼接在 BOS 后
        return str_cat(content, tmpl.nl)
    }

    if tmpl.format == "gemma" {
        // Gemma 不支持 system role, 降级为 user
        return format_user(content, tmpl)
    }

    // alpaca / default
    string r = str_cat(tmpl.system_token, content)
    str_cat(r, tmpl.nl)
}

func format_user(string content, template_config tmpl) string {
    if tmpl.format == "chatml" {
        string r = str_cat(tmpl.user_token, tmpl.nl)
        r = str_cat(r, content)
        r = str_cat(r, tmpl.end_token)
        return str_cat(r, tmpl.nl)
    }

    if tmpl.format == "llama2" {
        // {content} [/INST]
        string r = str_cat(content, " ")
        return str_cat(r, tmpl.end_token)
    }

    if tmpl.format == "llama3" {
        string r = str_cat(tmpl.user_token, content)
        r = str_cat(r, tmpl.end_token)
        return str_cat(r, tmpl.nl)
    }

    if tmpl.format == "neurx_r1" {
        string r = str_cat(tmpl.user_token, content)
        return r
    }

    if tmpl.format == "gemma" {
        string r = str_cat(tmpl.user_token, content)
        r = str_cat(r, tmpl.end_token)
        return r
    }

    // alpaca
    string r = str_cat(tmpl.user_token, content)
    str_cat(r, tmpl.nl)
}

// add_eos: 训练时 true (加 EOS 作为终止学习目标), 推理生成时 false
func format_assistant(string content, template_config tmpl, bool add_eos) string {
    if tmpl.format == "chatml" {
        string r = str_cat(tmpl.assistant_token, tmpl.nl)
        r = str_cat(r, content)
        if add_eos {
            r = str_cat(r, tmpl.end_token)
            r = str_cat(r, tmpl.nl)
        }
        return r
    }

    if tmpl.format == "llama2" {
        // {content}</s>
        string r = str_cat(" ", content)
        if add_eos {
            r = str_cat(r, tmpl.eos_token)
        }
        return r
    }

    if tmpl.format == "llama3" {
        string r = str_cat(tmpl.assistant_token, content)
        if add_eos {
            r = str_cat(r, tmpl.end_token)
            r = str_cat(r, tmpl.nl)
        }
        return r
    }

    if tmpl.format == "neurx_r1" {
        // <｜Assistant｜><think>\n{thinking}\n</think>\n{content}
        string r = str_cat(tmpl.assistant_token, content)
        if add_eos {
            r = str_cat(r, tmpl.end_token)
        }
        return r
    }

    if tmpl.format == "gemma" {
        string r = str_cat(tmpl.assistant_token, content)
        if add_eos {
            r = str_cat(r, tmpl.end_token)
        }
        return r
    }

    // alpaca
    string r = str_cat(tmpl.assistant_token, content)
    if add_eos {
        r = str_cat(r, tmpl.eos_token)
    }
    str_cat(r, tmpl.nl)
}

func format_tool(string name, string content, template_config tmpl) string {
    // Tool 消息: <|im_start|>tool\n[{name}]: {content}<|im_end|>\n
    if tmpl.format == "chatml" {
        string r = "<|im_start|>tool\n"
        if str_len(name) > 0 {
            r = str_cat(r, "[")
            r = str_cat(r, name)
            r = str_cat(r, "]: ")
        }
        r = str_cat(r, content)
        r = str_cat(r, tmpl.end_token)
        return str_cat(r, tmpl.nl)
    }
    // 其他格式降级为 user
    format_user(content, tmpl)
}

func format_generation_prompt(template_config tmpl) string {
    if tmpl.format == "chatml" {
        return str_cat(tmpl.assistant_token, tmpl.nl)
    }
    if tmpl.format == "llama2" {
        return " "
    }
    if tmpl.format == "llama3" {
        return tmpl.assistant_token
    }
    if tmpl.format == "neurx_r1" {
        return str_cat(tmpl.assistant_token, "<think>\n")
    }
    if tmpl.format == "gemma" {
        return tmpl.assistant_token
    }
    // alpaca
    tmpl.assistant_token
}

// ============================================================================
// 4. SFT 数据集格式化 (用于训练)
// ============================================================================

// SFT 样本: 输入文本 + loss mask (只对 assistant 回复计算 loss)
struct sft_sample {
    string full_text        // 完整对话文本
    []int  loss_mask        // [token_len] 0=忽略 1=计算 loss
    int    input_len        // 前缀 (prompt) 长度 (不计 loss)
    int    target_len       // 响应长度 (计 loss)
}

// 格式化 SFT 样本，返回 full_text 和 loss_mask_boundary (input_len)
func format_sft_sample(chat_conversation conv, template_config tmpl) sft_sample {
    // 构造两版: 带生成提示的版本 (获取 input_len) + 完整版本
    chat_conversation input_only = chat_conversation {
        messages: drop_last_assistant(conv.messages),
        add_generation_prompt: true,
        system_prompt: conv.system_prompt,
    }

    string prompt_text   = apply_chat_template(input_only, tmpl)
    string full_text     = apply_chat_template(conv, tmpl)

    int prompt_len = str_len(prompt_text)
    int full_len   = str_len(full_text)

    // loss_mask: 0 for prompt chars, 1 for response chars
    []int mask = []
    int i = 0
    for i < prompt_len {
        mask = append(mask, 0)
        i = i + 1
    }
    int j = prompt_len
    for j < full_len {
        mask = append(mask, 1)
        j = j + 1
    }

    sft_sample {
        full_text: full_text,
        loss_mask: mask,
        input_len: prompt_len,
        target_len: full_len - prompt_len,
    }
}

// 移除最后一条 assistant 消息 (若有), 返回剩余 messages
func drop_last_assistant([]chat_message msgs) []chat_message {
    int n = len(msgs)
    if n == 0 { return msgs }
    chat_message last = msgs[n-1]
    if last.role == "assistant" {
        []chat_message result = []
        int i = 0
        for i < n - 1 {
            result = append(result, msgs[i])
            i = i + 1
        }
        return result
    }
    msgs
}

// ============================================================================
// 5. 批量格式化
// ============================================================================

struct sft_batch {
    []string texts       // 批次文本
    [][]int  loss_masks  // 批次 loss mask
    int batch_size
}

func format_sft_batch([]chat_conversation convs, template_config tmpl) sft_batch {
    []string texts = []
    [][]int masks  = []
    int i = 0
    for i < len(convs) {
        sft_sample s = format_sft_sample(convs[i], tmpl)
        texts = append(texts, s.full_text)
        masks = append(masks, s.loss_mask)
        i = i + 1
    }
    sft_batch {
        texts: texts,
        loss_masks: masks,
        batch_size: len(convs),
    }
}

// ============================================================================
// 6. 特殊 Token 注册 (与 BPE tokenizer 对接)
// ============================================================================

struct special_tokens {
    string bos
    string eos
    string pad
    string unk
    string im_start    // ChatML
    string im_end      // ChatML
    string eot_id      // LLaMA-3
    string think_start // NeurX-R1
    string think_end   // NeurX-R1
    []string extra     // 自定义 special tokens
}

func chatml_special_tokens() special_tokens {
    special_tokens {
        bos: "<|endoftext|>",
        eos: "<|endoftext|>",
        pad: "<|endoftext|>",
        unk: "<|endoftext|>",
        im_start: "<|im_start|>",
        im_end: "<|im_end|>",
        eot_id: "",
        think_start: "",
        think_end: "",
        extra: [],
    }
}

func llama3_special_tokens() special_tokens {
    special_tokens {
        bos: "<|begin_of_text|>",
        eos: "<|end_of_text|>",
        pad: "<|finetune_right_pad_id|>",
        unk: "",
        im_start: "",
        im_end: "",
        eot_id: "<|eot_id|>",
        think_start: "",
        think_end: "",
        extra: ["<|start_header_id|>", "<|end_header_id|>"],
    }
}

func neurx_r1_special_tokens() special_tokens {
    special_tokens {
        bos: "<｜begin▁of▁sentence｜>",
        eos: "<｜end▁of▁sentence｜>",
        pad: "<｜end▁of▁sentence｜>",
        unk: "",
        im_start: "",
        im_end: "",
        eot_id: "",
        think_start: "<think>",
        think_end: "</think>",
        extra: ["<｜User｜>", "<｜Assistant｜>"],
    }
}

// ============================================================================
// 7. 字符串工具
// ============================================================================

func str_cat(string a, string b) string {
    // runtime 实现字符串拼接
    a
}

func str_len(string s) int {
    // runtime 实现
    0
}
