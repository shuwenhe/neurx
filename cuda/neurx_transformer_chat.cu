#define NEURX_INFERENCE_ONLY
#define NEURX_TRANSFORMER_NO_MAIN
#include "neurx_transformer_train_v2.cu"
#include <iostream>
namespace {
struct inference_cache {
  int *ids;
  float *embedding, *x, *n1, *inv1, *q, *k, *v, *att, *ctx;
  float *proj, *res, *n2, *inv2, *gate, *up, *sw, *down, *h, *logits;
  std::vector<float *> key_cache, value_cache;
  int cache_length = 0;
  explicit inference_cache(const model &m) {
    int64_t td = int64_t(m.seq) * m.dim;
    int64_t tf = int64_t(m.seq) * m.ffn;
    ids = managed_i(m.seq);
    embedding = managed_f(td); x = managed_f(td); n1 = managed_f(td);
    inv1 = managed_f(m.seq); q = managed_f(td); k = managed_f(td);
    v = managed_f(td); att = managed_f(int64_t(m.heads) * m.seq * m.seq);
    ctx = managed_f(td); proj = managed_f(td); res = managed_f(td);
    n2 = managed_f(td); inv2 = managed_f(m.seq); gate = managed_f(tf);
    up = managed_f(tf); sw = managed_f(tf); down = managed_f(td);
    h = managed_f(td); logits = managed_f(int64_t(m.seq) * m.vocab);
    for (int layer = 0; layer < m.nlayers; ++layer) {
      key_cache.push_back(managed_f(td));
      value_cache.push_back(managed_f(td));
    }
  }
  ~inference_cache() {
    void *allocations[] = {ids, embedding, x, n1, inv1, q, k, v, att, ctx,
                           proj, res, n2, inv2, gate, up, sw, down, h, logits};
    for (void *p : allocations) {
      if (p) cuda_free(p);
    }
    for (float *p : key_cache) if (p) cuda_free(p);
    for (float *p : value_cache) if (p) cuda_free(p);
  }
};
static bool read_checkpoint_header(const std::string &path, header_v2 &h) {
  std::ifstream in(path, std::ios::binary);
  if (!in || !read_exact(in, &h, sizeof(h))) {
    std::fprintf(stderr, "Cannot read checkpoint: %s\n", path.c_str());
    return false;
  }
  if (std::memcmp(h.magic, "NXTRFMV2", 8) || (h.version != 2 && h.version != 3) ||
      h.header_bytes != sizeof(h)) {
    std::fprintf(stderr, "Unsupported checkpoint format (expected NXTRFMV2)\n");
    return false;
  }
  return true;
}
static bool load_inference_weights(model &model, const tokenizer &tok,
                                   const std::string &path,
                                   const header_v2 &expected) {
  std::ifstream in(path, std::ios::binary);
  header_v2 h{};
  if (!in || !read_exact(in, &h, sizeof(h))) return false;
  if (std::memcmp(&h, &expected, sizeof(h)) != 0) return false;
  if (h.tokenizer_kind != uint32_t(tok.kind == "bpe") ||
      (h.tokenizer_kind && h.tokenizer_hash != tok.fingerprint)) {
    std::fprintf(stderr, "Checkpoint tokenizer hash does not match vocab/merges\n");
    return false;
  }
  in.seekg(std::streamoff(h.vocab_path_bytes) + h.merges_path_bytes +
               std::streamoff(h.pending_count * sizeof(int)),
           std::ios::cur);
  auto params = model.params();
  if (h.param_count != params.size()) {
    std::fprintf(stderr, "Checkpoint parameter count mismatch\n");
    return false;
  }
  for (param *p : params) {
    uint64_t count = 0;
    if (!read_exact(in, &count, sizeof(count)) || count != uint64_t(p->n) ||
        !read_exact(in, p->v, count * sizeof(float))) {
      std::fprintf(stderr, "Checkpoint weight block mismatch\n");
      return false;
    }
    in.seekg(std::streamoff(count * sizeof(float) * 3), std::ios::cur);
    if (!in) return false;
  }
  return true;
}
static bool forward_prefill(model &m, inference_cache &c, const std::vector<int> &ids) {
  int t = int(ids.size()), d = m.dim, f = m.ffn, td = t * d, tf = t * f;
  for (int i = 0; i < t; ++i) c.ids[i] = ids[i];
  embedding_fwd<<<blocks(td), 256>>>(c.ids, m.emb.v, c.embedding, t, d);
  float *input = c.embedding;
  for (int li = 0; li < m.nlayers; ++li) {
    layer &l = *m.layers[li];
    CUDA_CHECK(cuda_memcpy(c.x, input, td * sizeof(float), cuda_memcpy_device_to_device));
    rms_fwd<<<blocks(t), 256>>>(c.x, l.nq.v, c.n1, c.inv1, t, d);
    if (!gemm(c.n1, l.wq.v, c.q, t, d, d) ||
        !gemm(c.n1, l.wk.v, c.k, t, d, d) ||
        !gemm(c.n1, l.wv.v, c.v, t, d, d)) return false;
    int rope_items = t * m.heads * (d / m.heads / 2);
    rope<<<blocks(rope_items), 256>>>(c.q, t, d, m.heads, false);
    rope<<<blocks(rope_items), 256>>>(c.k, t, d, m.heads, false);
    CUDA_CHECK(cuda_memcpy(c.key_cache[li], c.k, td * sizeof(float), cuda_memcpy_device_to_device));
    CUDA_CHECK(cuda_memcpy(c.value_cache[li], c.v, td * sizeof(float), cuda_memcpy_device_to_device));
    attention_fwd<<<m.heads * t, 1>>>(c.q, c.k, c.v, c.att, c.ctx, t, d, m.heads);
    if (!gemm(c.ctx, l.wo.v, c.proj, t, d, d)) return false;
    add<<<blocks(td), 256>>>(c.x, c.proj, c.res, td);
    rms_fwd<<<blocks(t), 256>>>(c.res, l.nf.v, c.n2, c.inv2, t, d);
    if (!gemm(c.n2, l.wg.v, c.gate, t, d, f) ||
        !gemm(c.n2, l.wu.v, c.up, t, d, f)) return false;
    swiglu_fwd<<<blocks(tf), 256>>>(c.gate, c.up, c.sw, tf);
    if (!gemm(c.sw, l.wd.v, c.down, t, f, d)) return false;
    add<<<blocks(td), 256>>>(c.res, c.down, c.h, td);
    input = c.h;
  }
  if (!gemm(input, m.out.v, c.logits, t, d, m.vocab)) return false;
  CUDA_CHECK(cuda_device_synchronize());
  c.cache_length = t;
  return true;
}
static bool forward_decode(model &m, inference_cache &c, int token, int position) {
  if (position != c.cache_length || position < 0 || position >= m.seq) {
    std::fprintf(stderr, "KV cache position mismatch: position=%d cache_length=%d\n",
                 position, c.cache_length);
    return false;
  }
  const int d = m.dim, f = m.ffn;
  c.ids[0] = token;
  embedding_fwd<<<blocks(d), 256>>>(c.ids, m.emb.v, c.embedding, 1, d);
  float *input = c.embedding;
  for (int li = 0; li < m.nlayers; ++li) {
    layer &l = *m.layers[li];
    CUDA_CHECK(cuda_memcpy(c.x, input, d * sizeof(float), cuda_memcpy_device_to_device));
    rms_fwd<<<1, 1>>>(c.x, l.nq.v, c.n1, c.inv1, 1, d);
    if (!gemm(c.n1, l.wq.v, c.q, 1, d, d) ||
        !gemm(c.n1, l.wk.v, c.k, 1, d, d) ||
        !gemm(c.n1, l.wv.v, c.v, 1, d, d)) return false;
    const int rope_items = m.heads * (d / m.heads / 2);
    rope_position<<<blocks(rope_items), 256>>>(c.q, d, m.heads, position);
    rope_position<<<blocks(rope_items), 256>>>(c.k, d, m.heads, position);
    CUDA_CHECK(cuda_memcpy(c.key_cache[li] + int64_t(position) * d, c.k,
                          d * sizeof(float), cuda_memcpy_device_to_device));
    CUDA_CHECK(cuda_memcpy(c.value_cache[li] + int64_t(position) * d, c.v,
                          d * sizeof(float), cuda_memcpy_device_to_device));
    attention_decode<<<blocks(m.heads), 256>>>(c.q, c.key_cache[li], c.value_cache[li],
                                               c.att, c.ctx, position, m.seq, d, m.heads);
    if (!gemm(c.ctx, l.wo.v, c.proj, 1, d, d)) return false;
    add<<<blocks(d), 256>>>(c.x, c.proj, c.res, d);
    rms_fwd<<<1, 1>>>(c.res, l.nf.v, c.n2, c.inv2, 1, d);
    if (!gemm(c.n2, l.wg.v, c.gate, 1, d, f) ||
        !gemm(c.n2, l.wu.v, c.up, 1, d, f)) return false;
    swiglu_fwd<<<blocks(f), 256>>>(c.gate, c.up, c.sw, f);
    if (!gemm(c.sw, l.wd.v, c.down, 1, f, d)) return false;
    add<<<blocks(d), 256>>>(c.res, c.down, c.h, d);
    input = c.h;
  }
  if (!gemm(input, m.out.v, c.logits, 1, d, m.vocab)) return false;
  CUDA_CHECK(cuda_device_synchronize());
  c.cache_length = position + 1;
  return true;
}
static int greedy_token(const model &m, const inference_cache &c, int position) {
  const float *row = c.logits + int64_t(position) * m.vocab;
  int best = 0;
  for (int i = 1; i < m.vocab; ++i) if (row[i] > row[best]) best = i;
  return best;
}
static std::vector<std::string> decoder_for(const tokenizer &tok) {
  std::vector<std::string> decoder(tok.size());
  for (const auto &entry : tok.vocab) {
    if (entry.second >= 0 && entry.second < int(decoder.size()))
      decoder[entry.second] = entry.first;
  }
  return decoder;
}
}
int main() {
  std::setvbuf(stdout, nullptr, _IOLBF, 0);
  int device_count = 0;
  cuda_error_t status = cuda_get_device_count(&device_count);
  if (status != cuda_success || device_count < 1) {
    std::fprintf(stderr, "CUDA device unavailable: %s\n", cuda_get_error_string(status));
    return 2;
  }
  std::string checkpoint = env_str("NEURX_CHECKPOINT", "checkpoint/NeurX-1.3/transformer_v2.ckpt");
  header_v2 header{};
  if (!read_checkpoint_header(checkpoint, header)) return 3;
  tokenizer tok;
  if (!tok.load(env_str("NEURX_TOKENIZER_VOCAB", "data/corpus/vocab.json"),
                env_str("NEURX_TOKENIZER_MERGES", "data/corpus/merges.txt"))) return 4;
  if (tok.size() != int(header.vocab)) {
    std::fprintf(stderr, "Tokenizer vocabulary size mismatch: %d != %u\n", tok.size(), header.vocab);
    return 4;
  }
  std::printf("Loading %.2f GiB NXTRFMV2 checkpoint weights...\n",
              std::filesystem::file_size(checkpoint) / double(1ULL << 30));
  model model(header.vocab, header.seq, header.dim, header.heads,
              header.ffn, header.layers);
  if (!load_inference_weights(model, tok, checkpoint, header)) return 5;
  inference_cache cache(model);
  auto decoder = decoder_for(tok);
  int max_new_tokens = std::max(1, env_int("NEURX_CHAT_MAX_TOKENS", 64));
  std::printf("NeurX real CUDA inference ready (step=%llu, layers=%u, context=%u).\n",
              static_cast<unsigned long long>(header.step), header.layers, header.seq);
  std::printf("Commands: quit, exit, bye, or English text\n\n");
  for (std::string line;;) {
    std::printf("You: ");
    if (!std::getline(std::cin, line)) break;
    if (line == "quit" || line == "exit" || line == "bye" || line == "English text") break;
    if (line.empty()) continue;
    std::vector<int> ids = tok.encode("User: " + line + "\nAssistant:");
    if (tok.eos >= 0 && !ids.empty() && ids.back() == tok.eos) ids.pop_back();
    if (ids.empty()) ids.push_back(tok.unk);
    if (ids.size() >= header.seq) ids.erase(ids.begin(), ids.end() - (header.seq - 1));
    std::printf("NeurX: ");
    if (!forward_prefill(model, cache, ids)) return 6;
    int logits_position = int(ids.size()) - 1;
    for (int n = 0; n < max_new_tokens && ids.size() < header.seq; ++n) {
      int token = greedy_token(model, cache, logits_position);
      if (token == tok.eos) break;
      if (token >= 0 && token < int(decoder.size())) std::printf("%s", decoder[token].c_str());
      ids.push_back(token);
      if (n + 1 < max_new_tokens && ids.size() < header.seq) {
        if (!forward_decode(model, cache, token, int(ids.size()) - 1)) return 6;
        logits_position = 0;
      }
    }
    std::printf("\n\n");
  }
  std::printf("Session ended.\n");
  return 0;
}
