package neurx.tokenizer.chat_template

struct chat_message {
    string role
    string content
    string name
}

struct chat_conversation {
    []chat_message messages
    bool add_generation_prompt
    string system_prompt
}

func new_conversation([]chat_message msgs, bool gen_prompt) chat_conversation {
    chat_conversation {
        messages: msgs,
        add_generation_prompt: gen_prompt,
        system_prompt: "",
    }
}

struct template_config {
    string format
    string system_token
    string user_token
    string assistant_token
    string end_token
    string bos_token
    string eos_token
    string nl
    bool add_bos
    bool add_eos_turn
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

func apply_chat_template(chat_conversation conv, template_config tmpl) string {
    string result = ""
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
        if is_first && str_len(default_system) > 0 {
            result = str_cat(result, format_system(default_system, tmpl))
        }
        return str_cat(result, format_user(content, tmpl))
    }
    if msg.role == "assistant" {
        return format_assistant(content, tmpl, true)
    }
    format_tool(msg.name, content, tmpl)
}

func format_system(string content, template_config tmpl) string {
    if tmpl.format == "chatml" {
        string r = str_cat(tmpl.system_token, tmpl.nl)
        r = str_cat(r, content)
        r = str_cat(r, tmpl.end_token)
        return str_cat(r, tmpl.nl)
    }
    if tmpl.format == "llama2" {
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
        return str_cat(content, tmpl.nl)
    }
    if tmpl.format == "gemma" {
        return format_user(content, tmpl)
    }
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
    string r = str_cat(tmpl.user_token, content)
    str_cat(r, tmpl.nl)
}

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
    string r = str_cat(tmpl.assistant_token, content)
    if add_eos {
        r = str_cat(r, tmpl.eos_token)
    }
    str_cat(r, tmpl.nl)
}

func format_tool(string name, string content, template_config tmpl) string {
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
    tmpl.assistant_token
}

struct sft_sample {
    string full_text
    []int  loss_mask
    int    input_len
    int    target_len
}

func format_sft_sample(chat_conversation conv, template_config tmpl) sft_sample {
    chat_conversation input_only = chat_conversation {
        messages: drop_last_assistant(conv.messages),
        add_generation_prompt: true,
        system_prompt: conv.system_prompt,
    }
    string prompt_text   = apply_chat_template(input_only, tmpl)
    string full_text     = apply_chat_template(conv, tmpl)
    int prompt_len = str_len(prompt_text)
    int full_len   = str_len(full_text)
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

struct sft_batch {
    []string texts
    [][]int  loss_masks
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

struct special_tokens {
    string bos
    string eos
    string pad
    string unk
    string im_start
    string im_end
    string eot_id
    string think_start
    string think_end
    []string extra
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

func str_cat(string a, string b) string {
    a
}

func str_len(string s) int {
    0
}
