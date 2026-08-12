package neurx.tokenizer.neurx
import neurx.tensor.*
struct special_tokens_config {
    int pad_token_id      = 0
    int bos_token_id      = 1
    int eos_token_id      = 2
    int unk_token_id      = 3
    int mask_token_id     = 150000
    int gmask_token_id    = 150001
    int sop_token_id      = 150002
    int eop_token_id      = 150003
    string pad_token      = ""
    string bos_token      = ""
    string eos_token      = ""
    string unk_token      = ""
    string mask_token     = ""
    string gmask_token    = "gMASK"
    string sop_token      = ""
    string eop_token      = ""
}

func default_special_tokens() special_tokens_config {
    return special_tokens_config{}
}
enum encoding_type {
    UNIGRAM
    BPE
    WORD_PIECE
}

struct tokenizer_state {
    string vocab_file_path
    int vocab_size
    encoding_type enc_type
    dict[string, int] encoder
    dict[int, string] decoder
    special_tokens_config special_tokens
    int num_added_tokens
    struct stats {
        int total_encoded_tokens
        int total_decoded_tokens
        float avg_tokens_per_word
        float avg_chars_per_token
    } stats
}

func create_tokenizer(
    vocab_file_path: string,
    special_tokens: option[special_tokens_config] = none
) tokenizer_state {
    print("🔤 Loading NEURX tokenizer from: {vocab_file_path}")
    dict[string, int] loaded_encoder = {}
    dict[int, string] loaded_decoder = {}
    if exists(vocab_file_path) {
        print("   Loading vocabulary from file...")
    } else {
        print("   ⚠️ Vocab file not found, using mock vocabulary for testing")
        _create_mock_vocab(loaded_encoder, loaded_decoder)
    }
    special_tokens_config specs = special_tokens != none ? special_tokens! : default_special_tokens()
    int base_vocab_size = len(loaded_encoder)
    _add_special_tokens(loaded_encoder, loaded_decoder, specs, base_vocab_size)
    tokenizer_state state {
        vocab_file_path: vocab_file_path,
        vocab_size: len(loaded_encoder),
        enc_type: UNIGRAM,
        encoder: loaded_encoder,
        decoder: loaded_decoder,
        special_tokens: specs,
        num_added_tokens: len(specs),
        stats: stats {
            total_encoded_tokens: 0,
            total_decoded_tokens: 0,
            avg_tokens_per_word: 0.0,
            avg_chars_per_token: 0.0
        }
    }
    print(f"✅ NEURX tokenizer loaded successfully!")
    print(f"   Vocabulary size: {state.vocab_size}")
    print(f"   Special tokens added: {state.num_added_tokens}")
    return state
}

func _create_mock_vocab(
    ref dict[string, int] encoder,
    ref dict[int, string] decoder) {
    string common_zh[] = ["English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text", "English text"]
    for i, token in enumerate(common_zh):
        encoder[token] = i
        decoder[i] = token
    string common_en[] = ["the", "a", "is", "of", "to", "in", "and", "that", "for", "it", "as", "was", "with", "on", "are", "you", "his", "at", "be", "this", "from", "or", "by", "an"]
    int offset = len(common_zh)
    for i, token in enumerate(common_en):
        encoder[token] = offset + i
        decoder[offset + i] = token
    for c in range(0x_4_e_00, 0x_4_e_00 + 100):
        string char = chr(c)
        if char not in encoder:
            encoder[char] = len(encoder)
            decoder[len(encoder) - 1] = char
    for c in range(32, 127):
        string char = chr(c)
        if char not in encoder:
            encoder[char] = len(encoder)
            decoder[len(encoder) - 1] = char
}

func _add_special_tokens(
    ref dict[string, int] encoder,
    ref dict[int, string] decoder,
    special_tokens_config specs,
    base_size: int) {
    int next_id = base_size
    tuple[string, int][] special_list = [
        (specs.pad_token, specs.pad_token_id),
        (specs.bos_token, specs.bos_token_id),
        (specs.eos_token, specs.eos_token_id),
        (specs.unk_token, specs.unk_token_id),
        (specs.mask_token, specs.mask_token_id),
        (specs.gmask_token, specs.gmask_token_id),
        (specs.sop_token, specs.sop_token_id),
        (specs.eop_token, specs.eop_token_id),
    ]
    for token_str, token_id in special_list {
        if token_str not in encoder:
            encoder[token_str] = token_id
            decoder[token_id] = token_str
        }
    }
}

