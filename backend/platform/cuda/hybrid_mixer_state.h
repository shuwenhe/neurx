#pragma once
#include "hybrid_attention_cuda.h"
#include "hybrid_deltanet_cuda.h"
#include "../../../src/runtime/model/hybrid_config.h"
#include <stdexcept>
#include <utility>
#include <variant>
namespace neurx::cuda::hybrid {
using MixerTrace=std::variant<AttentionTrace,DeltaTrace>;
// Owning, tagged layer state. The decoder assigns a nonzero session owner ID;
// all operations validate it before touching either kind of GPU state.
// This is not a complete decoder, layer factory, residual or MoE implementation.
class MixerState {
 public:
  MixerState(std::unique_ptr<FullAttentionSession> session,uint64_t owner)
      :state_(std::move(session)),owner_(owner){validate(owner);}
  MixerState(std::unique_ptr<DeltaNetSession> session,uint64_t owner)
      :state_(std::move(session)),owner_(owner){validate(owner);}
  MixerState(const MixerState&)=delete;
  MixerState& operator=(const MixerState&)=delete;
  MixerState(MixerState&&) noexcept=default;
  MixerState& operator=(MixerState&&)=delete;
  neurx::runtime::model::MixerKind kind(uint64_t owner)const {
    validate(owner);
    return state_.index()==0 ? neurx::runtime::model::MixerKind::full_attention
                            : neurx::runtime::model::MixerKind::linear_attention;
  }
  int length(uint64_t owner)const {
    validate(owner);return std::visit([](const auto& p){return p->length();},state_);
  }
  void reset(uint64_t owner) {
    validate(owner);std::visit([](auto& p){p->reset();},state_);
  }
  MixerTrace forward(const std::vector<float>& input,int position,uint64_t owner,
                     bool trace=false) {
    validate(owner);
    return std::visit([&](auto& p)->MixerTrace{return p->forward(input,position,trace);},state_);
  }
 private:
  std::variant<std::unique_ptr<FullAttentionSession>,std::unique_ptr<DeltaNetSession>> state_;
  const uint64_t owner_;
  void validate(uint64_t owner)const {
    if(!owner_||owner!=owner_)throw std::invalid_argument("mixer state owner mismatch");
    if(std::visit([](const auto& p){return !p;},state_))
      throw std::invalid_argument("null or moved-from mixer state");
  }
};
}
