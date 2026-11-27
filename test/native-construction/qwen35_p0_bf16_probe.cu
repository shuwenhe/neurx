#include "../../backend/platform/cuda/hybrid_deltanet_bf16.h"
#include "../../backend/platform/cuda/hybrid_deltanet_cuda.cu"
#include <nlohmann/json.hpp>
#include <cuda_bf16.h>
#include <iostream>
#include <limits>
using namespace neurx::cuda::hybrid;
using J=nlohmann::json;
int main(){try{
 J j;std::cin>>j;
 DeltaConfig c{j.at("hidden"),j.at("kh"),j.at("vh"),j.at("kd"),j.at("vd"),j.at("conv"),j.at("context"),j.at("chunk"),j.at("eps")};
 DeltaWeights w{j.at("qkv"),j.at("z"),j.at("a"),j.at("b"),j.at("conv_weight"),j.at("alog"),j.at("dt"),j.at("norm"),j.at("out")};
 DeltaNetBF16Session s(c,w,j.value("budget",256ULL<<20),256ULL<<20);
 DeltaNetSession fp32(c,w,j.value("budget",256ULL<<20),256ULL<<20);
 auto state=j.value("initial_state",std::vector<float>{}),history=j.value("initial_history",std::vector<float>{});s.reset(state,history);fp32.reset(state,history);
 if(j.value("lifecycle_tests",false)){
  J checks=J::object();auto input=j.at("calls")[0].at("x").get<std::vector<float>>();input.resize(c.hidden);
  auto rejects=[](auto fn){try{fn();return false;}catch(const std::exception&){return true;}};
  checks["position_rejected"]=rejects([&]{s.forward(input,1);});
  checks["shape_rejected"]=rejects([&]{s.forward(std::vector<float>(c.hidden+1),0);});
  checks["reset_shape_rejected"]=rejects([&]{s.reset({1.f});});
  checks["admission_rejected"]=rejects([&]{DeltaNetBF16Session rejected(c,w,1,0);});
  auto nonfinite=input;nonfinite[0]=std::numeric_limits<float>::infinity();
  checks["nonfinite_rejected"]=rejects([&]{s.forward(nonfinite,0);});
  auto overflow=input;overflow[0]=std::numeric_limits<float>::max();
  checks["bf16_overflow_rejected"]=rejects([&]{s.forward(overflow,0);});
  checks["failed_forward_invalidates"]=rejects([&]{s.forward(input,0);});
  s.reset();auto recovered=s.forward(input,0);checks["reset_recovers"]=s.length()==1 && !recovered.at("output").empty();
  s.reset();for(int i=0;i<c.context;++i)s.forward(input,i);
  checks["context_rejected"]=rejects([&]{s.forward(input,c.context);});
  std::cout<<checks.dump()<<'\n';return 0;
 }
 DeltaNetBF16Session::Trace all;std::vector<float> fp32_output,fp32_qkv,cast_output;
 auto check=[](cudaError_t e){if(e!=cudaSuccess)throw std::runtime_error(cudaGetErrorString(e));};
 // Diagnostic use of the unchanged native FP32 projection kernel.
 struct Buffers{float *x=nullptr,*weights=nullptr,*raw=nullptr;~Buffers(){cudaFree(raw);cudaFree(weights);cudaFree(x);}} buffers;
 auto& x=buffers.x;auto& weights=buffers.weights;auto& raw=buffers.raw;int width=2*c.key_heads*c.key_dim+c.value_heads*c.value_dim;
 check(cudaMalloc(&x,c.hidden*sizeof(float)));check(cudaMalloc(&weights,w.qkv.size()*sizeof(float)));check(cudaMalloc(&raw,width*sizeof(float)));
 check(cudaMemcpy(weights,w.qkv.data(),w.qkv.size()*sizeof(float),cudaMemcpyHostToDevice));
 for(auto& call:j.at("calls")){
  if(call.contains("reset")){s.reset();fp32.reset();continue;}
  auto input=call.at("x").get<std::vector<float>>();auto t=s.forward(input,call.at("position"));
  auto old=fp32.forward(input,call.at("position"),true);fp32_output.insert(fp32_output.end(),old.output.begin(),old.output.end());
  for(float v:old.output)cast_output.push_back(__bfloat162float(__float2bfloat16_rn(v)));
  for(size_t offset=0;offset<input.size();offset+=c.hidden){
   check(cudaMemcpy(x,input.data()+offset,c.hidden*sizeof(float),cudaMemcpyHostToDevice));
   delta_kernels::project<<<(width+255)/256,256>>>(x,weights,raw,1,c.hidden,width);check(cudaGetLastError());
   std::vector<float> sample(width);check(cudaMemcpy(sample.data(),raw,width*sizeof(float),cudaMemcpyDeviceToHost));fp32_qkv.insert(fp32_qkv.end(),sample.begin(),sample.end());
  }
  for(auto& field:t)all[field.first].insert(all[field.first].end(),field.second.begin(),field.second.end());
 }

 J out=all;out["storage"]="BF16";out["state_storage"]="FP32";out["accumulation"]="FP32";out["fp32_output"]=fp32_output;out["cast_only_output"]=cast_output;out["fp32_qkv"]=fp32_qkv;out["length"]=s.length();std::cout<<out.dump()<<'\n';
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