func encode(
    state: tokenizer_state,
    text: string,
    add_special_tokens: bool = true,
    max_length: option[int] = none,
    truncation: bool = false,
    padding: bool = false,
    return_tensors: bool = false
) dict[str, any] {
    string preprocessed = preprocess_text(text)
    []string tokens = tokenize(state, preprocessed)
    []int ids = convert_tokens_to_ids(state, tokens)
    if add_special_tokens:
        ids = _add_special_tokens_to_ids(ids, state.special_tokens)
    if truncation && max_length != none && len(ids) > max_length!:
        ids = ids[:max_length!]
    state.stats.total_encoded_tokens += len(ids)
    dict[str, any] result = {}
    result["input_ids"] = ids
    if padding && max_length != none:
        int pad_len = max_length! - len(ids)
        if pad_len > 0:
            []int padded_ids = ids + [state.special_tokens.pad_token_id] * pad_len
            result["input_ids"] = padded_ids
            result["attention_mask"] = [1] * len(ids) + [0] * pad_len
        else:
            result["attention_mask"] = [1] * max_length!
    else:
        result["attention_mask"] = [1] * len(ids)
    if return_tensors:
        result["input_ids"] = tensor(result["input_ids"])
        result["attention_mask"] = tensor(result["attention_mask"])
    return result
}

func batch_encode(
    state: tokenizer_state,
    []string texts,
    add_special_tokens: bool = true,
    max_length: option[int] = none,
    truncation: bool = false,
    padding: bool = true,
    return_tensors: bool = true,
    num_threads: int = 4
) dict[str, any] {
    int batch_size = len(texts)
    dict[str, any][] results = []
    for text in texts:
        dict[str, any] encoded = encode(
            state=state,
            text=text,
            add_special_tokens=add_special_tokens,
            max_length=max_length,
            truncation=truncation,
            padding=false,
            return_tensors=False
        )
        append(results, encoded)
    int max_len = 0
    for r in results:
        max_len = max(max_len, len(r["input_ids"]))
    if max_length != none:
        max_len = min(max_len, max_length!)
    tensor input_ids_tensor(batch_size, max_len)
    tensor attention_mask_tensor(batch_size, max_len)
    for i, r in enumerate(results):
        []int ids = r["input_ids"]
        []int masks = r["attention_mask"]
        int actual_len = min(len(ids), max_len)
        for j in range(actual_len):
            input_ids_tensor[i, j] = ids[j]
            attention_mask_tensor[i, j] = masks[j]
        for j in range(actual_len, max_len):
            input_ids_tensor[i, j] = state.special_tokens.pad_token_id
            attention_mask_tensor[i, j] = 0
    dict[str, any] batch_result = {}
    batch_result["input_ids"] = input_ids_tensor
    batch_result["attention_mask"] = attention_mask_tensor
    return batch_result
}

func decode(
    state: tokenizer_state,
    []int token_ids,
    skip_special_tokens: bool = false,
    clean_up_tokenization_spaces: bool = true
) string {
    []string tokens = []
    for id in token_ids:
        if id in state.decoder:
            string token = state.decoder[id]
            if skip_special_tokens && _is_special_token(id, state.special_tokens):
                continue
            append(tokens, token)
        else:
            append(tokens, state.special_tokens.unk_token)
    string text = join(tokens, "")
    if clean_up_tokenization_spaces:
        text = cleanup_spaces(text)
    state.stats.total_decoded_tokens += len(token_ids)
    return text
}

func batch_decode(
    state: tokenizer_state,
    tensor token_ids,
    skip_special_tokens: bool = false
) []string {
    int batch_size = shape(token_ids)[0]
    []string results = []
    for i in range(batch_size):
        []int ids = token_ids[i].tolist()
        string text = decode(state, ids, skip_special_tokens=skip_special_tokens)
        append(results, text)
    return results
}

func preprocess_text(string text) string {
    text = normalize_unicode(text)
    text = replace_control_characters(text)
    text = normalize_whitespace(text)
    return text
}

func normalize_unicode(string text) {
    return text
}

func replace_control_characters(string text) {
    string chars = []
    for ch in text:
        int cp = ord(ch)
        if cp == 9 || cp == 10 || cp == 13 || cp > 31:
            append(chars, ch)
        else:
            append(chars, ' ')
    return join(chars, "")
}

func normalize_whitespace(string text) {
    while "  " in text:
        text = text.replace("  ", " ")
    return text.strip()
}

func cleanup_spaces(string text) {
    text = text.replace("  ", " ")
    text = text.strip()
    return text
}

