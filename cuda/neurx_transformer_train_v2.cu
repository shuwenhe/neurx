#include "transformer_kernels.cuh"
#include "training_policy.h"
#include "token_stream.h"
#include <cublas_v2.h>
#include <cuda_runtime.h>
#include "../distributed/nccl/nccl_compat.h"
#include <algorithm>
#include <cctype>
#include <chrono>
#include <climits>
#include <cmath>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <limits>
#include <map>
#include <memory>
#include <random>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>
using namespace neurx_cuda_transformer;
namespace {
#define CUDA_CHECK(x) do { cuda_error_t e=(x); if(e!=cuda_success){ \
  std::fprintf(stderr,"CUDA error %s:%d: %s\n",__FILE__,__LINE__,cuda_get_error_string(e)); return false; } } while(0)
#define CUBLAS_CHECK(x) do { cublas_status_t e=(x); if(e!=CUBLAS_STATUS_SUCCESS){ \
  std::fprintf(stderr,"cuBLAS error %s:%d: %d\n",__FILE__,__LINE__,int(e)); return false; } } while(0)
static int env_int(const char *n,int d){const char*s=std::getenv(n);return s&&*s?std::atoi(s):d;}
static float env_float(const char*n,float d){const char*s=std::getenv(n);return s&&*s?std::strtof(s,nullptr):d;}
static std::string env_str(const char*n,const std::string&d){const char*s=std::getenv(n);return s&&*s?s:d;}
static uint64_t fnv1a(const std::string&s){uint64_t h=1469598103934665603ULL;for(unsigned char c:s){h^=c;h*=1099511628211ULL;}return h;}
static bool exists(const std::string&p){return std::filesystem::exists(p);}
static bool nccl_ok(nccl_result_t e,const char*expr){if(e==nccl_success)return true;std::fprintf(stderr,"NCCL error %s: %s\n",expr,nccl_get_error_string(e));return false;}
#define NCCL_CHECK(x) do{if(!nccl_ok((x),#x))return false;}while(0)
struct param {
  float *v=nullptr,*g=nullptr,*m=nullptr,*s=nullptr; int64_t n=0;
  bool apply_weight_decay=true;
  explicit param(int64_t count=0,bool decay=true):n(count),apply_weight_decay(decay){
    if(!n)return; cuda_malloc_managed(&v,n*4);
#ifndef NEURX_INFERENCE_ONLY
    cuda_malloc_managed(&g,n*4);
    cuda_malloc_managed(&m,n*4);cuda_malloc_managed(&s,n*4);
    cuda_memset(g,0,n*4);cuda_memset(m,0,n*4);cuda_memset(s,0,n*4);
#endif
  }
  param(const param&)=delete; param&operator=(const param&)=delete;
  ~param(){if(v)cuda_free(v);if(g)cuda_free(g);if(m)cuda_free(m);if(s)cuda_free(s);}
};
struct layer {
  int d,f; param nq,nk,wq,wk,wv,wo,nf,wg,wu,wd;
  layer(int dim,int ffn):d(dim),f(ffn),nq(d,false),nk(d,false),wq(d*d),wk(d*d),wv(d*d),wo(d*d),nf(d,false),wg(d*f),wu(d*f),wd(f*d){}
  std::vector<param*> params(){return{&nq,&wq,&wk,&wv,&wo,&nf,&wg,&wu,&wd};}
};
struct model {
  int vocab,seq,dim,heads,ffn,nlayers; param emb,out; std::vector<std::unique_ptr<layer>> layers;
  uint32_t seed;
  model(int v,int t,int d,int h,int f,int n,uint32_t init_seed=1337):vocab(v),seq(t),dim(d),heads(h),ffn(f),nlayers(n),emb(int64_t(v)*d),out(int64_t(d)*v),seed(init_seed){
    for(int i=0;i<n;i++)layers.emplace_back(std::make_unique<layer>(d,f));
#ifndef NEURX_INFERENCE_ONLY
    init();
#endif
  }
  std::vector<param*> params(){std::vector<param*>p{&emb};for(auto&l:layers){auto q=l->params();p.insert(p.end(),q.begin(),q.end());}p.push_back(&out);return p;}
  void init(){std::mt19937 rng(seed);std::normal_distribution<float>nd(0,.02f);for(param*p:params())for(int64_t i=0;i<p->n;i++)p->v[i]=nd(rng);for(auto&l:layers)for(int i=0;i<dim;i++){l->nq.v[i]=1;l->nk.v[i]=1;l->nf.v[i]=1;}}
};
struct layer_cache {
  float *x,*n1,*iq,*ik,*q,*k,*v,*att,*ctx,*proj,*res,*n2,*iff,*gate,*up,*sw,*down,*h;
  float *dout,*dres,*dsw,*dg,*du,*dn2,*tmp,*dctx,*dq,*dk,*dv,*dn1,*dx;
};
static float* managed_f(int64_t n){float*p=nullptr;cuda_malloc_managed(&p,n*4);return p;}
static int* managed_i(int64_t n){int*p=nullptr;cuda_malloc_managed(&p,n*4);return p;}
static layer_cache make_layer_cache(int t,int d,int f,int heads){layer_cache a{};int64_t td=int64_t(t)*d,tf=int64_t(t)*f;
  a.x=managed_f(td);a.n1=managed_f(td);a.iq=managed_f(t);a.ik=managed_f(t);a.q=managed_f(td);a.k=managed_f(td);a.v=managed_f(td);
  a.att=managed_f(int64_t(heads)*t*t);a.ctx=managed_f(td);a.proj=managed_f(td);a.res=managed_f(td);a.n2=managed_f(td);a.iff=managed_f(t);
  a.gate=managed_f(tf);a.up=managed_f(tf);a.sw=managed_f(tf);a.down=managed_f(td);a.h=managed_f(td);a.dout=managed_f(td);a.dres=managed_f(td);
  a.dsw=managed_f(tf);a.dg=managed_f(tf);a.du=managed_f(tf);a.dn2=managed_f(td);a.tmp=managed_f(std::max(td,tf));a.dctx=managed_f(td);
  a.dq=managed_f(td);a.dk=managed_f(td);a.dv=managed_f(td);a.dn1=managed_f(td);a.dx=managed_f(td);return a;}
struct train_cache {int*ids,*targets;float*embedding,*logits,*loss,*dl,*dh;std::vector<layer_cache>lc;
  train_cache(model&m){int64_t td=int64_t(m.seq)*m.dim,tv=int64_t(m.seq)*m.vocab;ids=managed_i(m.seq);targets=managed_i(m.seq);embedding=managed_f(td);logits=managed_f(tv);loss=managed_f(1);dl=managed_f(tv);dh=managed_f(td);for(int i=0;i<m.nlayers;i++)lc.push_back(make_layer_cache(m.seq,m.dim,m.ffn,m.heads));}
};
static cublas_handle_t blas=nullptr;
static bool gemm(float*a,float*b,float*c,int m,int k,int n){if(!blas)CUBLAS_CHECK(cublas_create(&blas));const float one=1,zero=0;CUBLAS_CHECK(cublas_sgemm(blas,CUBLAS_OP_N,CUBLAS_OP_N,n,m,k,&one,b,n,a,k,&zero,c,n));return true;}
static bool backward_linear(float*x,param&w,float*dy,float*dx,int m,int k,int n){if(!blas)CUBLAS_CHECK(cublas_create(&blas));const float one=1,zero=0;
  CUBLAS_CHECK(cublas_sgemm(blas,CUBLAS_OP_T,CUBLAS_OP_N,k,m,n,&one,w.v,n,dy,n,&zero,dx,k));
  CUBLAS_CHECK(cublas_sgemm(blas,CUBLAS_OP_N,CUBLAS_OP_T,n,k,m,&one,dy,n,x,k,&one,w.g,n));return true;}
