package neurx.posttrain.tools.data_preprocess
use neurx.tensor.{tensor}

struct conversation {
    []message messages
    string conversation_id
}

struct message {
    string role
    string content
    string[] tool_calls
}

struct rl_sample {
    string prompt
    string[] completions
    float[] rewards
    int group_id
    string task_type
}

struct preference_pair {
    string prompt
    string chosen
    string rejected
    float margin
}

func convert_conversation_to_prompt(conversation conv) string {
    string prompt = ""
    int i = 0
    for i < conv.messages.len {
        message msg = conv.messages[i]
        if msg.role == "system" {
            prompt = prompt + "System: " + msg.content + "\n"
        } else if msg.role == "user" {
            prompt = prompt + "User: " + msg.content + "\n"
        } else if msg.role == "assistant" {
            prompt = prompt + "Assistant: " + msg.content + "\n"
        }
        i = i + 1
    }
    prompt
}

func create_grpo_groups(
    string[] prompts,
    string[][] completions,
    float[][] rewards,
    int group_size
) []rl_sample {
    []rl_sample samples = []rl_sample{}
    int i = 0
    for i < prompts.len {
        int group_id = i / group_size
        rl_sample sample = rl_sample {
            prompt: prompts[i],
            completions: completions[i],
            rewards: rewards[i],
            group_id: group_id,
            task_type: "general",
        }
        samples[samples.len] = sample
        i = i + 1
    }
    samples
}

func create_preference_pairs_from_rankings(
    string prompt,
    string[] completions,
    float[] scores
) []preference_pair {
    []preference_pair pairs = []preference_pair{}
    int[] indices = argsort_descending(scores)
    int i = 0
    for i < completions.len {
        int j = i + 1
        for j < completions.len {
            int idx_i = indices[i]
            int idx_j = indices[j]
            preference_pair pair = preference_pair {
                prompt: prompt,
                chosen: completions[idx_i],
                rejected: completions[idx_j],
                margin: scores[idx_i] - scores[idx_j],
            }
            pairs[pairs.len] = pair
            j = j + 1
        }
        i = i + 1
    }
    pairs
}

func format_prompt_with_examples(
    string instruction,
    string[] examples,
    string query
) string {
    string prompt = instruction + "\n\n"
    int i = 0
    for i < examples.len {
        prompt = prompt + "Example " + int_to_string(i + 1) + ":\n"
        prompt = prompt + examples[i] + "\n\n"
        i = i + 1
    }
    prompt = prompt + "Query:\n" + query + "\n\n"
    prompt = prompt + "Response:\n"
    prompt
}

func extract_code_from_response(string response) string {
    if contains(response, "```") {
        int start = index_of(response, "```")
        int end = index_of_from(response, "```", start + 3)
        if end > start {
            string code_block = substring(response, start + 3, end)
            int newline = index_of(code_block, "\n")
            if newline > 0 {
                code_block = substring(code_block, newline + 1, code_block.len)
            }
            return code_block
        }
    }
    response
}

func tokenize_with_padding(
    string[] texts,
    int max_length,
    int pad_token_id
) int[][] {
    int[][] tokenized = int[][]{cap: texts.len}
    int i = 0
    for i < texts.len {
        int[] tokens = tokenize_text(texts[i])
        if tokens.len > max_length {
            int[] truncated = int[]{cap: max_length}
            int j = 0
            for j < max_length {
                truncated[j] = tokens[j]
                j = j + 1
            }
            tokens = truncated
        }
        for tokens.len < max_length {
            tokens[tokens.len] = pad_token_id
        }
        tokenized[i] = tokens
        i = i + 1
    }
    tokenized
}

func create_attention_masks(
    int[][] token_ids,
    int pad_token_id
) int[][] {
    int[][] masks = int[][]{cap: token_ids.len}
    int i = 0
    for i < token_ids.len {
        int[] mask = int[]{cap: token_ids[i].len}
        int j = 0
        for j < token_ids[i].len {
            if token_ids[i][j] == pad_token_id {
                mask[j] = 0
            } else {
                mask[j] = 1
            }
            j = j + 1
        }
        masks[i] = mask
        i = i + 1
    }
    masks
}

func batch_samples(
    []rl_sample samples,
    int batch_size
) [][]rl_sample {
    int num_batches = (samples.len + batch_size - 1) / batch_size
    [][]rl_sample batches = [][]rl_sample{cap: num_batches}
    int b = 0
    for b < num_batches {
        int start = b * batch_size
        int end = start + batch_size
        if end > samples.len {
            end = samples.len
        }
        []rl_sample batch = []rl_sample{cap: end - start}
        int i = start
        for i < end {
            batch[i - start] = samples[i]
            i = i + 1
        }
        batches[b] = batch
        b = b + 1
    }
    batches
}

func argsort_descending(float[] arr) int[] { int[]{} }

func int_to_string(int n) string { "" }

func contains(string s, string sub) bool { false }

func index_of(string s, string sub) int { 0 }

func index_of_from(string s, string sub, int from) int { 0 }

func substring(string s, int start, int end) string { s }

func tokenize_text(string text) int[] { int[]{} }