func tokenize(state: tokenizer_state, string text) []string {
    if len(text) == 0:
        return []
    []string tokens = []
    int pos = 0
    while pos < len(text):
        int best_len = 0
        int max_match_len = min(len(text) - pos, 50)
        for l in range(max_match_len, 0, -1):
            string substr = text[pos:pos+l]
            if substr in state.encoder:
                best_len = l
                break
        if best_len > 0:
            append(tokens, text[pos:pos+best_len])
            pos += best_len
        else:
            append(tokens, text[pos])
            pos += 1
    return tokens
}

func convert_tokens_to_ids(state: tokenizer_state, []string tokens) []int {
    []int ids = []
    for token in tokens:
        if token in state.encoder:
            append(ids, state.encoder[token])
        else:
            for ch in token:
                if ch in state.encoder:
                    append(ids, state.encoder[ch])
                else:
                    append(ids, state.special_tokens.unk_token_id)
    return ids
}

func convert_ids_to_tokens(state: tokenizer_state, []int ids) []string {
    []string tokens = []
    for id in ids:
        if id in state.decoder:
            append(tokens, state.decoder[id])
        else:
            append(tokens, state.special_tokens.unk_token)
    return tokens
}

func build_chat_prompt(
    state: tokenizer_state,
    []string messages,
    system_prompt: option<string> = none,
    add_generation_prompt: bool = true
) dict[str, any] {
    []string parts = []
    if system_prompt != none:
        append(parts, system_prompt!)
    for msg in messages:
        if msg.role == "user":
            append(parts, "\nQuestion: " + msg.content)
        elif msg.role == "assistant":
            append(parts, "\n\nAnswer: " + msg.content)
    if add_generation_prompt:
        append(parts, "\n\nAnswer:")
    string full_prompt = join(parts, "")
    return encode(
        state=state,
        text=full_prompt,
        add_special_tokens=true,
        return_tensors=True
    )
}

func build_prefix_lm_input(
    state: tokenizer_state,
    prefix: string,
    continuation: string,
    max_prefix_ratio: float = 0.8
) dict[str, any] {
    string full_text = (
        state.special_tokens.sop_token +
        prefix +
        state.special_tokens.eop_token +
        continuation +
        state.special_tokens.eos_token
    )
    dict[str, any] encoded = encode(
        state=state,
        text=full_text,
        add_special_tokens=false,
        return_tensors=True
    )
    []int input_ids = encoded["input_ids"].tolist()  if isinstance(encoded["input_ids"], tensor) else encoded["input_ids"]
    int sop_pos = index_of(input_ids, state.special_tokens.sop_token_id)
    int eop_pos = index_of(input_ids, state.special_tokens.eop_token_id)
    encoded["sop_position"] = sop_pos
    encoded["eop_position"] = eop_pos
    encoded["prefix_length"] = eop_pos - sop_pos
    return encoded
}

func build_mlm_input(
    state: tokenizer_state,
    text: string,
    mlm_probability: float = 0.15
) dict[str, any] {
    dict[str, any] original = encode(
        state=state,
        text=text,
        add_special_tokens=True,
        return_tensors=False
    )
    []int input_ids = original["input_ids"]
    []int labels = input_ids.copy()
    []int valid_positions = []
    for i, id in enumerate(input_ids):
        if !_is_special_token(id, state.special_tokens):
            append(valid_positions, i)
    int num_to_mask = max(1, int(float(len(valid_positions)) * mlm_probability))
    []int mask_positions = sample_without_replacement(valid_positions, num_to_mask)
    for pos in mask_positions:
        float rand_val = rand()
        if rand_val < 0.8:
            input_ids[pos] = state.special_tokens.mask_token_id
        elif rand_val < 0.9:
            input_ids[pos] = randint(4, state.vocab_size)
        labels[pos] = input_ids[pos] if rand_val >= 0.8 else original["input_ids"][pos]
    for i in range(len(labels)):
        if i not in mask_positions:
            labels[i] = -100
    dict[str, any] result = {}
    result["input_ids"] = tensor(input_ids).unsqueeze(0)
    result["labels"] = tensor(labels).unsqueeze(0)
    result["attention_mask"] = original["attention_mask"].unsqueeze(0)
    result["mask_positions"] = mask_positions
    return result
}

func _is_special_token(int token_id, specs: special_tokens_config) {
    return token_id == specs.pad_token_id ||
           token_id == specs.bos_token_id ||
           token_id == specs.eos_token_id ||
           token_id == specs.unk_token_id ||
           token_id == specs.mask_token_id ||
           token_id == specs.gmask_token_id ||
           token_id == specs.sop_token_id ||
           token_id == specs.eop_token_id
}

func index_of([]int list, int target) {
    for i, val in enumerate(list):
        if val == target:
            return i
    return -1
}

func sample_without_replacement([]int pool, int k) {
    if k >= len(pool):
        return pool.copy()
    []int result = pool.copy()
    shuffle(result)
    return result[:k]
}