static void zero_grads(model&m){for(param*p:m.params())cuda_memset(p->g,0,p->n*4);}
__global__ void scale_values(float*x,int64_t n,float scale){int64_t i=int64_t(block_idx.x)*block_dim.x+thread_idx.x;if(i<n)x[i]*=scale;}
struct distributed_context {int rank=0,world=1,local_rank=0;nccl_comm_t comm=nullptr;cuda_stream_t stream=nullptr;};
static bool read_nccl_id(const std::string&path,nccl_unique_id&id){std::ifstream f(path,std::ios::binary);if(!f)return false;f.read(reinterpret_cast<char*>(&id),sizeof(id));return bool(f);}
static bool write_nccl_id(const std::string&path,const nccl_unique_id&id){std::string tmp=path+".tmp";std::ofstream f(tmp,std::ios::binary|std::ios::trunc);f.write(reinterpret_cast<const char*>(&id),sizeof(id));f.close();if(!f)return false;std::error_code ec;std::filesystem::rename(tmp,path,ec);return!ec;}
static bool init_distributed(distributed_context&d){
  d.rank=std::max(0,env_int("RANK",0));d.world=std::max(1,env_int("WORLD_SIZE",1));d.local_rank=std::max(0,env_int("LOCAL_RANK",d.rank));
  if(d.rank>=d.world)return false;CUDA_CHECK(cuda_set_device(d.local_rank));CUDA_CHECK(cuda_stream_create(&d.stream));
  if(d.world==1)return true;std::string id_path=env_str("NEURX_NCCL_ID_FILE","/tmp/neurx_nccl_id");nccl_unique_id id{};
  if(d.rank==0){NCCL_CHECK(nccl_get_unique_id(&id));if(!write_nccl_id(id_path,id)){std::fprintf(stderr,"cannot write NCCL id: %s\n",id_path.c_str());return false;}}
  else {for(int i=0;i<600&&!read_nccl_id(id_path,id);i++)std::this_thread::sleep_for(std::chrono::milliseconds(100));if(!read_nccl_id(id_path,id))return false;}
  NCCL_CHECK(nccl_comm_init_rank(&d.comm,d.world,id,d.rank));return true;
}
static bool sync_gradients(model&m,distributed_context&d){if(d.world==1)return true;for(param*p:m.params())NCCL_CHECK(nccl_all_reduce(p->g,p->g,p->n,nccl_float,nccl_sum,d.comm,d.stream));CUDA_CHECK(cuda_stream_synchronize(d.stream));for(param*p:m.params())scale_values<<<blocks(p->n),256,0,d.stream>>>(p->g,p->n,1.0f/float(d.world));CUDA_CHECK(cuda_stream_synchronize(d.stream));return true;}
static bool squared_l2_norm(const std::vector<param*>&params,
                            float* param::*member,double&result){
  if(!blas)CUBLAS_CHECK(cublas_create(&blas));
  result=0.0;
  for(param*p:params){
    float*ptr=p->*member;
    if(!ptr||p->n==0)continue;
    if(p->n>INT32_MAX){std::fprintf(stderr,"tensor too large for cuBLAS norm: %lld\n",(long long)p->n);return false;}
    float norm=0.0f;
    CUBLAS_CHECK(cublas_snrm2(blas,int(p->n),ptr,1,&norm));
    if(!std::isfinite(norm)){result=std::numeric_limits<double>::quiet__na_n();return true;}
    result+=double(norm)*double(norm);
  }
  return true;
}
static bool optimizer_state_is_finite(model&m){
  auto params=m.params();
  double value_norm=0.0,first_norm=0.0,second_norm=0.0;
  if(!squared_l2_norm(params,&param::v,value_norm)||
     !squared_l2_norm(params,&param::m,first_norm)||
     !squared_l2_norm(params,&param::s,second_norm))return false;
  return std::isfinite(value_norm)&&std::isfinite(first_norm)&&std::isfinite(second_norm);
}
__global__ void rms_dg_accum(const float*x,const float*inv,const float*dy,float*dg,int rows,int d){int j=block_idx.x*block_dim.x+thread_idx.x;if(j>=d)return;float s=0;for(int r=0;r<rows;r++)s+=dy[r*d+j]*x[r*d+j]*inv[r];dg[j]+=s;}
static bool forward_backward(model&m,train_cache&a){int t=m.seq,d=m.dim,f=m.ffn,v=m.vocab,td=t*d,tf=t*f;
  embedding_fwd<<<blocks(td),256>>>(a.ids,m.emb.v,a.embedding,t,d);float*input=a.embedding;
  for(int li=0;li<m.nlayers;li++){layer&l=*m.layers[li];layer_cache&c=a.lc[li];CUDA_CHECK(cuda_memcpy(c.x,input,td*4,cuda_memcpy_device_to_device));
    rms_fwd<<<blocks(t),256>>>(c.x,l.nq.v,c.n1,c.iq,t,d);if(!gemm(c.n1,l.wq.v,c.q,t,d,d)||!gemm(c.n1,l.wk.v,c.k,t,d,d)||!gemm(c.n1,l.wv.v,c.v,t,d,d))return false;
    int rope_items=t*m.heads*(d/m.heads/2);rope<<<blocks(rope_items),256>>>(c.q,t,d,m.heads,false);rope<<<blocks(rope_items),256>>>(c.k,t,d,m.heads,false);attention_fwd<<<m.heads*t,1>>>(c.q,c.k,c.v,c.att,c.ctx,t,d,m.heads);
    if(!gemm(c.ctx,l.wo.v,c.proj,t,d,d))return false;add<<<blocks(td),256>>>(c.x,c.proj,c.res,td);rms_fwd<<<blocks(t),256>>>(c.res,l.nf.v,c.n2,c.iff,t,d);
    if(!gemm(c.n2,l.wg.v,c.gate,t,d,f)||!gemm(c.n2,l.wu.v,c.up,t,d,f))return false;swiglu_fwd<<<blocks(tf),256>>>(c.gate,c.up,c.sw,tf);
    if(!gemm(c.sw,l.wd.v,c.down,t,f,d))return false;add<<<blocks(td),256>>>(c.res,c.down,c.h,td);input=c.h;
  }
  if(!gemm(input,m.out.v,a.logits,t,d,v))return false;cuda_memset(a.loss,0,4);cross_entropy_fwd_bwd<<<blocks(t),256>>>(a.logits,a.targets,a.loss,a.dl,t,v);
  if(!backward_linear(input,m.out,a.dl,a.dh,t,d,v))return false;float*upstream=a.dh;
  for(int li=m.nlayers-1;li>=0;li--){layer&l=*m.layers[li];layer_cache&c=a.lc[li];CUDA_CHECK(cuda_memcpy(c.dout,upstream,td*4,cuda_memcpy_device_to_device));CUDA_CHECK(cuda_memcpy(c.dres,c.dout,td*4,cuda_memcpy_device_to_device));
    if(!backward_linear(c.sw,l.wd,c.dout,c.dsw,t,f,d))return false;swiglu_bwd<<<blocks(tf),256>>>(c.gate,c.up,c.dsw,c.dg,c.du,tf);
    if(!backward_linear(c.n2,l.wg,c.dg,c.dn2,t,d,f)||!backward_linear(c.n2,l.wu,c.du,c.tmp,t,d,f))return false;add_inplace<<<blocks(td),256>>>(c.dn2,c.tmp,td);
    rms_dx<<<blocks(t),256>>>(c.res,l.nf.v,c.iff,c.dn2,c.tmp,t,d);rms_dg_accum<<<blocks(d),256>>>(c.res,c.iff,c.dn2,l.nf.g,t,d);add_inplace<<<blocks(td),256>>>(c.dres,c.tmp,td);
    if(!backward_linear(c.ctx,l.wo,c.dres,c.dctx,t,d,d))return false;cuda_memset(c.dq,0,td*4);cuda_memset(c.dk,0,td*4);cuda_memset(c.dv,0,td*4);
    attention_bwd<<<m.heads*t,1,2*t*sizeof(float)>>>(c.q,c.k,c.v,c.att,c.dctx,c.dq,c.dk,c.dv,t,d,m.heads);int rope_items=t*m.heads*(d/m.heads/2);rope<<<blocks(rope_items),256>>>(c.dq,t,d,m.heads,true);rope<<<blocks(rope_items),256>>>(c.dk,t,d,m.heads,true);
    if(!backward_linear(c.n1,l.wq,c.dq,c.dn1,t,d,d)||!backward_linear(c.n1,l.wk,c.dk,c.tmp,t,d,d))return false;add_inplace<<<blocks(td),256>>>(c.dn1,c.tmp,td);
    if(!backward_linear(c.n1,l.wv,c.dv,c.tmp,t,d,d))return false;add_inplace<<<blocks(td),256>>>(c.dn1,c.tmp,td);rms_dx<<<blocks(t),256>>>(c.x,l.nq.v,c.iq,c.dn1,c.dx,t,d);rms_dg_accum<<<blocks(d),256>>>(c.x,c.iq,c.dn1,l.nq.g,t,d);add_inplace<<<blocks(td),256>>>(c.dx,c.dres,td);upstream=c.dx;
  }
  embedding_bwd<<<blocks(td),256>>>(a.ids,upstream,m.emb.g,t,d);CUDA_CHECK(cuda_device_synchronize());return true;
}
static bool optimizer_step(model&m,int step,float lr,float grad_scale,float weight_decay){for(param*p:m.params()){scale_values<<<blocks(p->n),256>>>(p->g,p->n,grad_scale);const float decay=p->apply_weight_decay?weight_decay:0.0f;adamw<<<blocks(p->n),256>>>(p->v,p->g,p->m,p->s,p->n,step,lr,decay);}CUDA_CHECK(cuda_device_synchronize());return true;}
static std::string json_unescape(const std::string&s){std::string o;for(size_t i=0;i<s.size();i++){char c=s[i];if(c!='\\'||i+1>=s.size()){o+=c;continue;}char e=s[++i];if(e=='n')o+='\n';else if(e=='r')o+='\r';else if(e=='t')o+='\t';else if(e=='b')o+='\b';else if(e=='f')o+='\f';else if(e=='"'||e=='\\'||e=='/')o+=e;else if(e=='u'&&i+4<s.size()){unsigned cp=0;for(int j=0;j<4;j++){char h=s[++i];cp=cp*16+(h>='0'&&h<='9'?h-'0':std::tolower(h)-'a'+10);}if(cp<128)o+=char(cp);else if(cp<2048){o+=char(0xc0|(cp>>6));o+=char(0x80|(cp&63));}else{o+=char(0xe0|(cp>>12));o+=char(0x80|((cp>>6)&63));o+=char(0x80|(cp&63));}}}return o;}
static bool parse_json_string(const std::string&s,size_t&p,std::string&out){while(p<s.size()&&std::isspace((unsigned char)s[p]))p++;if(p>=s.size()||s[p]!='"')return false;p++;std::string raw;bool esc=false;for(;p<s.size();p++){char c=s[p];if(!esc&&c=='"'){p++;out=json_unescape(raw);return true;}raw+=c;if(!esc&&c=='\\')esc=true;else esc=false;}return false;}
static std::string extract_json_string_field(const std::string&line,const std::string&field){size_t p=0;while(p<line.size()){std::string key;if(!parse_json_string(line,p,key)){p++;continue;}while(p<line.size()&&std::isspace((unsigned char)line[p]))p++;if(p>=line.size()||line[p++]!=':')continue;if(key==field){std::string value;if(parse_json_string(line,p,value))return value;return{};}std::string ignored;if(!parse_json_string(line,p,ignored)){while(p<line.size()&&line[p]!=',')p++;}}return{};}
static std::string extract_text(const std::string&line){std::string value=extract_json_string_field(line,"text");if(value.empty())value=extract_json_string_field(line,"content");if(value.empty())value=extract_json_string_field(line,"xml");return value;}
struct tokenizer {
  std::string kind="byte_level",vocab_path,merges_path;std::unordered_map<std::string,int>vocab;std::map<std::pair<std::string,std::string>,int>rank;int unk=0,eos=-1;uint64_t fingerprint=0;
  bool load(const std::string&vp,const std::string&mp){vocab_path=vp;merges_path=mp;if(vp.empty()){kind="byte_level";return true;}kind="bpe";std::ifstream in(vp);if(!in){std::fprintf(stderr,"cannot open BPE vocab: %s\n",vp.c_str());return false;}std::stringstream ss;ss<<in.rdbuf();std::string j=ss.str();size_t p=0;while(p<j.size()){std::string token;if(!parse_json_string(j,p,token)){p++;continue;}while(p<j.size()&&std::isspace((unsigned char)j[p]))p++;if(p>=j.size()||j[p++]!=':')continue;while(p<j.size()&&std::isspace((unsigned char)j[p]))p++;char*end=nullptr;long id=std::strtol(j.c_str()+p,&end,10);if(end!=j.c_str()+p){vocab[token]=int(id);p=size_t(end-j.c_str());}}
    if(vocab.empty()){std::fprintf(stderr,"BPE vocab has no token/id entries\n");return false;}for(auto n:{"<unk>","[UNK]","<|endoftext|>"})if(vocab.count(n)){unk=vocab[n];break;}for(auto n:{"</s>","<eos>","<|endoftext|>"})if(vocab.count(n)){eos=vocab[n];break;}
    std::ifstream mi(mp);if(!mi){std::fprintf(stderr,"cannot open BPE merges: %s\n",mp.c_str());return false;}std::string line,merge_text;int r=0;while(std::getline(mi,line)){merge_text+=line;merge_text+='\n';if(line.empty()||line[0]=='#')continue;std::istringstream ls(line);std::string a,b;if(ls>>a>>b)rank[{a,b}]=r++;}fingerprint=fnv1a(j+"\n"+merge_text);return true;}
  int size()const{if(kind=="byte_level")return 256;int mx=0;for(auto&x:vocab)mx=std::max(mx,x.second);return mx+1;}
#if 0
  std::vector<int> encode(const std::string&text)const{if(kind=="byte_level")return std::vector<int>(text.begin(),text.end());std::vector<std::string>pieces;for(size_t i=0;i<text.size();){if(std::isspace((unsigned char)text[i])){pieces.push_back(std::string(1,text[i++]));continue;}size_t j=i+1;while(j<text.size()&&!std::isspace((unsigned char)text[j]))j++;std::vector<std::string>w;for(size_t k=i;k<j;k++)w.emplace_back(1,text[k]);while(w.size()>1){int best=INT32_MAX,at=-1;for(size_t k=0;k+1<w.size();k++){auto q=rank.find({w[k],w[k+1]});if(q!=rank.end()&&q->second<best){best=q->second;at=int(k);}}if(at<0)break;w[at]+=w[at+1];w.erase(w.begin()+at+1);}pieces.insert(pieces.end(),w.begin(),w.end());i=j;}std::vector<int>ids;for(auto&p:pieces){auto it=vocab.find(p);if(it!=vocab.end())ids.push_back(it->second);else for(unsigned char c:p){auto q=vocab.find(std::string(1,char(c)));ids.push_back(q==vocab.end()?unk:q->second);}}if(eos>=0)ids.push_back(eos);return ids;}
#endif
  std::vector<int> encode(const std::string&text)const{
    if(kind=="byte_level"){std::vector<int>ids;ids.reserve(text.size());for(unsigned char c:text)ids.push_back(c);return ids;}
    std::vector<std::string>pieces;
    for(size_t i=0;i<text.size();){
      if(std::isspace((unsigned char)text[i])){pieces.push_back(std::string(1,text[i++]));continue;}
      size_t j=i+1;while(j<text.size()&&!std::isspace((unsigned char)text[j]))j++;
      std::vector<std::string>w;for(size_t k=i;k<j;k++)w.emplace_back(1,text[k]);
      while(w.size()>1){int best=INT32_MAX,at=-1;for(size_t k=0;k+1<w.size();k++){auto q=rank.find({w[k],w[k+1]});if(q!=rank.end()&&q->second<best){best=q->second;at=int(k);}}if(at<0)break;w[at]+=w[at+1];w.erase(w.begin()+at+1);}
      pieces.insert(pieces.end(),w.begin(),w.end());i=j;
    }
    std::vector<int>ids;for(auto&p:pieces){auto it=vocab.find(p);if(it!=vocab.end())ids.push_back(it->second);else for(unsigned char c:p){auto q=vocab.find(std::string(1,char(c)));ids.push_back(q==vocab.end()?unk:q->second);}}
    if(eos>=0)ids.push_back(eos);return ids;
  }
};
struct cursor {int shard=0;uint64_t line=0,docs=0;std::vector<int>pending;};
struct jsonl_stream {std::vector<std::string>shards;tokenizer*tok;cursor cur;std::ifstream in;
  bool load_list(const std::string&p){std::ifstream f(p);std::string s;while(std::getline(f,s))if(!s.empty())shards.push_back(s);return!shards.empty();}
  bool open_cursor(){in.close();if(cur.shard>=int(shards.size()))cur.shard=0;in.open(shards[cur.shard]);if(!in)return false;std::string skip;for(uint64_t i=0;i<cur.line&&std::getline(in,skip);i++);return true;}
  bool next_doc(){int exhausted=0;for(;;){if(!in.is_open()&&!open_cursor())return false;std::string line;if(std::getline(in,line)){cur.line++;std::string text=extract_text(line);if(text.empty())continue;std::vector<int>encoded=tok->encode(text);cur.docs++;if(!encoded.empty()){neurx_training::append_document_tokens(cur.pending,encoded);return true;}}else{in.close();cur.shard++;cur.line=0;exhausted++;if(exhausted>=int(shards.size())){std::fprintf(stderr,"no non-empty JSONL text fields found in one complete shard pass\n");return false;}if(cur.shard>=int(shards.size()))cur.shard=0;}}}
  bool sequence(std::vector<int>&ids){const size_t sequence_length=ids.empty()?0:ids.size()-1;while(cur.pending.size()<sequence_length+1)if(!next_doc())return false;return neurx_training::take_training_window(cur.pending,sequence_length,ids);}
};
static bool validation_loss(model&m,train_cache&cache,jsonl_stream&reader,
                            distributed_context&dist,int batches,double&mean_loss){
  reader.in.close();reader.cur=cursor{};
  zero_grads(m);
  std::vector<int>ids(m.seq+1);
  double local_loss=0.0;
  for(int batch=0;batch<batches;batch++){
    if(!reader.sequence(ids)){std::fprintf(stderr,"validation stream could not produce a complete sequence\n");return false;}
    for(int i=0;i<m.seq;i++){cache.ids[i]=ids[i];cache.targets[i]=ids[i+1];}
    if(!forward_backward(m,cache))return false;
    if(!std::isfinite(*cache.loss)){std::fprintf(stderr,"non-finite validation loss\n");return false;}
    local_loss+=double(*cache.loss);
  }
  zero_grads(m);
  if(dist.world==1){mean_loss=local_loss/double(batches);return true;}
  double*metrics=nullptr;CUDA_CHECK(cuda_malloc_managed(&metrics,2*sizeof(double)));
  metrics[0]=local_loss;metrics[1]=double(batches);
  nccl_result_t reduced=nccl_all_reduce(metrics,metrics,2,nccl_double,nccl_sum,dist.comm,dist.stream);
  if(reduced!=nccl_success){std::fprintf(stderr,"NCCL validation reduction failed: %s\n",nccl_get_error_string(reduced));cuda_free(metrics);return false;}
  cuda_error_t synchronized=cuda_stream_synchronize(dist.stream);
  if(synchronized!=cuda_success){std::fprintf(stderr,"CUDA validation synchronization failed: %s\n",cuda_get_error_string(synchronized));cuda_free(metrics);return false;}
  mean_loss=metrics[0]/metrics[1];cuda_free(metrics);return std::isfinite(mean_loss);
}
static std::string read_text_file(const std::string&path){
  std::ifstream in(path,std::ios::binary);
  if(!in)return{};
  std::ostringstream out;out<<in.rdbuf();return out.str();
}
static std::string hex64(uint64_t value){
  std::ostringstream out;out<<std::hex<<std::setfill('0')<<std::setw(16)<<value;return out.str();
}
static std::string json_escape(const std::string&value){
  std::ostringstream out;
  for(unsigned char c:value){
    if(c=='"'||c=='\\')out<<'\\'<<char(c);
    else if(c=='\n')out<<"\\n";
    else if(c=='\r')out<<"\\r";
    else if(c=='\t')out<<"\\t";
    else if(c<0x20)out<<"\\u"<<std::hex<<std::setw(4)<<std::setfill('0')<<int(c)<<std::dec;
    else out<<char(c);
  }
  return out.str();
}
struct run_config {
  int vocab=0,seq=0,dim=0,heads=0,ffn=0,layers=0,micro_batch=0,grad_accum=0,eval_batches=0;
  int rank=0,world_size=1;
  uint32_t seed=0;
  uint64_t total_steps=0,warmup_steps=0,eval_interval=0;
  float peak_lr=0.0f,min_lr=0.0f,max_grad_norm=0.0f,weight_decay=0.0f;
  std::string schedule,tokenizer_kind,tokenizer_hash,shard_list_path,shard_list_hash;
  std::string validation_source,validation_hash,git_sha;
};
static std::string run_config_canonical(const run_config&c){
  std::ostringstream out;
  out<<"vocab="<<c.vocab<<"\nseq="<<c.seq<<"\ndim="<<c.dim<<"\nheads="<<c.heads
     <<"\nffn="<<c.ffn<<"\nlayers="<<c.layers<<"\nmicro_batch="<<c.micro_batch
     <<"\ngrad_accum="<<c.grad_accum<<"\neval_batches="<<c.eval_batches
     <<"\nrank="<<c.rank<<"\nworld_size="<<c.world_size
     <<"\nseed="<<c.seed<<"\ntotal_steps="<<c.total_steps<<"\nwarmup_steps="<<c.warmup_steps
     <<"\neval_interval="<<c.eval_interval
     <<"\npeak_lr="<<std::setprecision(9)<<c.peak_lr<<"\nmin_lr="<<c.min_lr
     <<"\nmax_grad_norm="<<c.max_grad_norm<<"\nweight_decay="<<c.weight_decay<<"\nschedule="<<c.schedule
     <<"\ntokenizer_kind="<<c.tokenizer_kind<<"\ntokenizer_hash="<<c.tokenizer_hash
     <<"\nshard_list_path="<<c.shard_list_path<<"\nshard_list_hash="<<c.shard_list_hash
     <<"\nvalidation_source="<<c.validation_source<<"\nvalidation_hash="<<c.validation_hash
     <<"\ngit_sha="<<c.git_sha<<"\n";
  return out.str();
}
static bool write_run_manifest(const std::string&directory,const run_config&c,
                               bool allow_mismatch){
  std::filesystem::create_directories(directory);
  const std::string fingerprint=hex64(fnv1a(run_config_canonical(c)));
  const std::string path=directory+"/run_manifest.json";
  if(exists(path)){
    const std::string old=read_text_file(path);
    const std::string needle="\"run_fingerprint\": \""+fingerprint+"\"";
    if(old.find(needle)!=std::string::npos)return true;
    if(!allow_mismatch){
      std::fprintf(stderr,
        "run manifest mismatch at %s; set NEURX_ALLOW_RUN_CONFIG_MISMATCH=1 only for an intentional new run\n",
        path.c_str());
      return false;
    }
  }
  const auto now=std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
  std::ostringstream json;
  json<<"{\n"
      <<"  \"format\": \"NEURX_RUN_MANIFEST_V1\",\n"
      <<"  \"run_fingerprint\": \""<<fingerprint<<"\",\n"
      <<"  \"created_unix\": "<<static_cast<long long>(now)<<",\n"
      <<"  \"git_sha\": \""<<json_escape(c.git_sha)<<"\",\n"
      <<"  \"seed\": "<<c.seed<<",\n"
      <<"  \"rank\": "<<c.rank<<",\n"
      <<"  \"world_size\": "<<c.world_size<<",\n"
      <<"  \"model\": {\"vocab_size\": "<<c.vocab<<", \"context_length\": "<<c.seq
      <<", \"hidden_size\": "<<c.dim<<", \"num_heads\": "<<c.heads
      <<", \"ffn_size\": "<<c.ffn<<", \"num_layers\": "<<c.layers<<"},\n"
      <<"  \"training\": {\"total_steps\": "<<c.total_steps<<", \"micro_batch_size\": "
      <<c.micro_batch<<", \"gradient_accumulation_steps\": "<<c.grad_accum
      <<", \"peak_lr\": "<<std::setprecision(9)<<c.peak_lr<<", \"min_lr\": "<<c.min_lr
      <<", \"warmup_steps\": "<<c.warmup_steps<<", \"lr_schedule\": \""
      <<json_escape(c.schedule)<<"\", \"max_grad_norm\": "<<c.max_grad_norm
      <<", \"weight_decay\": "<<c.weight_decay<<", \"eval_interval\": "<<c.eval_interval
      <<", \"eval_batches\": "<<c.eval_batches<<"},\n"
      <<"  \"tokenizer\": {\"kind\": \""<<json_escape(c.tokenizer_kind)
      <<"\", \"hash\": \""<<json_escape(c.tokenizer_hash)<<"\"},\n"
      <<"  \"data\": {\"shard_list\": \""<<json_escape(c.shard_list_path)
      <<"\", \"shard_list_hash\": \""<<json_escape(c.shard_list_hash)
      <<"\", \"validation_source\": \""<<json_escape(c.validation_source)
      <<"\", \"validation_hash\": \""<<json_escape(c.validation_hash)<<"\"}\n"
      <<"}\n";
  const std::string tmp=path+".tmp";
  std::ofstream out(tmp,std::ios::binary|std::ios::trunc);
  out<<json.str();out.close();
  if(!out)return false;
  std::error_code ec;
  std::filesystem::rename(tmp,path,ec);
  if(ec){
    std::filesystem::remove(path,ec);ec.clear();
    std::filesystem::rename(tmp,path,ec);
  }
  if(ec){std::fprintf(stderr,"cannot install run manifest: %s\n",ec.message().c_str());return false;}
  return true;
}
static double load_best_validation_loss(const std::string&directory){
  std::ifstream in(directory+"/best_validation_loss.txt");
  double value=std::numeric_limits<double>::infinity();
  if(in>>value&&std::isfinite(value))return value;
  return std::numeric_limits<double>::infinity();
}
static bool save_best_validation_loss(const std::string&directory,double value){
  const std::string path=directory+"/best_validation_loss.txt",tmp=path+".tmp";
  std::ofstream out(tmp,std::ios::trunc);out<<std::setprecision(17)<<value<<"\n";out.close();
  if(!out)return false;
  std::error_code ec;std::filesystem::rename(tmp,path,ec);
  if(ec){std::filesystem::remove(path,ec);ec.clear();std::filesystem::rename(tmp,path,ec);}
  return !ec;
}
#pragma pack(push,1)
struct header_v1{char magic[8];int32_t version,step,cursor,vocab,seq,dim,heads,ffn;};
struct header_v2{char magic[8];uint32_t version,header_bytes;uint64_t step,optimizer_step,micro_step,shard,line,docs,tokens;uint32_t vocab,seq,dim,heads,ffn,layers,micro_batch,grad_accum,tokenizer_kind,vocab_path_bytes,merges_path_bytes;uint64_t tokenizer_hash,pending_count,param_count;};
struct checkpoint_footer_v3{char magic[8];uint64_t payload_bytes,checksum;};
#pragma pack(pop)
static bool write_blob(std::ofstream&o,const void*p,size_t n){o.write((const char*)p,n);return bool(o);}
static bool file_checksum(const std::string&path,uint64_t bytes,uint64_t&checksum){
  std::ifstream in(path,std::ios::binary);if(!in)return false;
  checksum=1469598103934665603ULL;std::vector<char>buffer(1<<20);uint64_t remaining=bytes;
  while(remaining){size_t count=size_t(std::min<uint64_t>(remaining,buffer.size()));in.read(buffer.data(),count);if(size_t(in.gcount())!=count)return false;for(size_t i=0;i<count;i++){checksum^=static_cast<unsigned char>(buffer[i]);checksum*=1099511628211ULL;}remaining-=count;}
  return true;
}
static bool save_v2(model&m,tokenizer&t,jsonl_stream&r,const std::string&dir,uint64_t step,uint64_t opt,uint64_t micro,int mb,int ga,uint64_t tokens){cuda_device_synchronize();std::filesystem::create_directories(dir);std::string tmp=dir+"/transformer_v2.ckpt.tmp",dst=dir+"/transformer_v2.ckpt";std::ofstream o(tmp,std::ios::binary|std::ios::trunc);auto ps=m.params();header_v2 h{};std::memcpy(h.magic,"NXTRFMV2",8);h.version=3;h.header_bytes=sizeof(h);h.step=step;h.optimizer_step=opt;h.micro_step=micro;h.shard=r.cur.shard;h.line=r.cur.line;h.docs=r.cur.docs;h.tokens=tokens;h.vocab=m.vocab;h.seq=m.seq;h.dim=m.dim;h.heads=m.heads;h.ffn=m.ffn;h.layers=m.nlayers;h.micro_batch=mb;h.grad_accum=ga;h.tokenizer_kind=t.kind=="bpe"?1:0;h.vocab_path_bytes=t.vocab_path.size();h.merges_path_bytes=t.merges_path.size();h.tokenizer_hash=t.fingerprint;h.pending_count=r.cur.pending.size();h.param_count=ps.size();write_blob(o,&h,sizeof(h));write_blob(o,t.vocab_path.data(),h.vocab_path_bytes);write_blob(o,t.merges_path.data(),h.merges_path_bytes);if(h.pending_count)write_blob(o,r.cur.pending.data(),h.pending_count*4);for(param*p:ps){uint64_t n=p->n;write_blob(o,&n,8);write_blob(o,p->v,n*4);write_blob(o,p->g,n*4);write_blob(o,p->m,n*4);write_blob(o,p->s,n*4);}o.close();if(!o)return false;std::error_code size_error;uint64_t payload_bytes=std::filesystem::file_size(tmp,size_error),checksum=0;if(size_error||!file_checksum(tmp,payload_bytes,checksum))return false;checkpoint_footer_v3 footer{};std::memcpy(footer.magic,"NXHASH01",8);footer.payload_bytes=payload_bytes;footer.checksum=checksum;std::ofstream append(tmp,std::ios::binary|std::ios::app);if(!write_blob(append,&footer,sizeof(footer))){return false;}append.close();std::filesystem::rename(tmp,dst);
  std::string model_name=env_str("NEURX_PRETRAIN_MODEL_NAME","NeurX-1.3");std::string model_path=dir+"/"+model_name+".neurx";std::ofstream meta(model_path);meta<<"{\n  \"model_name\": \""<<model_name<<"\",\n  \"format\": \"NXTRFMV2\",\n  \"architecture\": \"decoder_only_transformer\",\n  \"tokenizer\": \""<<t.kind<<"\",\n  \"tokenizer_hash\": \""<<std::hex<<t.fingerprint<<std::dec<<"\",\n  \"step\": "<<step<<",\n  \"optimizer_step\": "<<opt<<",\n  \"vocab_size\": "<<m.vocab<<",\n  \"context_length\": "<<m.seq<<",\n  \"hidden_size\": "<<m.dim<<",\n  \"num_heads\": "<<m.heads<<",\n  \"ffn_size\": "<<m.ffn<<",\n  \"num_layers\": "<<m.nlayers<<",\n  \"micro_batch_size\": "<<mb<<",\n  \"gradient_accumulation_steps\": "<<ga<<",\n  \"checkpoint\": \""<<dst<<"\"\n}\n";std::ofstream latest(dir+"/latest_checkpoint.txt");latest<<dst<<"\n";return true;}
