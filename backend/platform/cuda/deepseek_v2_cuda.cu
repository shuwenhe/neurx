#include "../../../src/runtime/model/json.h"
#include "deepseek_v2_cuda.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cuda_runtime.h>
#include <fcntl.h>
#include <filesystem>
#include <limits>
#include <map>
#include <stdexcept>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <utility>

namespace neurx::cuda {
namespace {
using runtime::model::json;
void ck(cudaError_t e, const char *op) {
  if (e != cudaSuccess)
    throw std::runtime_error(std::string(op) + ": " + cudaGetErrorString(e));
}
struct buffer {
  void *p = nullptr;
  size_t size = 0;
  buffer() = default;
  explicit buffer(size_t n) : size(n) {
    if (n)
      ck(cudaMalloc(&p, n), "DeepSeek cudaMalloc");
  }
  ~buffer() {
    if (p)
      cudaFree(p);
  }
  buffer(buffer &&o) noexcept
      : p(std::exchange(o.p, nullptr)), size(std::exchange(o.size, 0)) {}
  buffer &operator=(buffer &&o) noexcept {
    if (this != &o) {
      if (p)
        cudaFree(p);
      p = std::exchange(o.p, nullptr);
      size = std::exchange(o.size, 0);
    }
    return *this;
  }
  buffer(const buffer &) = delete;
  buffer &operator=(const buffer &) = delete;
  float *f() { return static_cast<float *>(p); }
};
struct mapping {
  void *p = MAP_FAILED;
  size_t size = 0;
  explicit mapping(const std::string &path) {
    int fd = open(path.c_str(), O_RDONLY);
    if (fd < 0)
      throw std::runtime_error("cannot open checkpoint shard: " + path);
    struct stat st{};
    if (fstat(fd, &st) || st.st_size < 8) {
      close(fd);
      throw std::runtime_error("invalid checkpoint shard: " + path);
    }
    size = st.st_size;
    p = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (p == MAP_FAILED)
      throw std::runtime_error("cannot mmap checkpoint shard: " + path);
    // Random expert access: do not fault whole multi-GB shards into host
    // memory.
    madvise(p, size, MADV_RANDOM);
  }
  ~mapping() {
    if (p != MAP_FAILED)
      munmap(p, size);
  }
};
struct tensor_view {
  const unsigned char *p;
  size_t bytes;
  std::vector<int> shape;
  bool bf16;
};
class weights {
  std::vector<std::unique_ptr<mapping>> maps;
  std::map<std::string, tensor_view> views;
  struct resident {
    buffer data;
    uint64_t used;
  };
  std::map<std::string, resident> gpu;
  size_t budget = 0, used = 0;
  uint64_t clock = 0;

public:
  weights(const std::string &dir, size_t bytes) : budget(bytes) {
    std::map<std::string, std::vector<std::string>> shards;
    const auto index =
        std::filesystem::path(dir) / "model.safetensors.index.json";
    if (std::filesystem::exists(index)) {
      const auto index_json = json::parse_file(index.string());
      for (const auto &kv : index_json.at("weight_map").as_object())
        shards[kv.second.as_string()].push_back(kv.first);
    } else
      shards["model.safetensors"] = {};
    for (const auto &shard : shards) {
      auto rel = std::filesystem::path(shard.first);
      if (rel.is_absolute() || rel.has_parent_path())
        throw std::runtime_error("invalid checkpoint shard filename");
      auto m = std::make_unique<mapping>(
          (std::filesystem::path(dir) / rel).string());
      auto base = static_cast<const unsigned char *>(m->p);
      uint64_t hs = 0;
      for (int i = 0; i < 8; ++i)
        hs |= uint64_t(base[i]) << (i * 8);
      if (hs > m->size - 8 || hs > 64 * 1024 * 1024)
        throw std::runtime_error("invalid checkpoint header size");
      const auto header = json::parse(
          std::string(reinterpret_cast<const char *>(base + 8), hs));
      for (const auto &kv : header.as_object()) {
        if (kv.first == "__metadata__")
          continue;
        const auto &j = kv.second;
        auto dtype = j.at("dtype").as_string();
        if (dtype != "BF16" && dtype != "F32")
          throw std::runtime_error(
              "DeepSeek expects BF16/F32 checkpoint weights");
        auto offsets = j.at("data_offsets").as_array();
        if (offsets.size() != 2)
          throw std::runtime_error("invalid tensor offsets");
        int64_t begin = offsets[0].as_int(), end = offsets[1].as_int();
        if (begin < 0 || end < begin || uint64_t(end) > m->size - 8 - hs)
          throw std::runtime_error("tensor exceeds checkpoint shard");
        tensor_view t{
            base + 8 + hs + begin, size_t(end - begin), {}, dtype == "BF16"};
        size_t count = 1;
        for (const auto &d : j.at("shape").as_array()) {
          int64_t n = d.as_int();
          if (n <= 0 || n > INT32_MAX || count > SIZE_MAX / size_t(n))
            throw std::runtime_error("invalid tensor shape");
          t.shape.push_back(int(n));
          count *= n;
        }
        size_t width = t.bf16 ? 2 : 4;
        if (count > SIZE_MAX / width || count * width != t.bytes)
          throw std::runtime_error("tensor byte count mismatch");
        if (!views.emplace(kv.first, t).second)
          throw std::runtime_error("duplicate checkpoint tensor");
      }
      for (const auto &name : shard.second)
        if (!header.contains(name))
          throw std::runtime_error("indexed tensor missing from shard: " +
                                   name);
      maps.push_back(std::move(m));
    }
  }
  const tensor_view &at(const std::string &name) const {
    auto it = views.find(name);
    if (it == views.end())
      throw std::runtime_error("missing DeepSeek tensor: " + name);
    return it->second;
  }
  void expect(const std::string &name, std::vector<int> shape) const {
    if (at(name).shape != shape)
      throw std::runtime_error("DeepSeek tensor shape mismatch: " + name);
  }
  const void *get(const std::string &name) {
    auto it = gpu.find(name);
    if (it != gpu.end()) {
      it->second.used = ++clock;
      return it->second.data.p;
    }
    const auto &v = at(name);
    if (v.bytes > budget)
      throw std::runtime_error("DeepSeek weight cache too small for " + name);
    while (used + v.bytes > budget) {
      auto old = std::min_element(gpu.begin(), gpu.end(),
                                  [](const auto &a, const auto &b) {
                                    return a.second.used < b.second.used;
                                  });
      used -= old->second.data.size;
      gpu.erase(old);
    }
    buffer b(v.bytes);
    ck(cudaMemcpy(b.p, v.p, v.bytes, cudaMemcpyHostToDevice),
       "upload DeepSeek weight");
    used += v.bytes;
    auto ins = gpu.emplace(name, resident{std::move(b), ++clock});
    return ins.first->second.data.p;
  }
};
__device__ float value(const void *p, int i, bool bf) {
  return bf ? __uint_as_float(uint32_t(static_cast<const uint16_t *>(p)[i])
                              << 16)
            : static_cast<const float *>(p)[i];
}
__device__ float sum256(float x) {
  __shared__ float s[256];
  int i = threadIdx.x;
  s[i] = x;
  __syncthreads();
  for (int n = 128; n; n >>= 1) {
    if (i < n)
      s[i] += s[i + n];
    __syncthreads();
  }
  return s[0];
}
__global__ void matvec(const void *w, const float *x, float *y, int in, int out,
                       bool bf) {
  int row = blockIdx.x;
  if (row >= out)
    return;
  float v = 0;
  for (int j = threadIdx.x; j < in; j += 256)
    v += value(w, row * in + j, bf) * x[j];
  v = sum256(v);
  if (threadIdx.x == 0)
    y[row] = v;
}
__global__ void embedding(const void *w, float *x, int id, int h, bool bf) {
  int i = blockIdx.x * 256 + threadIdx.x;
  if (i < h)
    x[i] = value(w, id * h + i, bf);
}
__global__ void rms(const float *x, const void *w, float *y, int n, float eps,
                    bool bf) {
  float v = 0;
  for (int i = threadIdx.x; i < n; i += 256)
    v += x[i] * x[i];
  float inv = rsqrtf(sum256(v) / n + eps);
  for (int i = threadIdx.x; i < n; i += 256)
    y[i] = x[i] * inv * value(w, i, bf);
}
__global__ void swiglu(float *g, const float *u, int n) {
  int i = blockIdx.x * 256 + threadIdx.x;
  if (i < n)
    g[i] = g[i] / (1 + expf(-g[i])) * u[i];
}
__global__ void add(float *x, const float *y, int n, float scale) {
  int i = blockIdx.x * 256 + threadIdx.x;
  if (i < n)
    x[i] += scale * y[i];
}
__global__ void prepare_mla(const float *q, const float *ka, const float *kv,
                            float *qr, float *keys, float *vals,
                            const float *freq, int pos, int heads, int nope,
                            int rd, int vd, int rank, float mscale) {
  int i = blockIdx.x * 256 + threadIdx.x;
  int qd = nope + rd;
  if (i < heads * qd) {
    int h = i / qd, d = i % qd;
    float qv, kvv;
    if (d < nope) {
      qv = q[i];
      kvv = kv[h * (nope + vd) + d];
    } else {
      int r = d - nope, j = r % (rd / 2);
      float angle = pos * freq[j], cs = cosf(angle) * mscale,
            sn = sinf(angle) * mscale;
      float a = q[h * qd + nope + 2 * j], b = q[h * qd + nope + 2 * j + 1];
      float c = ka[rank + 2 * j], e = ka[rank + 2 * j + 1];
      qv = r < rd / 2 ? a * cs - b * sn : b * cs + a * sn;
      kvv = r < rd / 2 ? c * cs - e * sn : e * cs + c * sn;
    }
    qr[i] = qv;
    keys[pos * heads * qd + i] = kvv;
  }
  if (i < heads * vd) {
    int h = i / vd, d = i % vd;
    vals[pos * heads * vd + i] = kv[h * (nope + vd) + nope + d];
  }
}
__global__ void attention(const float *q, const float *k, const float *v,
                          float *out, int heads, int qd, int vd, int length,
                          float scale) {
  extern __shared__ float scores[];
  int h = blockIdx.x, tid = threadIdx.x;
  float mx = -INFINITY;
  for (int t = tid; t < length; t += 256) {
    float z = 0;
    for (int d = 0; d < qd; ++d)
      z += q[h * qd + d] * k[(t * heads + h) * qd + d];
    scores[t] = z * scale;
    mx = fmaxf(mx, scores[t]);
  }
  __shared__ float reduce[256];
  reduce[tid] = mx;
  __syncthreads();
  for (int n = 128; n; n >>= 1) {
    if (tid < n)
      reduce[tid] = fmaxf(reduce[tid], reduce[tid + n]);
    __syncthreads();
  }
  mx = reduce[0];
  float total = 0;
  for (int t = tid; t < length; t += 256) {
    scores[t] = expf(scores[t] - mx);
    total += scores[t];
  }
  total = sum256(total);
  __syncthreads();
  for (int d = tid; d < vd; d += 256) {
    float y = 0;
    for (int t = 0; t < length; ++t)
      y += scores[t] * v[(t * heads + h) * vd + d];
    out[h * vd + d] = y / total;
  }
}
int integer(const json &c, const char *k, int fallback = -1) {
  if (!c.contains(k))
    return fallback;
  int64_t v = c.at(k).as_int();
  if (v < 0 || v > INT32_MAX)
    throw std::runtime_error(std::string("invalid DeepSeek config: ") + k);
  return int(v);
}
double number(const json &c, const char *k, double fallback) {
  return c.contains(k) ? c.at(k).as_number() : fallback;
}
int env_int(const char *name, int fallback) {
  const char *v = getenv(name);
  if (!v)
    return fallback;
  size_t n = 0;
  int x = std::stoi(v, &n);
  if (n != strlen(v) || x <= 0)
    throw std::runtime_error(std::string("invalid ") + name);
  return x;
}
} // namespace
struct deepseek_v2_cache::state {
  int length = 0, limit = 0;
  const void *owner = nullptr;
  std::vector<buffer> keys, values;
};
deepseek_v2_cache::deepseek_v2_cache(std::unique_ptr<state> s)
    : state_(std::move(s)) {}
deepseek_v2_cache::~deepseek_v2_cache() = default;
size_t deepseek_v2_cache::length() const { return state_->length; }
struct deepseek_v2_cuda::impl {
  int device, h, vocab, layers, heads, nope, rd, vd, rank, inter, moe, experts,
      topk, shared, first, limit, bos, eos;
  float eps, attn_scale, rope_scale, route_scale;
  bool norm_top;
  std::unique_ptr<weights> store;
  buffer x, z, q, ka, kan, kv, qr, attn, tmp, gate, up, expert, sum, logits,
      freq;
  explicit impl(const std::string &dir, int dev) : device(dev) {
    ck(cudaSetDevice(dev), "DeepSeek set device");
    auto c = json::parse_file(dir + "/config.json");
    if (c.at("model_type").as_string() != "deepseek_v2")
      throw std::runtime_error("expected deepseek_v2");
    if ((c.contains("q_lora_rank") && !c.at("q_lora_rank").is_null()) ||
        integer(c, "moe_layer_freq", 1) != 1 ||
        c.at("topk_method").as_string() != "greedy" ||
        c.at("scoring_func").as_string() != "softmax" ||
        c.at("hidden_act").as_string() != "silu" ||
        c.at("attention_bias").as_bool() ||
        (c.contains("mlp_bias") && c.at("mlp_bias").as_bool()))
      throw std::runtime_error("unsupported DeepSeek variant (requires Lite "
                               "q_proj, greedy softmax MoE, SiLU, no bias)");
    h = integer(c, "hidden_size");
    vocab = integer(c, "vocab_size");
    layers = integer(c, "num_hidden_layers");
    heads = integer(c, "num_attention_heads");
    nope = integer(c, "qk_nope_head_dim");
    rd = integer(c, "qk_rope_head_dim");
    vd = integer(c, "v_head_dim");
    rank = integer(c, "kv_lora_rank");
    inter = integer(c, "intermediate_size");
    moe = integer(c, "moe_intermediate_size");
    experts = integer(c, "n_routed_experts");
    topk = integer(c, "num_experts_per_tok");
    shared = integer(c, "n_shared_experts");
    first = integer(c, "first_k_dense_replace");
    bos = integer(c, "bos_token_id");
    eos = integer(c, "eos_token_id");
    eps = number(c, "rms_norm_eps", 1e-6);
    route_scale = number(c, "routed_scaling_factor", 1);
    norm_top = c.at("norm_topk_prob").as_bool();
    limit = std::min(integer(c, "max_position_embeddings"),
                     env_int("NEURX_DEEPSEEK_CONTEXT", 2048));
    if (h <= 0 || vocab <= 0 || layers <= 0 || heads <= 0 || nope <= 0 ||
        rd <= 0 || rd % 2 || vd <= 0 || rank <= 0 || inter <= 0 || moe <= 0 ||
        experts <= 0 || topk <= 0 || topk > experts || shared <= 0 ||
        first > layers || limit <= 0 || bos < 0 || bos >= vocab || eos < 0 ||
        eos >= vocab || eps <= 0)
      throw std::runtime_error("invalid DeepSeek dimensions");
    if (limit > 8192)
      throw std::runtime_error(
          "initial DeepSeek CUDA decoder supports context <=8192");
    double theta = number(c, "rope_theta", 10000), factor = 1, ms = 1, msa = 1,
           fast = 32, slow = 1, original = 4096;
    if (c.contains("rope_scaling") && !c.at("rope_scaling").is_null()) {
      const auto &r = c.at("rope_scaling");
      if (r.at("type").as_string() != "yarn")
        throw std::runtime_error(
            "only YaRN DeepSeek rotary scaling is supported");
      factor = number(r, "factor", 1);
      ms = number(r, "mscale", 1);
      msa = number(r, "mscale_all_dim", 0);
      fast = number(r, "beta_fast", 32);
      slow = number(r, "beta_slow", 1);
      original = number(r, "original_max_position_embeddings", 4096);
    }
    if (theta <= 1 || factor < 1 || fast <= 0 || slow <= 0 || original <= 0)
      throw std::runtime_error("invalid YaRN configuration");
    auto scale = [factor](double x) {
      return factor <= 1 ? 1. : 1. + .1 * x * std::log(factor);
    };
    rope_scale = scale(ms) / scale(msa);
    attn_scale = scale(msa) * scale(msa) / std::sqrt(float(nope + rd));
    auto corr = [&](double b) {
      return rd * std::log(original / (b * 2 * 3.141592653589793)) /
             (2 * std::log(theta));
    };
    double lo = std::max(std::floor(corr(fast)), 0.),
           hi = std::min(std::ceil(corr(slow)), double(rd - 1));
    if (lo == hi)
      hi += .001;
    std::vector<float> frequencies(rd / 2);
    for (int i = 0; i < rd / 2; ++i) {
      double ramp = std::clamp((i - lo) / (hi - lo), 0., 1.);
      frequencies[i] =
          std::pow(theta, -2. * i / rd) * (1 - ramp + ramp / factor);
    }
    size_t free = 0, total = 0;
    ck(cudaMemGetInfo(&free, &total), "DeepSeek available memory");
    const size_t reserve =
        size_t(layers) * limit * heads * (nope + rd + vd) * sizeof(float) +
        512ULL * 1024 * 1024;
    if (free <= reserve + 64 * 1024 * 1024)
      throw std::runtime_error("insufficient GPU memory for DeepSeek "
                               "KV/workspace; lower NEURX_DEEPSEEK_CONTEXT");
    size_t budget = std::min(
        size_t(env_int("NEURX_DEEPSEEK_WEIGHT_CACHE_MB", 8192)) * 1024 * 1024,
        free - reserve);
    store = std::make_unique<weights>(dir, budget);
    store->expect("model.embed_tokens.weight", {vocab, h});
    store->expect("model.norm.weight", {h});
    store->expect("lm_head.weight", {vocab, h});
    auto mlp_check = [&](const std::string &p, int d) {
      store->expect(p + "gate_proj.weight", {d, h});
      store->expect(p + "up_proj.weight", {d, h});
      store->expect(p + "down_proj.weight", {h, d});
    };
    for (int l = 0; l < layers; ++l) {
      auto p = "model.layers." + std::to_string(l) + ".";
      auto a = p + "self_attn.";
      store->expect(p + "input_layernorm.weight", {h});
      store->expect(p + "post_attention_layernorm.weight", {h});
      store->expect(a + "q_proj.weight", {heads * (nope + rd), h});
      store->expect(a + "kv_a_proj_with_mqa.weight", {rank + rd, h});
      store->expect(a + "kv_a_layernorm.weight", {rank});
      store->expect(a + "kv_b_proj.weight", {heads * (nope + vd), rank});
      store->expect(a + "o_proj.weight", {h, heads * vd});
      if (l < first)
        mlp_check(p + "mlp.", inter);
      else {
        store->expect(p + "mlp.gate.weight", {experts, h});
        mlp_check(p + "mlp.shared_experts.", shared * moe);
        for (int e = 0; e < experts; ++e)
          mlp_check(p + "mlp.experts." + std::to_string(e) + ".", moe);
      }
    }
    x = buffer(h * 4);
    z = buffer(h * 4);
    q = buffer(heads * (nope + rd) * 4);
    ka = buffer((rank + rd) * 4);
    kan = buffer(rank * 4);
    kv = buffer(heads * (nope + vd) * 4);
    qr = buffer(heads * (nope + rd) * 4);
    attn = buffer(heads * vd * 4);
    tmp = buffer(h * 4);
    gate = buffer(std::max(inter, shared * moe) * 4);
    up = buffer(gate.size);
    expert = buffer(h * 4);
    sum = buffer(h * 4);
    logits = buffer(std::max(vocab, experts) * 4);
    freq = buffer(frequencies.size() * 4);
    ck(cudaMemcpy(freq.p, frequencies.data(), freq.size,
                  cudaMemcpyHostToDevice),
       "DeepSeek rotary frequencies");
    fprintf(stderr,
            "[DeepSeek] %d layers, MLA + %d experts/top-%d, BF16/F32 "
            "checkpoint, FP32 activations; GPU weight cache %.0f MiB, context "
            "%d; host offload enabled\n",
            layers, experts, topk, budget / 1048576., limit);
  }
  void linear(const std::string &name, float *input, float *output) {
    const auto &t = store->at(name + ".weight");
    auto p = store->get(name + ".weight");
    matvec<<<t.shape[0], 256>>>(p, input, output, t.shape[1], t.shape[0],
                                t.bf16);
  }
  void norm(const std::string &name, float *input, float *output, int n) {
    const auto &t = store->at(name);
    auto p = store->get(name);
    rms<<<1, 256>>>(input, p, output, n, eps, t.bf16);
  }
  void mlp(const std::string &p, int d) {
    linear(p + "gate_proj", z.f(), gate.f());
    linear(p + "up_proj", z.f(), up.f());
    swiglu<<<(d + 255) / 256, 256>>>(gate.f(), up.f(), d);
    linear(p + "down_proj", gate.f(), expert.f());
  }
  std::vector<float> step(int id, deepseek_v2_cache::state &s) {
    ck(cudaSetDevice(device), "DeepSeek select device");
    if (id < 0 || id >= vocab)
      throw std::runtime_error("DeepSeek token out of range");
    if (s.owner != this)
      throw std::runtime_error("DeepSeek cache belongs to another model");
    if (s.length >= limit)
      throw std::runtime_error("DeepSeek context limit reached");
    const auto &t = store->at("model.embed_tokens.weight");
    auto ep = store->get("model.embed_tokens.weight");
    embedding<<<(h + 255) / 256, 256>>>(ep, x.f(), id, h, t.bf16);
    for (int l = 0; l < layers; ++l) {
      auto p = "model.layers." + std::to_string(l) + ".";
      auto a = p + "self_attn.";
      norm(p + "input_layernorm.weight", x.f(), z.f(), h);
      linear(a + "q_proj", z.f(), q.f());
      linear(a + "kv_a_proj_with_mqa", z.f(), ka.f());
      norm(a + "kv_a_layernorm.weight", ka.f(), kan.f(), rank);
      linear(a + "kv_b_proj", kan.f(), kv.f());
      int n = std::max(heads * (nope + rd), heads * vd);
      prepare_mla<<<(n + 255) / 256, 256>>>(
          q.f(), ka.f(), kv.f(), qr.f(), s.keys[l].f(), s.values[l].f(),
          freq.f(), s.length, heads, nope, rd, vd, rank, rope_scale);
      attention<<<heads, 256, (s.length + 1) * sizeof(float)>>>(
          qr.f(), s.keys[l].f(), s.values[l].f(), attn.f(), heads, nope + rd,
          vd, s.length + 1, attn_scale);
      linear(a + "o_proj", attn.f(), tmp.f());
      add<<<(h + 255) / 256, 256>>>(x.f(), tmp.f(), h, 1);
      norm(p + "post_attention_layernorm.weight", x.f(), z.f(), h);
      if (l < first) {
        mlp(p + "mlp.", inter);
        add<<<(h + 255) / 256, 256>>>(x.f(), expert.f(), h, 1);
      } else {
        linear(p + "mlp.gate", z.f(), logits.f());
        std::vector<float> scores(experts);
        ck(cudaMemcpy(scores.data(), logits.p, experts * 4,
                      cudaMemcpyDeviceToHost),
           "DeepSeek route logits");
        float mx = *std::max_element(scores.begin(), scores.end());
        double denominator = 0;
        for (float &v : scores) {
          v = std::exp(v - mx);
          denominator += v;
        }
        for (float &v : scores)
          v /= denominator;
        std::vector<int> indices(experts);
        for (int i = 0; i < experts; ++i)
          indices[i] = i;
        std::partial_sort(indices.begin(), indices.begin() + topk,
                          indices.end(), [&](int a, int b) {
                            return scores[a] == scores[b]
                                       ? a < b
                                       : scores[a] > scores[b];
                          });
        float selected = 0;
        for (int i = 0; i < topk; ++i)
          selected += scores[indices[i]];
        ck(cudaMemset(sum.p, 0, sum.size), "DeepSeek clear expert sum");
        for (int i = 0; i < topk; ++i) {
          int e = indices[i];
          mlp(p + "mlp.experts." + std::to_string(e) + ".", moe);
          float weight = norm_top && topk > 1 ? scores[e] / (selected + 1e-20f)
                                              : scores[e] * route_scale;
          add<<<(h + 255) / 256, 256>>>(sum.f(), expert.f(), h, weight);
        }
        mlp(p + "mlp.shared_experts.", shared * moe);
        add<<<(h + 255) / 256, 256>>>(x.f(), sum.f(), h, 1);
        add<<<(h + 255) / 256, 256>>>(x.f(), expert.f(), h, 1);
      }
    }
    norm("model.norm.weight", x.f(), z.f(), h);
    linear("lm_head", z.f(), logits.f());
    std::vector<float> result(vocab);
    ck(cudaGetLastError(), "DeepSeek kernels");
    ck(cudaMemcpy(result.data(), logits.p, vocab * 4, cudaMemcpyDeviceToHost),
       "DeepSeek output logits");
    if (!std::all_of(result.begin(), result.end(),
                     [](float v) { return std::isfinite(v); }))
      throw std::runtime_error("DeepSeek produced non-finite logits");
    ++s.length;
    return result;
  }
};
deepseek_v2_cuda::deepseek_v2_cuda(const std::string &dir, int device)
    : impl_(std::make_unique<impl>(dir, device)) {}
deepseek_v2_cuda::~deepseek_v2_cuda() = default;
std::unique_ptr<deepseek_v2_cache> deepseek_v2_cuda::create_cache() const {
  auto s = std::make_unique<deepseek_v2_cache::state>();
  s->limit = impl_->limit;
  s->owner = impl_.get();
  ck(cudaSetDevice(impl_->device), "DeepSeek cache device");
  for (int l = 0; l < impl_->layers; ++l) {
    s->keys.emplace_back(size_t(impl_->limit) * impl_->heads *
                         (impl_->nope + impl_->rd) * 4);
    s->values.emplace_back(size_t(impl_->limit) * impl_->heads * impl_->vd * 4);
  }
  return std::unique_ptr<deepseek_v2_cache>(
      new deepseek_v2_cache(std::move(s)));
}
std::vector<float> deepseek_v2_cuda::prefill(const std::vector<int32_t> &ids,
                                             deepseek_v2_cache *cache) {
  if (!cache || ids.empty())
    throw std::runtime_error("DeepSeek prefill requires tokens and cache");
  if (ids.size() + cache->length() > size_t(impl_->limit))
    throw std::runtime_error("DeepSeek prompt exceeds context limit");
  std::vector<float> out;
  for (int id : ids)
    out = decode(id, cache);
  return out;
}
std::vector<float> deepseek_v2_cuda::decode(int32_t id,
                                            deepseek_v2_cache *cache) {
  if (!cache)
    throw std::runtime_error("DeepSeek cache required");
  return impl_->step(id, *cache->state_);
}
int deepseek_v2_cuda::context_limit() const { return impl_->limit; }
int deepseek_v2_cuda::bos_token_id() const { return impl_->bos; }
int deepseek_v2_cuda::eos_token_id() const { return impl_->eos; }
} // namespace neurx::cuda
