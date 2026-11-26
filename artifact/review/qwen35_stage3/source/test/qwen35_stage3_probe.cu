#include "../../backend/platform/cuda/hybrid_deltanet_cuda.h"
#include "../../backend/platform/cuda/hybrid_mixer_state.h"
#include <nlohmann/json.hpp>
#include <iostream>
#include <cuda_runtime.h>
#include <cstring>
#include "../../src/runtime/model/architecture_registry.h"
using nlohmann::json;
using namespace neurx::cuda::hybrid;
std::vector<float> bf16(const neurx::runtime::model::MappedWeightStore& store,const std::string& name) {
  auto t=store.tensor(name);if(t.dtype()!="BF16"||t.size()%2)throw std::runtime_error("expected BF16");
  std::vector<uint8_t> raw(t.size());t.copy(0,raw.data(),raw.size());std::vector<float> out(raw.size()/2);
  for(size_t i=0;i<out.size();++i){uint32_t bits=(uint32_t(raw[2*i])|uint32_t(raw[2*i+1])<<8)<<16;std::memcpy(&out[i],&bits,4);}return out;
}
int main(int argc,char** argv) {
  try {
    json j; std::cin>>j;
    DeltaConfig c{j.at("hidden"),j.at("kh"),j.at("vh"),j.at("kd"),j.at("vd"),j.at("conv"),j.at("context"),j.at("chunk"),j.at("eps")};
    DeltaWeights w;
    int selected_layer = -1;
    if((argc==3 || argc==5)&&std::string(argv[1])=="--model") {
      namespace m=neurx::runtime::model;
      auto adapter=m::ArchitectureRegistry::resolve(argv[2]);auto store=m::MappedWeightStore::open(argv[2]);adapter.validate(store);
      const auto& cfg=adapter.config();size_t layer=0;
      if(argc==5) {
        if(std::string(argv[3])!="--layer")throw std::runtime_error("invalid layer option");
        std::string arg=argv[4];
        if(arg.empty() || arg.find_first_not_of("0123456789")!=std::string::npos)throw std::runtime_error("invalid layer index");
        try { layer=std::stoull(arg); } catch(const std::exception&) { throw std::runtime_error("invalid layer index"); }
        if(layer>=cfg.layer_types.size() || cfg.layer_types[layer]!=m::MixerKind::linear_attention)throw std::runtime_error("layer is out of range or not DeltaNet");
      } else {
        while(layer<cfg.layer_types.size()&&cfg.layer_types[layer]!=m::MixerKind::linear_attention)++layer;
        if(layer==cfg.layer_types.size())throw std::runtime_error("no DeltaNet layer");
      }
      selected_layer=int(layer);
      if(c.hidden!=int(cfg.hidden_size)||c.key_heads!=int(cfg.delta.key_heads)||c.value_heads!=int(cfg.delta.value_heads)||c.key_dim!=int(cfg.delta.key_dim)||c.value_dim!=int(cfg.delta.value_dim)||c.conv_kernel!=int(cfg.delta.conv_kernel)||c.epsilon!=cfg.rms_epsilon)throw std::runtime_error("model config mismatch");
      auto pre="model.language_model.layers."+std::to_string(layer)+".linear_attn.";
      w.qkv=bf16(store,pre+"in_proj_qkv.weight");w.z=bf16(store,pre+"in_proj_z.weight");
      w.a=bf16(store,pre+"in_proj_a.weight");w.b=bf16(store,pre+"in_proj_b.weight");
      w.conv=bf16(store,pre+"conv1d.weight");w.alog=bf16(store,pre+"A_log");w.dt=bf16(store,pre+"dt_bias");
      w.norm=bf16(store,pre+"norm.weight");w.out=bf16(store,pre+"out_proj.weight");
    }else{
    if(argc!=1)throw std::runtime_error("invalid model or layer arguments");
    w.qkv=j.at("qkv").get<std::vector<float>>();w.z=j.at("z").get<std::vector<float>>();
    w.a=j.at("a").get<std::vector<float>>();w.b=j.at("b").get<std::vector<float>>();
    w.conv=j.at("conv_weight").get<std::vector<float>>();w.alog=j.at("alog").get<std::vector<float>>();
    w.dt=j.at("dt").get<std::vector<float>>();w.norm=j.at("norm").get<std::vector<float>>();w.out=j.at("out").get<std::vector<float>>();
    }
    size_t before=0,after=0,total=0;cudaMemGetInfo(&before,&total);
    DeltaNetSession s(c,w,j.value("budget",uint64_t(64)<<20),j.value("headroom",uint64_t(256)<<20));
    cudaMemGetInfo(&after,&total);
    s.reset(j.value("initial_state",std::vector<float>{}),j.value("initial_history",std::vector<float>{}));
    if(j.value("mixer_state_test",false)) {
      AttentionConfig fc{c.hidden,2,1,4,2,8,4,10000.,1e-6};
      AttentionWeights fw;fw.qg.resize(16*c.hidden);fw.k.resize(4*c.hidden);fw.v.resize(4*c.hidden);fw.o.resize(8*c.hidden);fw.qnorm.resize(4);fw.knorm.resize(4);
      MixerState full(std::make_unique<FullAttentionSession>(fc,fw,64ULL<<20,256ULL<<20),77);
      MixerState linear(std::make_unique<DeltaNetSession>(c,w,64ULL<<20,256ULL<<20),88);
      auto x=j.at("calls")[0].at("x").get<std::vector<float>>();x.resize(c.hidden);
      bool rejected=false;try{linear.forward(x,0,77,true);}catch(const std::invalid_argument&){rejected=true;}
      auto ft=full.forward(x,0,77,true),lt=linear.forward(x,0,88,true);
      json result={{"owner_rejected",rejected},{"full_kind",full.kind(77)==neurx::runtime::model::MixerKind::full_attention},
                   {"linear_kind",linear.kind(88)==neurx::runtime::model::MixerKind::linear_attention},
                   {"full_trace",std::holds_alternative<AttentionTrace>(ft)},{"linear_trace",std::holds_alternative<DeltaTrace>(lt)},
                   {"full_output",std::get<AttentionTrace>(ft).output},{"linear_output",std::get<DeltaTrace>(lt).output},
                   {"full_length",full.length(77)},{"linear_length",linear.length(88)}};
      full.reset(77);linear.reset(88);result["reset_lengths"]={full.length(77),linear.length(88)};
      std::cout<<result.dump()<<'\n';return 0;
    }
    json result=json::array();
    for(auto& call:j.at("calls")) {
      try {
        if(call.contains("reset")){s.reset();result.push_back({{"reset",true}});continue;}
        auto t=s.forward(call.at("x").get<std::vector<float>>(),call.at("position"),true);
        if(call.value("summary_only",false)) {
          uint64_t capacity=uint64_t(t.output.capacity()+t.core.capacity()+t.state.capacity()+t.history.capacity()+t.q.capacity()+t.k.capacity()+t.beta.capacity()+t.decay.capacity())*sizeof(float);
          result.push_back({{"trace_capacity_bytes",capacity},{"length",s.length()}});continue;
        }
        result.push_back({{"output",t.output},{"core",t.core},{"state",t.state},{"history",t.history},
                          {"q",t.q},{"k",t.k},{"beta",t.beta},{"decay",t.decay},{"length",s.length()}});
      }catch(const std::exception& e){result.push_back({{"error",e.what()},{"length",s.length()}});}
    }
    json output={{"calls",result},{"allocated",s.allocated_bytes()},{"free_before",before},{"free_after",after}};
    if(selected_layer>=0) output["layer"]=selected_layer;
    std::cout<<output.dump()<<'\n';
  }catch(const std::exception& e){std::cout<<json({{"error",e.what()}}).dump()<<'\n';return 1;}
}
