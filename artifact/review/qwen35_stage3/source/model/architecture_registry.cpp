#include "architecture_registry.h"
#include "strict_model_json.h"
#include <openssl/evp.h>
#include <array>
#include <iomanip>
#include <sstream>

namespace neurx::runtime::model {
namespace {
using Shape=std::vector<uint64_t>;
using Requirements=std::map<std::string,Shape>;
Requirements requirements(const HybridDecoderConfig& c) {
  using detail::checked_add;using detail::checked_mul;
  Requirements weights;
  auto h=c.hidden_size;auto intermediate=c.moe.intermediate;auto shared=c.moe.shared_intermediate;
  weights.emplace("model.language_model.embed_tokens.weight",Shape{c.vocab_size,h});
  weights.emplace("model.language_model.norm.weight",Shape{h});
  weights.emplace("lm_head.weight",Shape{c.vocab_size,h});
  for (size_t i=0;i<c.layer_types.size();++i) {
    auto p="model.language_model.layers."+std::to_string(i)+".";
    auto add=[&](const std::string& name, Shape shape) { weights.emplace(p+name,std::move(shape)); };
    add("input_layernorm.weight",{h});add("post_attention_layernorm.weight",{h});
    add("mlp.gate.weight",{c.moe.experts,h});
    add("mlp.experts.gate_up_proj",{c.moe.experts,checked_mul(2,intermediate),h});
    add("mlp.experts.down_proj",{c.moe.experts,h,intermediate});
    add("mlp.shared_expert.gate_proj.weight",{shared,h});add("mlp.shared_expert.up_proj.weight",{shared,h});
    add("mlp.shared_expert.down_proj.weight",{h,shared});add("mlp.shared_expert_gate.weight",{1,h});
    if (c.layer_types[i]==MixerKind::linear_attention) {
      auto key=checked_mul(c.delta.key_heads,c.delta.key_dim),value=checked_mul(c.delta.value_heads,c.delta.value_dim);
      auto conv=checked_add(checked_mul(2,key),value);
      add("linear_attn.in_proj_qkv.weight",{conv,h});add("linear_attn.in_proj_z.weight",{value,h});
      add("linear_attn.in_proj_a.weight",{c.delta.value_heads,h});add("linear_attn.in_proj_b.weight",{c.delta.value_heads,h});
      add("linear_attn.A_log",{c.delta.value_heads});add("linear_attn.dt_bias",{c.delta.value_heads});
      add("linear_attn.conv1d.weight",{conv,1,c.delta.conv_kernel});add("linear_attn.norm.weight",{c.delta.value_dim});
      add("linear_attn.out_proj.weight",{h,value});
    } else {
      auto query=checked_mul(c.full.query_heads,c.full.head_dim),kv=checked_mul(c.full.kv_heads,c.full.head_dim);
      add("self_attn.q_proj.weight",{checked_mul(2,query),h});add("self_attn.k_proj.weight",{kv,h});
      add("self_attn.v_proj.weight",{kv,h});add("self_attn.o_proj.weight",{h,query});
      add("self_attn.q_norm.weight",{c.full.head_dim});add("self_attn.k_norm.weight",{c.full.head_dim});
    }
  }
  return weights;
}
bool starts_with(const std::string& s,const char* p) { return s.rfind(p,0)==0; }
}
ModelAdapter ArchitectureRegistry::resolve(const std::string& directory) {
  auto raw=detail::read_small_file(directory+"/config.json");auto j=detail::strict_parse(raw);
  if (j.contains("architectures") && j.at("architectures")!=detail::model_json::array({"Qwen3_5MoeForConditionalGeneration"}))
    throw std::runtime_error("unsupported architecture class");
  ModelAdapter adapter;adapter.config_=HybridDecoderConfig::parse(raw);adapter.config_json_=j.dump();return adapter;
}
WeightManifest ModelAdapter::validate(const MappedWeightStore& store) const {
  auto expected=requirements(config_);WeightManifest result;
  std::string dtype=config_.weight_dtype=="bfloat16" ? "BF16" : config_.weight_dtype=="float16" ? "F16" : "F32";
  for (const auto& req:expected) {
    const auto& actual=store.view(req.first);
    if (actual.shape!=req.second || actual.dtype!=dtype) throw std::runtime_error("required shape/dtype mismatch: "+req.first);
    result.roles.emplace(req.first,WeightRole::executed_text);++result.text;
  }
  for (const auto& entry:store.tensors()) {
    if (expected.count(entry.first)) continue;
    if (config_.has_vision && starts_with(entry.first,"model.visual.")) {
      result.roles.emplace(entry.first,WeightRole::excluded_vision);++result.vision;
    } else if (config_.mtp_layers && starts_with(entry.first,"mtp.")) {
      result.roles.emplace(entry.first,WeightRole::excluded_mtp);++result.mtp;
    } else throw std::runtime_error("unexpected/unmapped model tensor: "+entry.first);
  }
  return result;
}
std::string ModelAdapter::metadata_identity(const MappedWeightStore& store) const {
  auto text=std::string("NeurX-config-and-metadata-only-v1\n")+config_json_+"\n"+store.metadata_identity();
  std::array<uint8_t,EVP_MAX_MD_SIZE> raw{};unsigned n=0;
  if (EVP_Digest(text.data(),text.size(),raw.data(),&n,EVP_sha256(),nullptr)!=1)
    throw std::runtime_error("model metadata SHA256 failed");
  std::ostringstream out;
  for (unsigned i=0;i<n;++i) out<<std::hex<<std::setfill('0')<<std::setw(2)<<int(raw[i]);
  return out.str();
}
}
