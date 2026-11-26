#include "../../backend/platform/cuda/hybrid_attention_cuda.h"
#include <nlohmann/json.hpp>
#include <iostream>
#include <cuda_runtime.h>
#include "../../src/runtime/model/architecture_registry.h"
#include <cstring>
using nlohmann::json;
using namespace neurx::cuda::hybrid;
std::vector<float> bf16(const neurx::runtime::model::MappedWeightStore& store,const std::string& name) {
  auto t=store.tensor(name);
  if(t.dtype()!="BF16"||t.size()%2)throw std::runtime_error("expected BF16");
  std::vector<uint8_t> bytes(t.size());t.copy(0,bytes.data(),bytes.size());
  std::vector<float> out(bytes.size()/2);
  for(size_t i=0;i<out.size();++i){uint32_t bits=(uint32_t(bytes[2*i])|uint32_t(bytes[2*i+1])<<8)<<16;std::memcpy(&out[i],&bits,4);}
  return out;
}
int main(int argc,char** argv) {
  try {
    json j; std::cin >> j;
    AttentionConfig c{j.at("hidden"), j.at("qh"), j.at("kh"), j.at("dim"),
                      j.at("rotary"), j.at("context"), j.at("chunk"),
                      j.at("theta"), j.at("eps")};
    AttentionWeights w;
    if(argc==3&&std::string(argv[1])=="--model") {
      namespace m=neurx::runtime::model;
      auto adapter=m::ArchitectureRegistry::resolve(argv[2]);auto store=m::MappedWeightStore::open(argv[2]);adapter.validate(store);
      const auto& cfg=adapter.config();size_t layer=0;
      while(layer<cfg.layer_types.size()&&cfg.layer_types[layer]!=m::MixerKind::full_attention)++layer;
      if(layer==cfg.layer_types.size())throw std::runtime_error("no full attention layer");
      if(c.hidden!=int(cfg.hidden_size)||c.query_heads!=int(cfg.full.query_heads)||c.kv_heads!=int(cfg.full.kv_heads)||c.head_dim!=int(cfg.full.head_dim)||c.rotary_dim!=int(cfg.full.rotary_dim)||c.theta!=cfg.full.theta||c.epsilon!=cfg.rms_epsilon)throw std::runtime_error("model config mismatch");
      auto pre="model.language_model.layers."+std::to_string(layer)+".self_attn.";
      w.qg=bf16(store,pre+"q_proj.weight");w.k=bf16(store,pre+"k_proj.weight");w.v=bf16(store,pre+"v_proj.weight");w.o=bf16(store,pre+"o_proj.weight");
      w.qnorm=bf16(store,pre+"q_norm.weight");w.knorm=bf16(store,pre+"k_norm.weight");
    }else{
      w.qg=j.at("qg").get<std::vector<float>>(); w.k=j.at("k").get<std::vector<float>>();
      w.v=j.at("v").get<std::vector<float>>(); w.o=j.at("o").get<std::vector<float>>();
      w.qnorm=j.at("qnorm").get<std::vector<float>>(); w.knorm=j.at("knorm").get<std::vector<float>>();
    }
    size_t free_before=0,free_after=0,total=0;
    cudaMemGetInfo(&free_before,&total);
    FullAttentionSession session(c,w,j.value("budget",uint64_t(64)<<20),j.value("headroom",uint64_t(256)<<20));
    cudaMemGetInfo(&free_after,&total);
    json result=json::array();
    for (auto& a:j.at("calls")) {
      try {
        if(a.contains("reset")) {session.reset();result.push_back({{"reset",true}});continue;}
        auto t=session.forward(a.at("x").get<std::vector<float>>(),a.at("position"),true);
        result.push_back({{"output",t.output},{"q",t.q},{"k",t.k},{"v",t.v},
                          {"attention",t.attention},{"length",session.length()}});
      } catch(const std::exception& e) {result.push_back({{"error",e.what()},{"length",session.length()}});}
    }
    std::cout<<json({{"calls",result},{"allocated",session.allocated_bytes()},
                    {"free_before",free_before},{"free_after",free_after}}).dump()<<'\n';
  } catch(const std::exception& e) {std::cout<<json({{"error",e.what()}}).dump()<<'\n';return 1;}
}
