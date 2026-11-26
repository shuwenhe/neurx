#include "hybrid_config.h"
#include "strict_model_json.h"
#include <cmath>

namespace neurx::runtime::model {
namespace {
using detail::model_json;
uint64_t dimension(const model_json& j, const char* name) {
  auto n=detail::natural(j.at(name));
  if (!n || n>(1ULL<<24)) throw std::runtime_error(std::string("invalid dimension: ")+name);
  return n;
}
void require(bool condition, const char* reason) {
  if (!condition) throw std::runtime_error(reason);
}
double number(const model_json& j) {
  require(j.is_number(),"expected finite number"); auto n=j.get<double>();
  require(std::isfinite(n),"non-finite config number"); return n;
}
bool boolean(const model_json& j) {
  require(j.is_boolean(),"expected boolean config flag");return j.get<bool>();
}
void known_fields(const model_json& object, const std::set<std::string>& names) {
  require(object.is_object(),"configuration section must be an object");
  for (const auto& item:object.items())
    if (!names.count(item.key())) throw std::runtime_error("unknown configuration attribute: "+item.key());
}
}
HybridDecoderConfig HybridDecoderConfig::from_file(const std::string& path) {
  return parse(detail::read_small_file(path));
}
HybridDecoderConfig HybridDecoderConfig::parse(const std::string& text) {
  const auto root=detail::strict_parse(text); const auto& t=root.at("text_config");
  known_fields(root,{"architectures","model_type","text_config","vision_config","tie_word_embeddings",
    "transformers_version","image_token_id","video_token_id","vision_start_token_id","vision_end_token_id"});
  // Training/serialization metadata is explicitly named rather than silently accepting semantic extensions.
  known_fields(t,{"model_type","hidden_size","vocab_size","num_hidden_layers","layer_types",
    "num_attention_heads","num_key_value_heads","head_dim","attention_bias","attention_dropout",
    "attn_output_gate","hidden_act","tie_word_embeddings","rms_norm_eps","dtype","max_position_embeddings",
    "linear_num_key_heads","linear_num_value_heads","linear_key_head_dim","linear_value_head_dim",
    "linear_conv_kernel_dim","mamba_ssm_dtype","num_experts","num_experts_per_tok","moe_intermediate_size",
    "shared_expert_intermediate_size","partial_rotary_factor","rope_parameters","mtp_num_hidden_layers",
    "mtp_use_dedicated_embeddings","bos_token_id","eos_token_id","pad_token_id","full_attention_interval",
    "initializer_range","output_router_logits","router_aux_loss_coef","use_cache","use_sliding_window"});
  HybridDecoderConfig c;
  c.model_type=root.at("model_type").get<std::string>();
  c.text_model_type=t.at("model_type").get<std::string>();
  require(c.model_type=="qwen3_5_moe" && c.text_model_type=="qwen3_5_moe_text","unsupported hybrid architecture");
  c.hidden_size=dimension(t,"hidden_size");c.vocab_size=dimension(t,"vocab_size");
  c.max_positions=dimension(t,"max_position_embeddings");
  c.weight_dtype=t.at("dtype").get<std::string>();
  require(c.weight_dtype=="bfloat16" || c.weight_dtype=="float16" || c.weight_dtype=="float32","unsupported checkpoint dtype");
  c.has_vision=root.contains("vision_config");
  if (c.has_vision) require(root.at("vision_config").is_object(),"vision_config must be an object");
  c.mtp_layers=t.contains("mtp_num_hidden_layers") ? detail::natural(t.at("mtp_num_hidden_layers")) : 0;
  require(c.mtp_layers<=1024,"invalid MTP layer count");
  c.rms_epsilon=number(t.at("rms_norm_eps"));require(c.rms_epsilon>0,"non-positive norm epsilon");
  require(!boolean(t.at("attention_bias")) && boolean(t.at("attn_output_gate")),"requires bias-free gated full attention");
  require(number(t.at("attention_dropout"))==0,"inference dropout unsupported");
  if (t.contains("use_sliding_window")) require(!boolean(t.at("use_sliding_window")),"sliding-window attention unsupported");
  require(!boolean(t.at("tie_word_embeddings")),"tied embeddings unsupported by this adapter");
  if (root.contains("tie_word_embeddings")) require(!boolean(root.at("tie_word_embeddings")),"outer tied embeddings unsupported");
  require(t.at("hidden_act")=="silu","unsupported hybrid activation");
  require(t.at("mamba_ssm_dtype")=="float32","Delta recurrent state must be FP32");
  auto layers=dimension(t,"num_hidden_layers");require(layers<=4096,"layer count limit exceeded");
  const auto& types=t.at("layer_types");require(types.is_array() && types.size()==layers,"layer_types must match layer count");
  for (const auto& type:types) {
    if (type=="linear_attention") c.layer_types.push_back(MixerKind::linear_attention);
    else if (type=="full_attention") c.layer_types.push_back(MixerKind::full_attention);
    else throw std::runtime_error("unknown mixer in layer_types");
  }
  c.full.query_heads=dimension(t,"num_attention_heads");c.full.kv_heads=dimension(t,"num_key_value_heads");
  c.full.head_dim=dimension(t,"head_dim");
  require(c.full.query_heads%c.full.kv_heads==0,"invalid GQA head ratio");
  const auto& r=t.at("rope_parameters");require(r.at("rope_type")=="default","unsupported rope type");
  known_fields(r,{"rope_type","rope_theta","partial_rotary_factor","mrope_interleaved","mrope_section"});
  require(boolean(r.at("mrope_interleaved")),"non-interleaved MRoPE unsupported");
  c.full.theta=number(r.at("rope_theta"));require(c.full.theta>1,"invalid rotary theta");
  double partial=number(r.at("partial_rotary_factor"));
  require(partial>0 && partial<=1,"invalid partial rotary factor");
  if (t.contains("partial_rotary_factor")) require(number(t.at("partial_rotary_factor"))==partial,"conflicting rotary factors");
  double rotary=double(c.full.head_dim)*partial;
  require(rotary>=2 && std::floor(rotary)==rotary,"rotary dimension must be integral");
  c.full.rotary_dim=uint64_t(rotary);require(c.full.rotary_dim%2==0,"rotary dimension must be even");
  const auto& sections=r.at("mrope_section");require(sections.is_array() && sections.size()==3,"three MRoPE sections required");
  uint64_t section_sum=0;
  for (const auto& s:sections) { auto n=detail::natural(s);section_sum=detail::checked_add(section_sum,n);c.full.mrope_section.push_back(n); }
  require(section_sum==c.full.rotary_dim/2,"MRoPE section size mismatch");
  c.delta.key_heads=dimension(t,"linear_num_key_heads");c.delta.value_heads=dimension(t,"linear_num_value_heads");
  c.delta.key_dim=dimension(t,"linear_key_head_dim");c.delta.value_dim=dimension(t,"linear_value_head_dim");
  c.delta.conv_kernel=dimension(t,"linear_conv_kernel_dim");
  require(c.delta.value_heads%c.delta.key_heads==0,"invalid Delta head ratio");
  c.moe.experts=dimension(t,"num_experts");c.moe.top_k=dimension(t,"num_experts_per_tok");
  c.moe.intermediate=dimension(t,"moe_intermediate_size");c.moe.shared_intermediate=dimension(t,"shared_expert_intermediate_size");
  require(c.moe.top_k<=c.moe.experts,"top-k exceeds number of experts");
  // Validate derived arithmetic even before any allocator is introduced.
  (void)c.state_bytes(c.max_positions);
  (void)detail::checked_mul(detail::checked_mul(c.moe.experts,2*c.moe.intermediate),c.hidden_size);
  return c;
}
HybridStateBytes HybridDecoderConfig::state_bytes(uint64_t context) const {
  if (!context || context>max_positions) throw std::runtime_error("context exceeds model capacity");
  using detail::checked_add; using detail::checked_mul;
  HybridStateBytes out;
  for (auto kind:layer_types) {
    if (kind==MixerKind::full_attention)
      out.kv=checked_add(out.kv,checked_mul(checked_mul(checked_mul(context,full.kv_heads),full.head_dim),8));
    else {
      out.recurrent=checked_add(out.recurrent,checked_mul(checked_mul(checked_mul(delta.value_heads,delta.key_dim),delta.value_dim),4));
      auto width=checked_add(checked_mul(checked_mul(delta.key_heads,delta.key_dim),2),checked_mul(delta.value_heads,delta.value_dim));
      out.conv=checked_add(out.conv,checked_mul(checked_mul(width,delta.conv_kernel),4));
    }
  }
  (void)checked_add(checked_add(out.kv,out.recurrent),out.conv);
  return out;
}
}