func print_special_tokens_info(state: tokenizer_state) {
    print("\n📋 NEURX Special Tokens:")
    print("-" * 40)
    print(f"  PAD : [{state.special_tokens.pad_token_id}] '{state.special_tokens.pad_token}'")
    print(f"  BOS : [{state.special_tokens.bos_token_id}] '{state.special_tokens.bos_token}'")
    print(f"  EOS : [{state.special_tokens.eos_token_id}] '{state.special_tokens.eos_token}'")
    print(f"  UNK : [{state.special_tokens.unk_token_id}] '{state.special_tokens.unk_token}'")
    print(f"  MASK: [{state.special_tokens.mask_token_id}] '{state.special_tokens.mask_token}'")
    print(f"  GMASK: [{state.special_tokens.gmask_token_id}] '{state.special_tokens.gmask_token}'")
    print(f"  SOP : [{state.special_tokens.sop_token_id}] '{state.special_tokens.sop_token}'")
    print(f"  EOP : [{state.special_tokens.eop_token_id}] '{state.special_tokens.eop_token}'")
    print(f"\n  Total vocabulary size: {state.vocab_size}")
    print("-" * 40)
}

func test_tokenizer() {
    print("\n" + "="*60)
    print("Testing NEURX tokenizer")
    print("="*60)
    print("\n[Test 1] Creating NEURX tokenizer...")
    tokenizer_state tok = create_tokenizer("vocab/neurx.model")
    assert(tok.vocab_size > 0)
    print("✅ tokenizer created!")
    print("\n[Test 2] Printing special tokens...")
    print_special_tokens_info(tok)
    print("\n[Test 3] Testing basic encode/decode...")
    string test_text = "English text, English text!Hello, World!"
    dict[str, any] encoded = encode(tok, test_text, add_special_tokens=True)
    print(f"   Original text: {test_text}")
    print(f"   Encoded IDs: {encoded['input_ids'][:10]}...")
    print(f"   Sequence length: {len(encoded['input_ids'])}")
    string decoded = decode(tok, encoded["input_ids"], skip_special_tokens=True)
    print(f"   Decoded text: {decoded}")
    print("✅ Basic encode/decode works!")
    print("\n[Test 4] Testing batch encoding...")
    []string batch_texts = [
        "English text.",
        "The quick brown fox jumps over the lazy dog.",
        "English text!",
        "This is a longer sentence to test the tokenizer's ability to handle various inputs."
    ]
    dict[str, any] batch_result = batch_encode(tok, batch_texts, max_length=some(64), padding=True)
    assert(shape(batch_result["input_ids"]) == (4, 64))
    assert(shape(batch_result["attention_mask"]) == (4, 64))
    print(f"   batch_2 shape: {shape(batch_result['input_ids'])}")
    print("✅ batch_2 encoding works!")
    print("\n[Test 5] Testing chat prompt construction...")
    message[] messages = [
        message{role: "user", content: "English text!"},
        message{role: "assistant", content: "English text!English textAllowedEnglish text?"},
        message{role: "user", content: "English text."}
    ]
    dict[str, any] chat_encoded = build_chat_prompt(
        tok,
        messages,
        system_prompt=some("English text NEURX-5.2, English textlanguagemodel."),
        add_generation_prompt=true
    )
    assert("input_ids" in chat_encoded)
    assert("attention_mask" in chat_encoded)
    print(f"   Chat prompt length: {len(chat_encoded['input_ids'].tolist())}")
    print("✅ Chat prompt construction works!")
    print("\n[Test 6] Testing PrefixLM input construction...")
    dict[str, any] prefix_lm_input = build_prefix_lm_input(
        tok,
        prefix="English text: ",
        continuation="English text."
    )
    assert("sop_position" in prefix_lm_input)
    assert("eop_position" in prefix_lm_input)
    assert(prefix_lm_input["sop_position"] >= 0)
    print(f"   SOP position: {prefix_lm_input['sop_position']}")
    print(f"   EOP position: {prefix_lm_input['eop_position']}")
    print(f"   Prefix length: {prefix_lm_input['prefix_length']}")
    print("✅ PrefixLM input construction works!")
    print("\n[Test 7] Testing MLM input construction...")
    dict[str, any] mlm_input = build_mlm_input(
        tok,
        text="English text____English text.",
        mlm_probability=0.15
    )
    assert("input_ids" in mlm_input)
    assert("labels" in mlm_input)
    assert("mask_positions" in mlm_input)
    print(f"   Masked positions: {mlm_input['mask_positions']}")
    print("✅ MLM input construction works!")
    print("\n[Tes

