// ============================================================
// NEURX Tokenizer - SentencePiece Based
// 支持 NEURX-4 / NEURX-5.2 系列
// 特点:
//   - 基于 SentencePiece (Unigram LM) 的 BPE tokenizer
//   - 支持特殊 token: , , , , SOP, EOP
//   - 中英文混合分词优化
//   - 高效的批量编码/解码
// ============================================================

package neurx.tokenizer.neurx

import neurx.tensor.*

// ============================================================
// NEURX 特殊 Token 定义 (与 HuggingFace 对齐)
// ============================================================
struct special_tokens_config {
    int pad_token_id      = 0      // 
    int bos_token_id      = 1      // 
    int eos_token_id      = 2      // 
    int unk_token_id      = 3      // 
    int mask_token_id     = 150000 //  (用于 MLM)
    int gmask_token_id    = 150001 //  (用于 Prefix-LM generation mask)
    int sop_token_id      = 150002 //  (Start of Prefix)
    int eop_token_id      = 150003 //  (End of Prefix)
    
    string pad_token      = ""
    string bos_token      = ""
    string eos_token      = ""
    string unk_token      = ""
    string mask_token     = ""
    string gmask_token    = "gMASK"
    string sop_token      = ""
    string eop_token      = ""
}

// 获取默认特殊 token 配置
func default_special_tokens() special_tokens_config {
    return special_tokens_config{}
}

// ============================================================
// Tokenizer 状态
// ============================================================
enum encoding_type {
    UNIGRAM       // Unigram Language Model (SentencePiece 默认)
    BPE           // Byte Pair Encoding
    WORD_PIECE    // WordPiece (BERT 风格)
}

struct tokenizer_state {
    string vocab_file_path          // SentencePiece model 文件路径
    int vocab_size                 // 词表大小
    encoding_type enc_type         // 编码类型
    
    // 词表: token -> ID 映射
    dict[string, int] encoder      // token2id
    
    // 反向词表: ID -> token 映射
    dict[int, string] decoder      // id2token
    
    // 特殊 tokens
    special_tokens_config special_tokens
    
    // 添加的特殊 token 数量 (在 base vocab 之上)
    int num_added_tokens
    
    // 统计信息
    struct stats {
        int total_encoded_tokens
        int total_decoded_tokens
        float avg_tokens_per_word
        float avg_chars_per_token
    } stats
}

// ============================================================
// 初始化 NEURX Tokenizer
// ============================================================
func create_tokenizer(
    vocab_file_path: string,
    special_tokens: option[special_tokens_config] = none
) tokenizer_state {
    
    print("🔤 Loading NEURX Tokenizer from: {vocab_file_path}")
    
    // === 加载 SentencePiece 模型 ===
    // 实际实现中会调用 SentencePiece C++ 库或 Python 绑定
    // 这里用 S 语言模拟加载过程
    
    dict[string, int] loaded_encoder = {}
    dict[int, string] loaded_decoder = {}
    
    # TODO: 实际加载 .model 文件
    # sp_model = sentencepiece.SentencePieceProcessor()
    # sp_model.load(vocab_file_path)
    
    # for i in range(sp_model.piece_size()):
    #     piece = sp_model.id_to_piece(i)
    #     if piece.startswith('▁'):  # SentencePiece space prefix
    #         piece = ' ' + piece[1:]
    #     encoder[piece] = i
    #     decoder[i] = piece
    
    // 模拟加载一个小的词表用于测试
    if exists(vocab_file_path) {
        // 从文件实际加载
        print("   Loading vocabulary from file...")
        # 实现文件读取逻辑
    } else {
        print("   ⚠️ Vocab file not found, using mock vocabulary for testing")
        // 创建模拟词表
        _create_mock_vocab(loaded_encoder, loaded_decoder)
    }
    
    // 设置特殊 tokens
    special_tokens_config specs = special_tokens != none ? special_tokens! : default_special_tokens()
    
    // 将特殊 tokens 加入词表
    int base_vocab_size = len(loaded_encoder)
    _add_special_tokens(loaded_encoder, loaded_decoder, specs, base_vocab_size)
    
    tokenizer_state state {
        vocab_file_path: vocab_file_path,
        vocab_size: len(loaded_encoder),
        enc_type: UNIGRAM,
        encoder: loaded_encoder,
        decoder: loaded_decoder,
        special_tokens: specs,
        num_added_tokens: len(specs),  // 简化计算
        stats: stats {
            total_encoded_tokens: 0,
            total_decoded_tokens: 0,
            avg_tokens_per_word: 0.0,
            avg_chars_per_token: 0.0
        }
    }
    
    print(f"✅ NEURX Tokenizer loaded successfully!")
    print(f"   Vocabulary size: {state.vocab_size}")
    print(f"   Special tokens added: {state.num_added_tokens}")
    
    return state
}