static bool read_exact(std::ifstream&i,void*p,size_t n){i.read((char*)p,n);return bool(i);}
static bool load_v2(model&m,tokenizer&t,jsonl_stream&r,const std::string&path,uint64_t&step,uint64_t&opt,uint64_t&micro,uint64_t&tokens,int mb,int ga){std::ifstream in(path,std::ios::binary);if(!in)return false;header_v2 h{};if(!read_exact(in,&h,sizeof(h))||std::memcmp(h.magic,"NXTRFMV2",8)||(h.version!=2&&h.version!=3)||h.header_bytes!=sizeof(h))return false;if(h.vocab!=uint32_t(m.vocab)||h.seq!=uint32_t(m.seq)||h.dim!=uint32_t(m.dim)||h.heads!=uint32_t(m.heads)||h.ffn!=uint32_t(m.ffn)||h.layers!=uint32_t(m.nlayers)||h.micro_batch!=uint32_t(mb)||h.grad_accum!=uint32_t(ga)){std::fprintf(stderr,"NXTRFMV2 configuration mismatch\n");return false;}if(h.tokenizer_kind!=(t.kind=="bpe")||(h.tokenizer_kind&&h.tokenizer_hash!=t.fingerprint)){std::fprintf(stderr,"NXTRFMV2 tokenizer mismatch\n");return false;}constexpr uint64_t max_path_bytes=1ULL<<20,max_pending_tokens=1ULL<<28;if(h.vocab_path_bytes>max_path_bytes||h.merges_path_bytes>max_path_bytes||h.pending_count>max_pending_tokens)return false;std::string saved_vocab(h.vocab_path_bytes,'\0'),saved_merges(h.merges_path_bytes,'\0');if((h.vocab_path_bytes&&!read_exact(in,saved_vocab.data(),h.vocab_path_bytes))||(h.merges_path_bytes&&!read_exact(in,saved_merges.data(),h.merges_path_bytes)))return false;r.cur.shard=h.shard;r.cur.line=h.line;r.cur.docs=h.docs;r.cur.pending.resize(h.pending_count);if(h.pending_count&&!read_exact(in,r.cur.pending.data(),h.pending_count*4))return false;auto ps=m.params();if(h.param_count!=ps.size())return false;for(param*p:ps){uint64_t n=0;if(!read_exact(in,&n,8)||n!=uint64_t(p->n)||!read_exact(in,p->v,n*4)||!read_exact(in,p->g,n*4)||!read_exact(in,p->m,n*4)||!read_exact(in,p->s,n*4))return false;}step=h.step;opt=h.optimizer_step;micro=h.micro_step;tokens=h.tokens;if(h.version==2)return in.peek()==std::ifstream::traits_type::eof();checkpoint_footer_v3 footer{};if(!read_exact(in,&footer,sizeof(footer))||std::memcmp(footer.magic,"NXHASH01",8)||in.peek()!=std::ifstream::traits_type::eof())return false;in.close();std::error_code ec;uint64_t total_bytes=std::filesystem::file_size(path,ec);uint64_t checksum=0;if(ec||footer.payload_bytes+sizeof(footer)!=total_bytes||!file_checksum(path,footer.payload_bytes,checksum)||checksum!=footer.checksum){std::fprintf(stderr,"NXTRFMV2 checkpoint checksum mismatch: %s\n",path.c_str());return false;}return true;}
static bool load_v1(model&m,tokenizer&t,const std::string&path,uint64_t&step){std::ifstream in(path,std::ios::binary);header_v1 h{};if(!in||!read_exact(in,&h,sizeof(h))||std::memcmp(h.magic,"NXTRFMR1",8))return false;if(t.kind!="byte_level"||m.vocab!=256||h.vocab!=m.vocab||h.seq!=m.seq||h.dim!=m.dim||h.heads!=m.heads||h.ffn!=m.ffn){std::fprintf(stderr,"NXTRFMR1 can only migrate with matching byte-level model dimensions\n");return false;}std::vector<param*>old{&m.emb,&m.layers[0]->nq,&m.layers[0]->nk,&m.layers[0]->wq,&m.layers[0]->wk,&m.layers[0]->wv,&m.layers[0]->wo,&m.layers[0]->nf,&m.layers[0]->wg,&m.layers[0]->wu,&m.layers[0]->wd,&m.out};for(param*p:old)if(!read_exact(in,p->v,p->n*4)||!read_exact(in,p->m,p->n*4)||!read_exact(in,p->s,p->n*4))return false;step=h.step;std::printf("[checkpoint] migrated NXTRFMR1 layer0; extra layers retain deterministic initialization\n");return true;}
}
#ifndef NEURX_TRANSFORMER_NO_MAIN
int main(){
  distributed_context dist;if(!init_distributed(dist)){std::fprintf(stderr,"distributed CUDA/NCCL initialization failed\n");return 2;}
  int device_count=0;cuda_error_t device_status=cuda_get_device_count(&device_count);if(device_status!=cuda_success||device_count<1){std::fprintf(stderr,"CUDA device unavailable: %s\n",cuda_get_error_string(device_status));return 2;}
  std::string root=env_str("NEURX_ROOT","."),base_out=env_str("NEURX_PRETRAIN_OUTPUT_DIR",root+"/checkpoint/NeurX-Transformer");
  std::string out=base_out+(dist.world>1?"/rank_"+std::to_string(dist.rank):"");
  tokenizer tok;if(!tok.load(env_str("NEURX_TOKENIZER_VOCAB",""),env_str("NEURX_TOKENIZER_MERGES","")))return 2;
  int seq=std::max(2,env_int("NEURX_PRETRAIN_SEQ_LEN",128)),dim=std::max(8,env_int("NEURX_TRANSFORMER_DIM",256)),heads=std::max(1,env_int("NEURX_TRANSFORMER_HEADS",8));
  int ffn=std::max(8,env_int("NEURX_TRANSFORMER_FFN",dim*3)),nl=std::max(1,env_int("NEURX_TRANSFORMER_NUM_LAYERS",4));int mb=std::max(1,env_int("NEURX_PRETRAIN_MICRO_BATCH",4)),ga=std::max(1,env_int("NEURX_GRADIENT_ACCUMULATION_STEPS",1));
  uint32_t seed=uint32_t(std::max(0,env_int("NEURX_SEED",1337)));
  uint64_t total=uint64_t(std::max(1,env_int("NEURX_PRETRAIN_STEPS",1000)));
  uint64_t save_every=uint64_t(std::max(1,env_int("NEURX_PRETRAIN_SAVE_INTERVAL",100)));
  uint64_t log_every=uint64_t(std::max(1,env_int("NEURX_PRETRAIN_LOG_INTERVAL",10)));
  uint64_t total_optimizer_steps=(total+uint64_t(ga)-1)/uint64_t(ga);
  float peak_lr=env_float("NEURX_PRETRAIN_LR",2e-4f);
  float min_lr=env_float("NEURX_PRETRAIN_MIN_LR",peak_lr*0.1f);
  float max_grad_norm=env_float("NEURX_MAX_GRAD_NORM",1.0f);
  float weight_decay=env_float("NEURX_PRETRAIN_WEIGHT_DECAY",0.01f);
  uint64_t warmup_steps=uint64_t(std::max(0,env_int("NEURX_PRETRAIN_WARMUP_STEPS",std::min<uint64_t>(2000,total_optimizer_steps/20))));
  if(warmup_steps>total_optimizer_steps){
    std::fprintf(stderr,"[trainer-v2] clamping warmup steps from %llu to %llu optimizer steps\n",
      (unsigned long long)warmup_steps,(unsigned long long)total_optimizer_steps);
    warmup_steps=total_optimizer_steps;
  }
  neurx_training::lr_schedule schedule;
  std::string schedule_text=env_str("NEURX_PRETRAIN_LR_SCHEDULE","cosine");
  if(!neurx_training::parse_lr_schedule(schedule_text,schedule)){
    std::fprintf(stderr,"unsupported NEURX_PRETRAIN_LR_SCHEDULE=%s (expected constant, linear, or cosine)\n",schedule_text.c_str());return 2;
  }
  if(!std::isfinite(peak_lr)||peak_lr<0.0f||!std::isfinite(min_lr)||min_lr<0.0f||min_lr>peak_lr||
     !std::isfinite(max_grad_norm)||max_grad_norm<0.0f||!std::isfinite(weight_decay)||weight_decay<0.0f){
    std::fprintf(stderr,"invalid optimizer policy: peak_lr=%g min_lr=%g max_grad_norm=%g weight_decay=%g warmup=%llu optimizer_steps=%llu\n",
      peak_lr,min_lr,max_grad_norm,weight_decay,(unsigned long long)warmup_steps,(unsigned long long)total_optimizer_steps);return 2;
  }
  neurx_training::lr_config lr_config{peak_lr,min_lr,warmup_steps,total_optimizer_steps,schedule};
  neurx_training::gradient_policy gradient_policy{max_grad_norm,1e-6};
  std::string shard_list_path=env_str("NEURX_PRETRAIN_SHARD_LIST_FILE",root+"/artifacts/build/run_large_pretrain/shard_list.txt");
  if(dim%heads){std::fprintf(stderr,"hidden size must be divisible by heads\n");return 2;}model model(tok.size(),seq,dim,heads,ffn,nl,seed);train_cache cache(model);jsonl_stream reader;reader.tok=&tok;if(!reader.load_list(shard_list_path)){std::fprintf(stderr,"empty shard list\n");return 3;}
  if(dist.world>1){std::vector<std::string>local;for(size_t i=dist.rank;i<reader.shards.size();i+=dist.world)local.push_back(reader.shards[i]);reader.shards.swap(local);if(reader.shards.empty())return 3;}
  jsonl_stream validation;validation.tok=&tok;
  std::string validation_list_path=env_str("NEURX_PRETRAIN_VALIDATION_SHARD_LIST_FILE","");
  std::string validation_file=env_str("NEURX_PRETRAIN_VALIDATION_FILE","");
  if(!validation_list_path.empty()&&!validation.load_list(validation_list_path)){
    std::fprintf(stderr,"empty validation shard list: %s\n",validation_list_path.c_str());return 3;
  }
  if(validation.shards.empty()&&!validation_file.empty())validation.shards.push_back(validation_file);
  const bool validation_enabled=!validation.shards.empty();
  const uint64_t eval_every=uint64_t(std::max(1,env_int("NEURX_PRETRAIN_EVAL_INTERVAL",100)));
  const int eval_batches=std::max(1,env_int("NEURX_PRETRAIN_EVAL_BATCHES",8));
  std::ostringstream shard_identity;
  for(const auto&path:reader.shards){
    std::error_code ec;
    const auto bytes=std::filesystem::file_size(path,ec);
    if(ec){std::fprintf(stderr,"cannot stat training shard %s: %s\n",path.c_str(),ec.message().c_str());return 3;}
    ec.clear();const auto modified=std::filesystem::last_write_time(path,ec);
    if(ec){std::fprintf(stderr,"cannot read shard timestamp %s: %s\n",path.c_str(),ec.message().c_str());return 3;}
    shard_identity<<path<<"\t"<<bytes<<"\t"<<modified.time_since_epoch().count()<<"\n";
  }
  std::ostringstream validation_identity;
  for(const auto&path:validation.shards){
    std::error_code ec;
    const auto bytes=std::filesystem::file_size(path,ec);
    if(ec){std::fprintf(stderr,"cannot stat validation shard %s: %s\n",path.c_str(),ec.message().c_str());return 3;}
    ec.clear();const auto modified=std::filesystem::last_write_time(path,ec);
    if(ec){std::fprintf(stderr,"cannot read validation shard timestamp %s: %s\n",path.c_str(),ec.message().c_str());return 3;}
    validation_identity<<path<<"\t"<<bytes<<"\t"<<modified.time_since_epoch().count()<<"\n";
  }
  run_config run_config;
  run_config.vocab=model.vocab;run_config.seq=seq;run_config.dim=dim;run_config.heads=heads;run_config.ffn=ffn;run_config.layers=nl;
  run_config.micro_batch=mb;run_config.grad_accum=ga;run_config.eval_batches=validation_enabled?eval_batches:0;
  run_config.eval_interval=validation_enabled?eval_every:0;run_config.rank=dist.rank;run_config.world_size=dist.world;run_config.seed=seed;
  run_config.total_steps=total;run_config.warmup_steps=warmup_steps;run_config.peak_lr=peak_lr;run_config.min_lr=min_lr;
  run_config.max_grad_norm=max_grad_norm;run_config.weight_decay=weight_decay;run_config.schedule=schedule_text;run_config.tokenizer_kind=tok.kind;
  run_config.tokenizer_hash=hex64(tok.fingerprint);run_config.shard_list_path=shard_list_path;
  run_config.shard_list_hash=hex64(fnv1a(shard_identity.str()));
  run_config.validation_source=validation_list_path.empty()?validation_file:validation_list_path;
  run_config.validation_hash=validation_enabled?hex64(fnv1a(validation_identity.str())):"";
  run_config.git_sha=env_str("NEURX_GIT_SHA","unknown");
  if(!write_run_manifest(out,run_config,env_int("NEURX_ALLOW_RUN_CONFIG_MISMATCH",0)!=0))return 3;
  std::printf("[trainer-v2] rank=%d world_size=%d local_rank=%d shards=%zu validation_shards=%zu checkpoint=%s seed=%u schedule=%s warmup=%llu max_grad_norm=%g\n",dist.rank,dist.world,dist.local_rank,reader.shards.size(),validation.shards.size(),out.c_str(),seed,schedule_text.c_str(),(unsigned long long)warmup_steps,max_grad_norm);
  uint64_t step=0,optstep=0,micro=0,tokens=0;std::string resume=env_str("NEURX_PRETRAIN_RESUME_FROM",out+"/transformer_v2.ckpt");if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(resume)){if(!load_v2(model,tok,reader,resume,step,optstep,micro,tokens,mb,ga))return 4;std::printf("[checkpoint] restored v2 step=%llu shard=%d line=%llu micro=%llu\n",(unsigned long long)step,reader.cur.shard,(unsigned long long)reader.cur.line,(unsigned long long)micro);}else if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(out+"/transformer.ckpt")){if(!load_v1(model,tok,out+"/transformer.ckpt",step))return 4;optstep=step;if(!save_v2(model,tok,reader,out,step,optstep,0,mb,ga,tokens))return 5;}
  if(env_int("NEURX_VALIDATE_CHECKPOINT",0)){
    std::vector<int>sample(seq+1);if(!reader.sequence(sample)){std::fprintf(stderr,"checkpoint validation could not read a token sequence\n");return 6;}
    zero_grads(model);for(int i=0;i<seq;i++){cache.ids[i]=sample[i];cache.targets[i]=sample[i+1];}if(!forward_backward(model,cache))return 7;
    int active=0;bool finite=std::isfinite(*cache.loss);for(param*p:model.params()){double l1=0;for(int64_t i=0;i<p->n;i++){finite=finite&&std::isfinite(p->v[i])&&std::isfinite(p->g[i])&&std::isfinite(p->m[i])&&std::isfinite(p->s[i]);l1+=std::abs(double(p->g[i]));}if(l1>0)active++;}
    std::printf("[checkpoint-test] step=%llu loss=%.6f finite=%s active_gradients=%d/%zu\n",(unsigned long long)step,*cache.loss,finite?"true":"false",active,model.params().size());return finite&&active==int(model.params().size())?0:9;
  }
  std::vector<int>ids(seq+1);float loss_sum=0;int accumulated=int(micro);double last_grad_norm=0.0;double current_lr=optstep?neurx_training::learning_rate(lr_config,optstep):0.0;
  double best_validation_loss=load_best_validation_loss(out);
  uint64_t finite_check_interval=uint64_t(std::max(1,env_int("NEURX_FINITE_CHECK_INTERVAL",int(log_every))));
  bool fail_on_nonfinite=env_int("NEURX_FAIL_ON_NONFINITE",1)!=0;
  if(accumulated==0)zero_grads(model);std::printf("[trainer-v2] tokenizer=%s vocab=%d layers=%d seq=%d dim=%d heads=%d ffn=%d micro_batch=%d grad_accum=%d effective_sequences=%d\n",tok.kind.c_str(),model.vocab,nl,seq,dim,heads,ffn,mb,ga,mb*ga);
  while(step<total){int this_batch=0;bool optimizer_updated=false;for(int b=0;b<mb;b++){if(!reader.sequence(ids))return 6;for(int i=0;i<seq;i++){cache.ids[i]=ids[i];cache.targets[i]=ids[i+1];}if(!forward_backward(model,cache))return 7;loss_sum+=*cache.loss;this_batch++;tokens+=seq;}micro++;accumulated++;step++;
    if(accumulated>=ga){
      if(!sync_gradients(model,dist))return 7;
      double raw_squared_norm=0.0;if(!squared_l2_norm(model.params(),&param::g,raw_squared_norm))return 7;
      double average_scale=1.0/double(accumulated*mb);
      neurx_training::gradient_decision decision=neurx_training::compute_gradient_decision(raw_squared_norm*average_scale*average_scale,gradient_policy);
      last_grad_norm=decision.norm;
      if(!decision.finite){
        std::fprintf(stderr,"[trainer-v2] non-finite gradient at step=%llu optimizer_step=%llu\n",(unsigned long long)step,(unsigned long long)optstep);
        zero_grads(model);accumulated=0;micro=0;
        if(fail_on_nonfinite)return 10;
      }else{
        uint64_t next_optstep=optstep+1;current_lr=neurx_training::learning_rate(lr_config,next_optstep);
        if(!optimizer_step(model,int(next_optstep),float(current_lr),float(average_scale*decision.scale),weight_decay))return 7;
        optstep=next_optstep;zero_grads(model);accumulated=0;micro=0;optimizer_updated=true;
        if(optstep%finite_check_interval==0&&!optimizer_state_is_finite(model)){
          std::fprintf(stderr,"[trainer-v2] non-finite parameter or Adam state at optimizer_step=%llu\n",(unsigned long long)optstep);return 10;
        }
      }
    }
    if(validation_enabled&&optimizer_updated&&optstep%eval_every==0){
      double val_loss=0.0;
      if(!validation_loss(model,cache,validation,dist,eval_batches,val_loss))return 11;
      double perplexity=std::exp(std::min(80.0,val_loss));
      bool is_best=val_loss<best_validation_loss;
      std::printf("[validation] optimizer_step=%llu loss=%.9f perplexity=%.9f best=%s batches_per_rank=%d\n",
        (unsigned long long)optstep,val_loss,perplexity,is_best?"true":"false",eval_batches);
      if(is_best){
        if(!save_v2(model,tok,reader,out+"/best",step,optstep,accumulated,mb,ga,tokens)||
           !save_best_validation_loss(out,val_loss))return 8;
        best_validation_loss=val_loss;
      }
    }
    if(step==1||step%log_every==0)std::printf("[trainer-v2] step=%llu/%llu optimizer_step=%llu loss=%.6f lr=%.9g grad_norm=%.6f tokens=%llu shard=%d line=%llu accum=%d/%d\n",(unsigned long long)step,(unsigned long long)total,(unsigned long long)optstep,loss_sum/std::max(1,this_batch),current_lr,last_grad_norm,(unsigned long long)tokens,reader.cur.shard,(unsigned long long)reader.cur.line,accumulated,ga);loss_sum=0;
    if(step%save_every==0&&!save_v2(model,tok,reader,out,step,optstep,accumulated,mb,ga,tokens))return 8;
  }
  if(!save_v2(model,tok,reader,out,step,optstep,accumulated,mb,ga,tokens))return 8;std::printf("[trainer-v2] complete checkpoint=%s/transformer_v2.ckpt\n",out.c_str());return 0;
}
#endif
