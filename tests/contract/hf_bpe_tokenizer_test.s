package main
use neurx.inference.tokenizer.hf_bpe_tokenizer.{hf_bpe_tokenizer, hf_bpe_result, load_hf_bpe_tokenizer, hf_bpe_encode}
use neurx.models.formats.safetensors_embedding.{st_f16_le, st_bf16_le}

func main() {
    hf_bpe_tokenizer tokenizer = load_hf_bpe_tokenizer("tests/fixtures/gateway_model")
    if !tokenizer.valid || tokenizer.vocab_count != 4 || tokenizer.merge_count != 1 { return 1 }
    hf_bpe_result result = hf_bpe_encode(tokenizer, "Hi", 8)
    if !result.ok || len(result.token_ids) != 1 || result.token_ids[0] != 3 { return 1 }
    []int f16 = []int{cap: 2}
    f16[0] = 0
    f16[1] = 60
    if st_f16_le(f16, 0) != 1.0 { return 1 }
    []int bf16 = []int{cap: 2}
    bf16[0] = 128
    bf16[1] = 63
    if st_bf16_le(bf16, 0) != 1.0 { return 1 }
    println("PASS pure S F16 BF16 and HF BPE contract")
    0
}