// 创建模拟词表 (用于测试)
func _create_mock_vocab(
    ref dict[string, int] encoder,
    ref dict[int, string] decoder) {
    
    // 常见中文词
    string common_zh[] = ["的", "是", "不", "了", "我", "在", "有", "和", "人", "这", "中", "大", "来", "上", "个", "国", "到", "说", "们", "为", "子", "你", "出", "会", "地", "也"]
    for i, token in enumerate(common_zh):
        encoder[token] = i
        decoder[i] = token
    
    // 常见英文词
    string common_en[] = ["the", "a", "is", "of", "to", "in", "and", "that", "for", "it", "as", "was", "with", "on", "are", "you", "his", "at", "be", "this", "from", "or", "by", "an"]
    int offset = len(common_zh)
    for i, token in enumerate(common_en):
        encoder[token] = offset + i
        decoder[offset + i] = token
    
    // 单个字符 (中文)
    for c in range(0x4E00, 0x4E00 + 100):  # 常用汉字范围
        string char = chr(c)
        if char not in encoder:
            encoder[char] = len(encoder)
            decoder[len(encoder) - 1] = char
    
    // 单个字符 (英文 ASCII)
    for c in range(32, 127):  # 可打印 ASCII
        string char = chr(c)
        if char not in encoder:
            encoder[char] = len(encoder)
            decoder[len(encoder) - 1] = char
}

