package main
use neurx.inference.tokenizer.hf_bpe_tokenizer.{hf_bpe_tokenizer, hf_bpe_result, hf_bpe_decode_result, hf_bpe_offset_result, load_hf_bpe_tokenizer, hf_bpe_encode, hf_bpe_decode, hf_bpe_encode_bytelevel_offsets}
use neurx.models.formats.safetensors_embedding.{st_f16_le, st_bf16_le}

func main() {
    hf_bpe_tokenizer tokenizer = load_hf_bpe_tokenizer("test/fixture/gateway_model")
    if !tokenizer.valid || tokenizer.vocab_count != 6 || tokenizer.merge_count != 2 || !tokenizer.byte_level || tokenizer.added_count != 1 { return 1 }
    hf_bpe_result result = hf_bpe_encode(tokenizer, "Hi", 8)
    if !result.ok || len(result.token_ids) != 1 || result.token_ids[0] != 3 { return 1 }
    result = hf_bpe_encode(tokenizer, " H", 8)
    if !result.ok || len(result.token_ids) != 1 || result.token_ids[0] != 5 { return 1 }
    hf_bpe_offset_result offsets = hf_bpe_encode_bytelevel_offsets(tokenizer, " H", 8)
    if !offsets.ok || len(offsets.token_ids) != 1 || offsets.token_ids[0] != 5 || offsets.start_offsets[0] != 1 || offsets.end_offsets[0] != 2 { return 1 }
    result = hf_bpe_encode(tokenizer, "<s>", 8)
    if !result.ok || len(result.token_ids) != 1 || result.token_ids[0] != 6 { return 1 }
    result = hf_bpe_encode(tokenizer, "Hi<s> H", 8)
    if !result.ok || len(result.token_ids) != 3 || result.token_ids[0] != 3 || result.token_ids[1] != 6 || result.token_ids[2] != 5 { return 1 }
    hf_bpe_decode_result decoded = hf_bpe_decode(tokenizer, result.token_ids)
    if !decoded.ok || decoded.text != "Hi<s> H" { return 1 }
    hf_bpe_tokenizer bert = load_hf_bpe_tokenizer("test/fixture/hf_tokenizers/bert")
    if !bert.valid || !bert.bert_pre_tokenizer || !bert.normalizer_lowercase || !bert.normalizer_strip { return 1 }
    result = hf_bpe_encode(bert, "  Hi!  ", 8)
    if !result.ok || len(result.token_ids) != 2 || result.token_ids[0] != 3 || result.token_ids[1] != 4 { return 1 }
    string normalized_input = "  " + string(239) + string(188) + string(168) + string(195) + string(173) + "!  "
    result = hf_bpe_encode(bert, normalized_input, 8)
    if !result.ok || len(result.token_ids) != 2 || result.token_ids[0] != 3 || result.token_ids[1] != 4 { return 1 }
    hf_bpe_tokenizer metaspace = load_hf_bpe_tokenizer("test/fixture/hf_tokenizers/metaspace")
    if !metaspace.valid || !metaspace.metaspace_pre_tokenizer { return 1 }
    result = hf_bpe_encode(metaspace, "Hi Hi", 8)
    if !result.ok || len(result.token_ids) != 2 || result.token_ids[0] != 5 || result.token_ids[1] != 5 { return 1 }
    decoded = hf_bpe_decode(metaspace, result.token_ids)
    if !decoded.ok || decoded.text != "Hi Hi" { return 1 }
    []int f16 = []int{cap: 2}
    f16[0] = 0
    f16[1] = 60
    if st_f16_le(f16, 0) != 1.0 { return 1 }
    []int bf16 = []int{cap: 2}
    bf16[0] = 128
    bf16[1] = 63
    if st_bf16_le(bf16, 0) != 1.0 { return 1 }
    println("PASS pure S HF tokenizer pipeline and F16 BF16 contract")
    0
}