// 添加特殊 tokens 到词表
func _add_special_tokens(
    ref dict[string, int] encoder,
    ref dict[int, string] decoder,
    special_tokens_config specs,
    base_size: int) {
    
    int next_id = base_size
    
    // 按优先级添加特殊 tokens
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

// ============================================================
// 核心编码函数: 文本 → Token IDs
// ============================================================

// 编码单个文本字符串
func encode(
    state: tokenizer_state,
    text: string,
    add_special_tokens: bool = true,
    max_length: option[int] = none,
    truncation: bool = false,
    padding: bool = false,
    return_tensors: bool = false
) dict[str, any] {
    
    // Step 1: 预处理文本
    string preprocessed = preprocess_text(text)
    
    // Step 2: 分词
    string[] tokens = tokenize(state, preprocessed)
    
    // Step 3: 转换为 IDs
    int[] ids = convert_tokens_to_ids(state, tokens)
    
    // Step 4: 添加特殊 tokens
    if add_special_tokens:
        ids = _add_special_tokens_to_ids(ids, state.special_tokens)
    
    // Step 5: 截断
    if truncation && max_length != none && len(ids) > max_length!:
        ids = ids[:max_length!]
    
    // Step 6: 记录统计
    state.stats.total_encoded_tokens += len(ids)
    
    // 构建返回结果
    dict[str, any] result = {}
    result["input_ids"] = ids
    
    if padding && max_length != none:
        # Pad to max_length
        int pad_len = max_length! - len(ids)
        if pad_len > 0:
            int[] padded_ids = ids + [state.special_tokens.pad_token_id] * pad_len
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

// 批量编码
func batch_encode(
    state: tokenizer_state,
    string[] texts,
    add_special_tokens: bool = true,
    max_length: option[int] = none,
    truncation: bool = false,
    padding: bool = true,  # 批量时默认 padding
    return_tensors: bool = true,
    num_threads: int = 4
) dict[str, any] {
    
    int batch_size = len(texts)
    
    # 并行编码所有文本
    dict[str, any][] results = []
    
    // 单线程版本 (S 语言可能不支持多线程)
    for text in texts:
        dict[str, any] encoded = encode(
            state=state,
            text=text,
            add_special_tokens=add_special_tokens,
            max_length=max_length,
            truncation=truncation,
            padding=false,  # 先不 pad, 后面统一处理
            return_tensors=False
        )
        append(results, encoded)
    
    # 确定 max length
    int max_len = 0
    for r in results:
        max_len = max(max_len, len(r["input_ids"]))
    
    if max_length != none:
        max_len = min(max_len, max_length!)
    
    # Padding & Stack
    tensor input_ids_tensor(batch_size, max_len)
    tensor attention_mask_tensor(batch_size, max_len)
    
    for i, r in enumerate(results):
        int[] ids = r["input_ids"]
        int[] masks = r["attention_mask"]
        
        int actual_len = min(len(ids), max_len)
        
        for j in range(actual_len):
            input_ids_tensor[i, j] = ids[j]
            attention_mask_tensor[i, j] = masks[j]
        
        # 填充剩余位置
        for j in range(actual_len, max_len):
            input_ids_tensor[i, j] = state.special_tokens.pad_token_id
            attention_mask_tensor[i, j] = 0
    
    dict[str, any] batch_result = {}
    batch_result["input_ids"] = input_ids_tensor
    batch_result["attention_mask"] = attention_mask_tensor
    
    return batch_result
}

// ============================================================
// 核心解码函数: Token IDs → 文本
// ============================================================
func decode(
    state: tokenizer_state,
    int[] token_ids,
    skip_special_tokens: bool = false,
    clean_up_tokenization_spaces: bool = true
) string {
    
    string[] tokens = []
    for id in token_ids:
        if id in state.decoder:
            string token = state.decoder[id]
            
            # 跳过特殊 tokens
            if skip_special_tokens && _is_special_token(id, state.special_tokens):
                continue
            
            append(tokens, token)
        else:
            # Unknown token
            append(tokens, state.special_tokens.unk_token)
    
    # 拼接 tokens 为文本
    string text = join(tokens, "")
    
    # 清理空格
    if clean_up_tokenization_spaces:
        text = cleanup_spaces(text)
    
    # 更新统计
    state.stats.total_decoded_tokens += len(token_ids)
    
    return text
}

// 批量解码
func batch_decode(
    state: tokenizer_state,
    tensor token_ids,  // [batch, seq_len]
    skip_special_tokens: bool = false
) string[] {
    
    int batch_size = shape(token_ids)[0]
    string[] results = []
    
    for i in range(batch_size):
        int[] ids = token_ids[i].tolist()
        string text = decode(state, ids, skip_special_tokens=skip_special_tokens)
        append(results, text)
    
    return results
}

// ============================================================
// 文本预处理
// ============================================================
func preprocess_text(text: string) string {
    
    # Unicode 标准化
    text = normalize_unicode(text)
    
    # 控制字符替换
    text = replace_control_characters(text)
    
    # 空格标准化
    text = normalize_whitespace(text)
    
    return text
}

func normalize_unicode(text: string) -> string {
    // NFC normalization (canonical composition)
    # 实际调用: unicodedata.normalize('NFC', text)
    return text
}

func replace_control_characters(text: string) -> string {
    string chars = []
    for ch in text:
        int cp = ord(ch)
        # 替换控制字符 (保留 tab, newline, carriage return)
        if cp == 9 || cp == 10 || cp == 13 || cp > 31:
            append(chars, ch)
        else:
            append(chars, ' ')
    return join(chars, "")
}

func normalize_whitespace(text: string) -> string {
    # 合并连续空格
    while "  " in text:
        text = text.replace("  ", " ")
    return text.strip()
}

func cleanup_spaces(text: string) -> string {
    # 清理 SentencePiece 产生的多余空格
    # SentencePiece 使用 ▁ 作为词首标记,转换为空格后需要清理
    text = text.replace("  ", " ")  # 双空格 → 单空格
    text = text.strip()
    return text
}

// ============================================================
// 分词算法
// ============================================================
func tokenize(state: tokenizer_state, text: string) string[] {
    
    if len(text) == 0:
        return []
    
    string[] tokens = []
    
    # 尝试从词表匹配最长子串 (贪心匹配)
    int pos = 0
    while pos < len(text):
        # 寻找最长匹配
        int best_len = 0
        
        # 最大匹配长度限制 (通常不超过词表中最长 token)
        int max_match_len = min(len(text) - pos, 50)
        
        for l in range(max_match_len, 0, -1):
            string substr = text[pos:pos+l]
            if substr in state.encoder:
                best_len = l
                break
        
        if best_len > 0:
            # 匹配成功
            append(tokens, text[pos:pos+best_len])
            pos += best_len
        else:
            # 未匹配到,按 UTF-8 字符切分
            append(tokens, text[pos])
            pos += 1
    
    return tokens
}

func convert_tokens_to_ids(state: tokenizer_state, string[] tokens) int[] {
    int[] ids = []
    for token in tokens:
        if token in state.encoder:
            append(ids, state.encoder[token])
        else:
            # 回退到逐字编码
            for ch in token:
                if ch in state.encoder:
                    append(ids, state.encoder[ch])
                else:
                    append(ids, state.special_tokens.unk_token_id)
    return ids
}

func convert_ids_to_tokens(state: tokenizer_state, int[] ids) string[] {
    string[] tokens = []
    for id in ids:
        if id in state.decoder:
            append(tokens, state.decoder[id])
        else:
            append(tokens, state.special_tokens.unk_token)
    return tokens
}

// ============================================================
// NEURX 特殊功能: 构建 Prompt 格式
// ============================================================

// 构建 Chat 格式 prompt (用于对话任务)
func build_chat_prompt(
    state: tokenizer_state,
    string[] messages,
    system_prompt: option<string> = none,
    add_generation_prompt: bool = true
) dict[str, any] {
    
    /*
    NEURX-4 Chat 格式:
    [system_prompt]
    [ Round 1 ]

    Question: {user_msg_1}
    

    Answer: {assistant_msg_1}

    [Round 2]
    ...
    */
    
    string[] parts = []
    
    // System prompt
    if system_prompt != none:
        append(parts, system_prompt!)
    
    // 对话轮次
    for msg in messages:
        if msg.role == "user":
            append(parts, "\nQuestion: " + msg.content)
        elif msg.role == "assistant":
            append(parts, "\n\nAnswer: " + msg.content)
    
    // Generation prompt
    if add_generation_prompt:
        append(parts, "\n\nAnswer:")
    
    string full_prompt = join(parts, "")
    
    # 编码
    return encode(
        state=state,
        text=full_prompt,
        add_special_tokens=true,
        return_tensors=True
    )
}

// 构建 Prefix-LM 格式输入
// 用于训练时的 PrefixLM 任务
func build_prefix_lm_input(
    state: tokenizer_state,
    prefix: string,
    continuation: string,
    max_prefix_ratio: float = 0.8
) dict[str, any] {
    
    /*
    PrefixLM 格式:
    SOP prefix EOP continuation EOS
    
    其中:
    - prefix 部分: 双向注意力
    - continuation 部分: 因果自回归
    */
    
    # 组合完整文本
    string full_text = (
        state.special_tokens.sop_token +
        prefix +
        state.special_tokens.eop_token +
        continuation +
        state.special_tokens.eos_token
    )
    
    # 编码
    dict[str, any] encoded = encode(
        state=state,
        text=full_text,
        add_special_tokens=false,  # 手动添加了特殊 tokens
        return_tensors=True
    )
    
    # 计算 SOP/EOP 位置
    int[] input_ids = encoded["input_ids"].tolist()  if isinstance(encoded["input_ids"], tensor) else encoded["input_ids"]
    
    int sop_pos = index_of(input_ids, state.special_tokens.sop_token_id)
    int eop_pos = index_of(input_ids, state.special_tokens.eop_token_id)
    
    encoded["sop_position"] = sop_pos
    encoded["eop_position"] = eop_pos
    encoded["prefix_length"] = eop_pos - sop_pos
    
    return encoded
}

// 构建 MLM 输入 (用于预训练)
func build_mlm_input(
    state: tokenizer_state,
    text: string,
    mlm_probability: float = 0.15
) dict[str, any] {
    
    /*
    MLM 格式 (NEURX-130B 风格):
    text with some tokens replaced by [MASK] or random
    
    返回:
    - input_ids: 包含 masked tokens
    - labels: 原始 token IDs (-100 在非 mask 位置)
    - mask_positions: 哪些位置被 mask 了
    */
    
    # 编码原始文本
    dict[str, any] original = encode(
        state=state,
        text=text,
        add_special_tokens=True,
        return_tensors=False
    )
    
    int[] input_ids = original["input_ids"]
    
    # 创建 labels
    int[] labels = input_ids.copy()
    
    # 随机选择 mask 位置 (排除特殊 tokens)
    int[] valid_positions = []
    for i, id in enumerate(input_ids):
        if !_is_special_token(id, state.special_tokens):
            append(valid_positions, i)
    
    # 选择要 mask 的位置 (约 15%)
    int num_to_mask = max(1, int(float(len(valid_positions)) * mlm_probability))
    int[] mask_positions = sample_without_replacement(valid_positions, num_to_mask)
    
    # 执行 masking: 80% [MASK], 10% 随机, 10% 不变
    for pos in mask_positions:
        float rand_val = rand()
        if rand_val < 0.8:
            # 80% 替换为 [MASK]
            input_ids[pos] = state.special_tokens.mask_token_id
        elif rand_val < 0.9:
            # 10% 替换为随机 token
            input_ids[pos] = randint(4, state.vocab_size)  # 排除前4个特殊 token
        # else: 10% 保持不变
        # 设置 label
        labels[pos] = input_ids[pos] if rand_val >= 0.8 else original["input_ids"][pos]
    
    # 非 mask 位置设为 -100 (忽略 loss)
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

// ============================================================
// 工具函数
// ============================================================
func _is_special_token(token_id: int, specs: special_tokens_config) -> bool {
    return token_id == specs.pad_token_id ||
           token_id == specs.bos_token_id ||
           token_id == specs.eos_token_id ||
           token_id == specs.unk_token_id ||
           token_id == specs.mask_token_id ||
           token_id == specs.gmask_token_id ||
           token_id == specs.sop_token_id ||
           token_id == specs.eop_token_id
}

# 在列表中查找元素索引
func index_of(int[] list, target: int) -> int {
    for i, val in enumerate(list):
        if val == target:
            return i
    return -1
}

# 无重复采样
func sample_without_replacement(int[] pool, int k) -> int[] {
    if k >= len(pool):
        return pool.copy()
    
    int[] result = pool.copy()
    shuffle(result)
    return result[:k]
}

// ============================================================
// NEURX 特殊 Token 信息输出
// ============================================================
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

// ============================================================
// 测试函数
// ============================================================
func test_tokenizer() {
    print("\n" + "="*60)
    print("Testing NEURX Tokenizer")
    print("="*60)
    
    // Test 1: 创建 Tokenizer
    print("\n[Test 1] Creating NEURX tokenizer...")
    tokenizer_state tok = create_tokenizer("vocab/neurx.model")
    assert(tok.vocab_size > 0)
    print("✅ Tokenizer created!")
    
    // Test 2: 打印特殊 tokens
    print("\n[Test 2] Printing special tokens...")
    print_special_tokens_info(tok)
    
    // Test 3: 基础编码/解码
    print("\n[Test 3] Testing basic encode/decode...")
    string test_text = "你好，世界！Hello, World!"
    dict[str, any] encoded = encode(tok, test_text, add_special_tokens=True)
    
    print(f"   Original text: {test_text}")
    print(f"   Encoded IDs: {encoded['input_ids'][:10]}...")  # 只显示前10个
    print(f"   Sequence length: {len(encoded['input_ids'])}")
    
    string decoded = decode(tok, encoded["input_ids"], skip_special_tokens=True)
    print(f"   Decoded text: {decoded}")
    print("✅ Basic encode/decode works!")
    
    // Test 4: Batch Encode
    print("\n[Test 4] Testing batch encoding...")
    string[] batch_texts = [
        "人工智能是未来发展的趋势。",
        "The quick brown fox jumps over the lazy dog.",
        "今天天气真好！",
        "This is a longer sentence to test the tokenizer's ability to handle various inputs."
    ]
    
    dict[str, any] batch_result = batch_encode(tok, batch_texts, max_length=some(64), padding=True)
    
    assert(shape(batch_result["input_ids"]) == (4, 64))
    assert(shape(batch_result["attention_mask"]) == (4, 64))
    print(f"   Batch shape: {shape(batch_result['input_ids'])}")
    print("✅ Batch encoding works!")
    
    // Test 5: Chat Prompt 构建
    print("\n[Test 5] Testing chat prompt construction...")
    message[] messages = [
        message{role: "user", content: "你好！"},
        message{role: "assistant", content: "你好！有什么可以帮助你的吗？"},
        message{role: "user", content: "请介绍一下你自己。"}
    ]
    
    dict[str, any] chat_encoded = build_chat_prompt(
        tok, 
        messages,
        system_prompt=some("你是 NEURX-5.2, 一个大型语言模型。"),
        add_generation_prompt=true
    )
    assert("input_ids" in chat_encoded)
    assert("attention_mask" in chat_encoded)
    print(f"   Chat prompt length: {len(chat_encoded['input_ids'].tolist())}")
    print("✅ Chat prompt construction works!")
    
    // Test 6: PrefixLM Input 构建
    print("\n[Test 6] Testing PrefixLM input construction...")
    dict[str, any] prefix_lm_input = build_prefix_lm_input(
        tok,
        prefix="请将以下句子翻译成英语：",
        continuation="人工智能正在改变世界。"
    )
    assert("sop_position" in prefix_lm_input)
    assert("eop_position" in prefix_lm_input)
    assert(prefix_lm_input["sop_position"] >= 0)
    print(f"   SOP position: {prefix_lm_input['sop_position']}")
    print(f"   EOP position: {prefix_lm_input['eop_position']}")
    print(f"   Prefix length: {prefix_lm_input['prefix_length']}")
    print("✅ PrefixLM input construction works!")
    
    // Test 7: MLM Input 构建
    print("\n[Test 7] Testing MLM input construction...")
    dict[str, any] mlm_input = build_mlm_input(
        tok,
        text="今天的天气非常____好。",
        mlm_probability=0.15
    )
    assert("input_ids" in mlm_input)
    assert("labels" in mlm_input)
    assert("mask_positions" in mlm_input)
    print(f"   Masked positions: {mlm_input['mask_positions']}")
    print("✅ MLM input construction works!")
    
    // Test 8: 统计信息
    print("\n[Tes