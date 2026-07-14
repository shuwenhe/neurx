#include "transformer_kernels.cuh"
#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <nccl.h>
#include <algorithm>
#include <cctype>
#include <cmath>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <map>
#include <memory>
#include <random>
#include <sstream>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

using namespace neurx_cuda_transformer;

namespace {

#define CUDA_CHECK(x) do { cudaError_t e=(x); if(e!=cudaSuccess){ \
  std::fprintf(stderr,"CUDA error %s:%d: %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); return false; } } while(0)
#define CUBLAS_CHECK(x) do { cublasStatus_t e=(x); if(e!=CUBLAS_STATUS_SUCCESS){ \
  std::fprintf(stderr,"cuBLAS error %s:%d: %d\n",__FILE__,__LINE__,int(e)); return false; } } while(0)

static int env_int(const char *n,int d){const char*s=std::getenv(n);return s&&*s?std::atoi(s):d;}
static float env_float(const char*n,float d){const char*s=std::getenv(n);return s&&*s?std::strtof(s,nullptr):d;}
static std::string env_str(const char*n,const std::string&d){const char*s=std::getenv(n);return s&&*s?s:d;}
static uint64_t fnv1a(const std::string&s){uint64_t h=1469598103934665603ULL;for(unsigned char c:s){h^=c;h*=1099511628211ULL;}return h;}
static bool exists(const std::string&p){return std::filesystem::exists(p);}

static bool nccl_ok(ncclResult_t e,const char*expr){if(e==ncclSuccess)return true;std::fprintf(stderr,"NCCL error %s: %s\n",expr,ncclGetErrorString(e));return false;}
#define NCCL_CHECK(x) do{if(!nccl_ok((x),#x))return false;}while(0)

struct DistributedContext {int rank=0,world=1,local_rank=0;ncclComm_t comm=nullptr;cudaStream_t stream=nullptr;};
static bool read_nccl_id(const std::string&path,ncclUniqueId&id){std::ifstream f(path,std::ios::binary);if(!f)return false;f.read(reinterpret_cast<char*>(&id),sizeof(id));return bool(f);}
static bool write_nccl_id(const std::string&path,const ncclUniqueId&id){std::string tmp=path+".tmp";std::ofstream f(tmp,std::ios::binary|std::ios::trunc);f.write(reinterpret_cast<const char*>(&id),sizeof(id));f.close();if(!f)return false;std::error_code ec;std::filesystem::rename(tmp,path,ec);return!ec;}
static bool init_distributed(DistributedContext&d){
  d.rank=std::max(0,env_int("RANK",0));d.world=std::max(1,env_int("WORLD_SIZE",1));d.local_rank=std::max(0,env_int("LOCAL_RANK",d.rank));
  if(d.rank>=d.world)return false;CUDA_CHECK(cudaSetDevice(d.local_rank));CUDA_CHECK(cudaStreamCreate(&d.stream));
  if(d.world==1)return true;std::string id_path=env_str("NEURX_NCCL_ID_FILE","/tmp/neurx_nccl_id");ncclUniqueId id{};
  if(d.rank==0){NCCL_CHECK(ncclGetUniqueId(&id));if(!write_nccl_id(id_path,id)){std::fprintf(stderr,"cannot write NCCL id: %s\n",id_path.c_str());return false;}}
  else {for(int i=0;i<600&&!read_nccl_id(id_path,id);i++)std::this_thread::sleep_for(std::chrono::milliseconds(100));if(!read_nccl_id(id_path,id))return false;}
  NCCL_CHECK(ncclCommInitRank(&d.comm,d.world,id,d.rank));return true;
}
static bool sync_gradients(Model&m,DistributedContext&d){if(d.world==1)return true;for(Param*p:m.params())NCCL_CHECK(ncclAllReduce(p->g,p->g,p->n,ncclFloat,ncclSum,d.comm,d.stream));CUDA_CHECK(cudaStreamSynchronize(d.stream));for(Param*p:m.params())scale_values<<<blocks(p->n),256,0,d.stream>>>(p->g,p->n,1.0f/float(d.world));CUDA_CHECK(cudaStreamSynchronize(d.stream));return true;}

struct Param {
  float *v=nullptr,*g=nullptr,*m=nullptr,*s=nullptr; int64_t n=0;
  explicit Param(int64_t count=0):n(count){
    if(!n)return; cudaMallocManaged(&v,n*4);
#ifndef NEURX_INFERENCE_ONLY
    cudaMallocManaged(&g,n*4);
    cudaMallocManaged(&m,n*4);cudaMallocManaged(&s,n*4);
    cudaMemset(g,0,n*4);cudaMemset(m,0,n*4);cudaMemset(s,0,n*4);
#endif
  }
  Param(const Param&)=delete; Param&operator=(const Param&)=delete;
  ~Param(){if(v)cudaFree(v);if(g)cudaFree(g);if(m)cudaFree(m);if(s)cudaFree(s);}
};

struct Layer {
  int d,f; Param nq,nk,wq,wk,wv,wo,nf,wg,wu,wd;
  Layer(int dim,int ffn):d(dim),f(ffn),nq(d),nk(d),wq(d*d),wk(d*d),wv(d*d),wo(d*d),nf(d),wg(d*f),wu(d*f),wd(f*d){}
  // nk is retained only as a sink for the unused legacy NXTRFMR1 norm slot.
  std::vector<Param*> params(){return{&nq,&wq,&wk,&wv,&wo,&nf,&wg,&wu,&wd};}
};

struct Model {
  int vocab,seq,dim,heads,ffn,nlayers; Param emb,out; std::vector<std::unique_ptr<Layer>> layers;
  Model(int v,int t,int d,int h,int f,int n):vocab(v),seq(t),dim(d),heads(h),ffn(f),nlayers(n),emb(int64_t(v)*d),out(int64_t(d)*v){
    for(int i=0;i<n;i++)layers.emplace_back(std::make_unique<Layer>(d,f));
#ifndef NEURX_INFERENCE_ONLY
    init();
#endif
  }
  std::vector<Param*> params(){std::vector<Param*>p{&emb};for(auto&l:layers){auto q=l->params();p.insert(p.end(),q.begin(),q.end());}p.push_back(&out);return p;}
  void init(){std::mt19937 rng(1337);std::normal_distribution<float>nd(0,.02f);for(Param*p:params())for(int64_t i=0;i<p->n;i++)p->v[i]=nd(rng);for(auto&l:layers)for(int i=0;i<dim;i++){l->nq.v[i]=1;l->nk.v[i]=1;l->nf.v[i]=1;}}
};

struct LayerCache {
  float *x,*n1,*iq,*ik,*q,*k,*v,*att,*ctx,*proj,*res,*n2,*iff,*gate,*up,*sw,*down,*h;
  float *dout,*dres,*dsw,*dg,*du,*dn2,*tmp,*dctx,*dq,*dk,*dv,*dn1,*dx;
};
static float* managed_f(int64_t n){float*p=nullptr;cudaMallocManaged(&p,n*4);return p;}
static int* managed_i(int64_t n){int*p=nullptr;cudaMallocManaged(&p,n*4);return p;}
static LayerCache make_layer_cache(int t,int d,int f,int heads){LayerCache a{};int64_t td=int64_t(t)*d,tf=int64_t(t)*f;
  a.x=managed_f(td);a.n1=managed_f(td);a.iq=managed_f(t);a.ik=managed_f(t);a.q=managed_f(td);a.k=managed_f(td);a.v=managed_f(td);
  a.att=managed_f(int64_t(heads)*t*t);a.ctx=managed_f(td);a.proj=managed_f(td);a.res=managed_f(td);a.n2=managed_f(td);a.iff=managed_f(t);
  a.gate=managed_f(tf);a.up=managed_f(tf);a.sw=managed_f(tf);a.down=managed_f(td);a.h=managed_f(td);a.dout=managed_f(td);a.dres=managed_f(td);
  a.dsw=managed_f(tf);a.dg=managed_f(tf);a.du=managed_f(tf);a.dn2=managed_f(td);a.tmp=managed_f(std::max(td,tf));a.dctx=managed_f(td);
  a.dq=managed_f(td);a.dk=managed_f(td);a.dv=managed_f(td);a.dn1=managed_f(td);a.dx=managed_f(td);return a;}
struct TrainCache {int*ids,*targets;float*embedding,*logits,*loss,*dl,*dh;std::vector<LayerCache>lc;
  TrainCache(Model&m){int64_t td=int64_t(m.seq)*m.dim,tv=int64_t(m.seq)*m.vocab;ids=managed_i(m.seq);targets=managed_i(m.seq);embedding=managed_f(td);logits=managed_f(tv);loss=managed_f(1);dl=managed_f(tv);dh=managed_f(td);for(int i=0;i<m.nlayers;i++)lc.push_back(make_layer_cache(m.seq,m.dim,m.ffn,m.heads));}
};

static cublasHandle_t blas=nullptr;
static bool gemm(float*a,float*b,float*c,int m,int k,int n){if(!blas)CUBLAS_CHECK(cublasCreate(&blas));const float one=1,zero=0;CUBLAS_CHECK(cublasSgemm(blas,CUBLAS_OP_N,CUBLAS_OP_N,n,m,k,&one,b,n,a,k,&zero,c,n));return true;}
static bool backward_linear(float*x,Param&w,float*dy,float*dx,int m,int k,int n){if(!blas)CUBLAS_CHECK(cublasCreate(&blas));const float one=1,zero=0;
  CUBLAS_CHECK(cublasSgemm(blas,CUBLAS_OP_T,CUBLAS_OP_N,k,m,n,&one,w.v,n,dy,n,&zero,dx,k));
  CUBLAS_CHECK(cublasSgemm(blas,CUBLAS_OP_N,CUBLAS_OP_T,n,k,m,&one,dy,n,x,k,&one,w.g,n));return true;}
static void zero_grads(Model&m){for(Param*p:m.params())cudaMemset(p->g,0,p->n*4);}
__global__ void scale_values(float*x,int64_t n,float scale){int64_t i=int64_t(blockIdx.x)*blockDim.x+threadIdx.x;if(i<n)x[i]*=scale;}
__global__ void rms_dg_accum(const float*x,const float*inv,const float*dy,float*dg,int rows,int d){int j=blockIdx.x*blockDim.x+threadIdx.x;if(j>=d)return;float s=0;for(int r=0;r<rows;r++)s+=dy[r*d+j]*x[r*d+j]*inv[r];dg[j]+=s;}

static bool forward_backward(Model&m,TrainCache&a){int t=m.seq,d=m.dim,f=m.ffn,v=m.vocab,td=t*d,tf=t*f;
  embedding_fwd<<<blocks(td),256>>>(a.ids,m.emb.v,a.embedding,t,d);float*input=a.embedding;
  for(int li=0;li<m.nlayers;li++){Layer&l=*m.layers[li];LayerCache&c=a.lc[li];CUDA_CHECK(cudaMemcpy(c.x,input,td*4,cudaMemcpyDeviceToDevice));
    rms_fwd<<<blocks(t),256>>>(c.x,l.nq.v,c.n1,c.iq,t,d);if(!gemm(c.n1,l.wq.v,c.q,t,d,d)||!gemm(c.n1,l.wk.v,c.k,t,d,d)||!gemm(c.n1,l.wv.v,c.v,t,d,d))return false;
    int rope_items=t*m.heads*(d/m.heads/2);rope<<<blocks(rope_items),256>>>(c.q,t,d,m.heads,false);rope<<<blocks(rope_items),256>>>(c.k,t,d,m.heads,false);attention_fwd<<<m.heads*t,1>>>(c.q,c.k,c.v,c.att,c.ctx,t,d,m.heads);
    if(!gemm(c.ctx,l.wo.v,c.proj,t,d,d))return false;add<<<blocks(td),256>>>(c.x,c.proj,c.res,td);rms_fwd<<<blocks(t),256>>>(c.res,l.nf.v,c.n2,c.iff,t,d);
    if(!gemm(c.n2,l.wg.v,c.gate,t,d,f)||!gemm(c.n2,l.wu.v,c.up,t,d,f))return false;swiglu_fwd<<<blocks(tf),256>>>(c.gate,c.up,c.sw,tf);
    if(!gemm(c.sw,l.wd.v,c.down,t,f,d))return false;add<<<blocks(td),256>>>(c.res,c.down,c.h,td);input=c.h;
  }
  if(!gemm(input,m.out.v,a.logits,t,d,v))return false;cudaMemset(a.loss,0,4);cross_entropy_fwd_bwd<<<blocks(t),256>>>(a.logits,a.targets,a.loss,a.dl,t,v);
  if(!backward_linear(input,m.out,a.dl,a.dh,t,d,v))return false;float*upstream=a.dh;
  for(int li=m.nlayers-1;li>=0;li--){Layer&l=*m.layers[li];LayerCache&c=a.lc[li];CUDA_CHECK(cudaMemcpy(c.dout,upstream,td*4,cudaMemcpyDeviceToDevice));CUDA_CHECK(cudaMemcpy(c.dres,c.dout,td*4,cudaMemcpyDeviceToDevice));
    if(!backward_linear(c.sw,l.wd,c.dout,c.dsw,t,f,d))return false;swiglu_bwd<<<blocks(tf),256>>>(c.gate,c.up,c.dsw,c.dg,c.du,tf);
    if(!backward_linear(c.n2,l.wg,c.dg,c.dn2,t,d,f)||!backward_linear(c.n2,l.wu,c.du,c.tmp,t,d,f))return false;add_inplace<<<blocks(td),256>>>(c.dn2,c.tmp,td);
    rms_dx<<<blocks(t),256>>>(c.res,l.nf.v,c.iff,c.dn2,c.tmp,t,d);rms_dg_accum<<<blocks(d),256>>>(c.res,c.iff,c.dn2,l.nf.g,t,d);add_inplace<<<blocks(td),256>>>(c.dres,c.tmp,td);
    if(!backward_linear(c.ctx,l.wo,c.dres,c.dctx,t,d,d))return false;cudaMemset(c.dq,0,td*4);cudaMemset(c.dk,0,td*4);cudaMemset(c.dv,0,td*4);
    attention_bwd<<<m.heads*t,1,2*t*sizeof(float)>>>(c.q,c.k,c.v,c.att,c.dctx,c.dq,c.dk,c.dv,t,d,m.heads);int rope_items=t*m.heads*(d/m.heads/2);rope<<<blocks(rope_items),256>>>(c.dq,t,d,m.heads,true);rope<<<blocks(rope_items),256>>>(c.dk,t,d,m.heads,true);
    if(!backward_linear(c.n1,l.wq,c.dq,c.dn1,t,d,d)||!backward_linear(c.n1,l.wk,c.dk,c.tmp,t,d,d))return false;add_inplace<<<blocks(td),256>>>(c.dn1,c.tmp,td);
    if(!backward_linear(c.n1,l.wv,c.dv,c.tmp,t,d,d))return false;add_inplace<<<blocks(td),256>>>(c.dn1,c.tmp,td);rms_dx<<<blocks(t),256>>>(c.x,l.nq.v,c.iq,c.dn1,c.dx,t,d);rms_dg_accum<<<blocks(d),256>>>(c.x,c.iq,c.dn1,l.nq.g,t,d);add_inplace<<<blocks(td),256>>>(c.dx,c.dres,td);upstream=c.dx;
  }
  embedding_bwd<<<blocks(td),256>>>(a.ids,upstream,m.emb.g,t,d);CUDA_CHECK(cudaDeviceSynchronize());return true;
}

static void optimizer_step(Model&m,int step,float lr,float grad_scale){for(Param*p:m.params()){scale_values<<<blocks(p->n),256>>>(p->g,p->n,grad_scale);adamw<<<blocks(p->n),256>>>(p->v,p->g,p->m,p->s,p->n,step,lr,.01f);}cudaDeviceSynchronize();}

static std::string json_unescape(const std::string&s){std::string o;for(size_t i=0;i<s.size();i++){char c=s[i];if(c!='\\'||i+1>=s.size()){o+=c;continue;}char e=s[++i];if(e=='n')o+='\n';else if(e=='r')o+='\r';else if(e=='t')o+='\t';else if(e=='b')o+='\b';else if(e=='f')o+='\f';else if(e=='"'||e=='\\'||e=='/')o+=e;else if(e=='u'&&i+4<s.size()){unsigned cp=0;for(int j=0;j<4;j++){char h=s[++i];cp=cp*16+(h>='0'&&h<='9'?h-'0':std::tolower(h)-'a'+10);}if(cp<128)o+=char(cp);else if(cp<2048){o+=char(0xc0|(cp>>6));o+=char(0x80|(cp&63));}else{o+=char(0xe0|(cp>>12));o+=char(0x80|((cp>>6)&63));o+=char(0x80|(cp&63));}}}return o;}
static bool parse_json_string(const std::string&s,size_t&p,std::string&out){while(p<s.size()&&std::isspace((unsigned char)s[p]))p++;if(p>=s.size()||s[p]!='"')return false;p++;std::string raw;bool esc=false;for(;p<s.size();p++){char c=s[p];if(!esc&&c=='"'){p++;out=json_unescape(raw);return true;}raw+=c;if(!esc&&c=='\\')esc=true;else esc=false;}return false;}
static std::string extract_json_string_field(const std::string&line,const std::string&field){size_t p=0;while(p<line.size()){std::string key;if(!parse_json_string(line,p,key)){p++;continue;}while(p<line.size()&&std::isspace((unsigned char)line[p]))p++;if(p>=line.size()||line[p++]!=':')continue;if(key==field){std::string value;if(parse_json_string(line,p,value))return value;return{};}std::string ignored;if(!parse_json_string(line,p,ignored)){while(p<line.size()&&line[p]!=',')p++;}}return{};}
static std::string extract_text(const std::string&line){std::string value=extract_json_string_field(line,"text");if(value.empty())value=extract_json_string_field(line,"content");if(value.empty())value=extract_json_string_field(line,"xml");return value;}

struct Tokenizer {
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

struct Cursor {int shard=0;uint64_t line=0,docs=0;std::vector<int>pending;};
struct JsonlStream {std::vector<std::string>shards;Tokenizer*tok;Cursor cur;std::ifstream in;
  bool load_list(const std::string&p){std::ifstream f(p);std::string s;while(std::getline(f,s))if(!s.empty())shards.push_back(s);return!shards.empty();}
  bool open_cursor(){in.close();if(cur.shard>=int(shards.size()))cur.shard=0;in.open(shards[cur.shard]);if(!in)return false;std::string skip;for(uint64_t i=0;i<cur.line&&std::getline(in,skip);i++);return true;}
  bool next_doc(){int exhausted=0;for(;;){if(!in.is_open()&&!open_cursor())return false;std::string line;if(std::getline(in,line)){cur.line++;std::string text=extract_text(line);if(text.empty())continue;cur.pending=tok->encode(text);cur.docs++;if(!cur.pending.empty())return true;}else{in.close();cur.shard++;cur.line=0;exhausted++;if(exhausted>=int(shards.size())){std::fprintf(stderr,"no non-empty JSONL text fields found in one complete shard pass\n");return false;}if(cur.shard>=int(shards.size()))cur.shard=0;}}}
  bool sequence(std::vector<int>&ids){while(cur.pending.size()<ids.size()+1)if(!next_doc())return false;std::copy(cur.pending.begin(),cur.pending.begin()+ids.size()+1,ids.begin());cur.pending.erase(cur.pending.begin(),cur.pending.begin()+ids.size());return true;}
};

#pragma pack(push,1)
struct HeaderV1{char magic[8];int32_t version,step,cursor,vocab,seq,dim,heads,ffn;};
struct HeaderV2{char magic[8];uint32_t version,header_bytes;uint64_t step,optimizer_step,micro_step,shard,line,docs,tokens;uint32_t vocab,seq,dim,heads,ffn,layers,micro_batch,grad_accum,tokenizer_kind,vocab_path_bytes,merges_path_bytes;uint64_t tokenizer_hash,pending_count,param_count;};
#pragma pack(pop)
static bool write_blob(std::ofstream&o,const void*p,size_t n){o.write((const char*)p,n);return bool(o);}
static bool save_v2(Model&m,Tokenizer&t,JsonlStream&r,const std::string&dir,uint64_t step,uint64_t opt,uint64_t micro,int mb,int ga,uint64_t tokens){cudaDeviceSynchronize();std::filesystem::create_directories(dir);std::string tmp=dir+"/transformer_v2.ckpt.tmp",dst=dir+"/transformer_v2.ckpt";std::ofstream o(tmp,std::ios::binary|std::ios::trunc);auto ps=m.params();HeaderV2 h{};std::memcpy(h.magic,"NXTRFMV2",8);h.version=2;h.header_bytes=sizeof(h);h.step=step;h.optimizer_step=opt;h.micro_step=micro;h.shard=r.cur.shard;h.line=r.cur.line;h.docs=r.cur.docs;h.tokens=tokens;h.vocab=m.vocab;h.seq=m.seq;h.dim=m.dim;h.heads=m.heads;h.ffn=m.ffn;h.layers=m.nlayers;h.micro_batch=mb;h.grad_accum=ga;h.tokenizer_kind=t.kind=="bpe"?1:0;h.vocab_path_bytes=t.vocab_path.size();h.merges_path_bytes=t.merges_path.size();h.tokenizer_hash=t.fingerprint;h.pending_count=r.cur.pending.size();h.param_count=ps.size();write_blob(o,&h,sizeof(h));write_blob(o,t.vocab_path.data(),h.vocab_path_bytes);write_blob(o,t.merges_path.data(),h.merges_path_bytes);if(h.pending_count)write_blob(o,r.cur.pending.data(),h.pending_count*4);for(Param*p:ps){uint64_t n=p->n;write_blob(o,&n,8);write_blob(o,p->v,n*4);write_blob(o,p->g,n*4);write_blob(o,p->m,n*4);write_blob(o,p->s,n*4);}o.close();if(!o)return false;std::filesystem::rename(tmp,dst);
  std::string model_name=env_str("NEURX_PRETRAIN_MODEL_NAME","NeurX-1.3");std::string model_path=dir+"/"+model_name+".neurx";std::ofstream meta(model_path);meta<<"{\n  \"model_name\": \""<<model_name<<"\",\n  \"format\": \"NXTRFMV2\",\n  \"architecture\": \"decoder_only_transformer\",\n  \"tokenizer\": \""<<t.kind<<"\",\n  \"tokenizer_hash\": \""<<std::hex<<t.fingerprint<<std::dec<<"\",\n  \"step\": "<<step<<",\n  \"optimizer_step\": "<<opt<<",\n  \"vocab_size\": "<<m.vocab<<",\n  \"context_length\": "<<m.seq<<",\n  \"hidden_size\": "<<m.dim<<",\n  \"num_heads\": "<<m.heads<<",\n  \"ffn_size\": "<<m.ffn<<",\n  \"num_layers\": "<<m.nlayers<<",\n  \"micro_batch_size\": "<<mb<<",\n  \"gradient_accumulation_steps\": "<<ga<<",\n  \"checkpoint\": \""<<dst<<"\"\n}\n";std::ofstream latest(dir+"/latest_checkpoint.txt");latest<<dst<<"\n";return true;}

static bool read_exact(std::ifstream&i,void*p,size_t n){i.read((char*)p,n);return bool(i);}
static bool load_v2(Model&m,Tokenizer&t,JsonlStream&r,const std::string&path,uint64_t&step,uint64_t&opt,uint64_t&micro,uint64_t&tokens,int mb,int ga){std::ifstream in(path,std::ios::binary);if(!in)return false;HeaderV2 h{};if(!read_exact(in,&h,sizeof(h))||std::memcmp(h.magic,"NXTRFMV2",8)||h.version!=2||h.header_bytes!=sizeof(h))return false;if(h.vocab!=uint32_t(m.vocab)||h.seq!=uint32_t(m.seq)||h.dim!=uint32_t(m.dim)||h.heads!=uint32_t(m.heads)||h.ffn!=uint32_t(m.ffn)||h.layers!=uint32_t(m.nlayers)||h.micro_batch!=uint32_t(mb)||h.grad_accum!=uint32_t(ga)){std::fprintf(stderr,"NXTRFMV2 configuration mismatch\n");return false;}if(h.tokenizer_kind!=(t.kind=="bpe")||(h.tokenizer_kind&&h.tokenizer_hash!=t.fingerprint)){std::fprintf(stderr,"NXTRFMV2 tokenizer mismatch\n");return false;}std::string saved_vocab(h.vocab_path_bytes,'\0'),saved_merges(h.merges_path_bytes,'\0');if((h.vocab_path_bytes&&!read_exact(in,saved_vocab.data(),h.vocab_path_bytes))||(h.merges_path_bytes&&!read_exact(in,saved_merges.data(),h.merges_path_bytes)))return false;r.cur.shard=h.shard;r.cur.line=h.line;r.cur.docs=h.docs;r.cur.pending.resize(h.pending_count);if(h.pending_count&&!read_exact(in,r.cur.pending.data(),h.pending_count*4))return false;auto ps=m.params();if(h.param_count!=ps.size())return false;for(Param*p:ps){uint64_t n=0;if(!read_exact(in,&n,8)||n!=uint64_t(p->n)||!read_exact(in,p->v,n*4)||!read_exact(in,p->g,n*4)||!read_exact(in,p->m,n*4)||!read_exact(in,p->s,n*4))return false;}step=h.step;opt=h.optimizer_step;micro=h.micro_step;tokens=h.tokens;return true;}

static bool load_v1(Model&m,Tokenizer&t,const std::string&path,uint64_t&step){std::ifstream in(path,std::ios::binary);HeaderV1 h{};if(!in||!read_exact(in,&h,sizeof(h))||std::memcmp(h.magic,"NXTRFMR1",8))return false;if(t.kind!="byte_level"||m.vocab!=256||h.vocab!=m.vocab||h.seq!=m.seq||h.dim!=m.dim||h.heads!=m.heads||h.ffn!=m.ffn){std::fprintf(stderr,"NXTRFMR1 can only migrate with matching byte-level model dimensions\n");return false;}std::vector<Param*>old{&m.emb,&m.layers[0]->nq,&m.layers[0]->nk,&m.layers[0]->wq,&m.layers[0]->wk,&m.layers[0]->wv,&m.layers[0]->wo,&m.layers[0]->nf,&m.layers[0]->wg,&m.layers[0]->wu,&m.layers[0]->wd,&m.out};for(Param*p:old)if(!read_exact(in,p->v,p->n*4)||!read_exact(in,p->m,p->n*4)||!read_exact(in,p->s,p->n*4))return false;step=h.step;std::printf("[checkpoint] migrated NXTRFMR1 layer0; extra layers retain deterministic initialization\n");return true;}

} // namespace

#ifndef NEURX_TRANSFORMER_NO_MAIN
int main(){
  int device_count=0;cudaError_t device_status=cudaGetDeviceCount(&device_count);if(device_status!=cudaSuccess||device_count<1){std::fprintf(stderr,"CUDA device unavailable: %s\n",cudaGetErrorString(device_status));return 2;}
  std::string root=env_str("NEURX_ROOT","."),out=env_str("NEURX_PRETRAIN_OUTPUT_DIR",root+"/checkpoint/NeurX-Transformer");
  Tokenizer tok;if(!tok.load(env_str("NEURX_TOKENIZER_VOCAB",""),env_str("NEURX_TOKENIZER_MERGES","")))return 2;
  int seq=std::max(2,env_int("NEURX_PRETRAIN_SEQ_LEN",128)),dim=std::max(8,env_int("NEURX_TRANSFORMER_DIM",256)),heads=std::max(1,env_int("NEURX_TRANSFORMER_HEADS",8));
  int ffn=std::max(8,env_int("NEURX_TRANSFORMER_FFN",dim*3)),nl=std::max(1,env_int("NEURX_TRANSFORMER_NUM_LAYERS",4));int mb=std::max(1,env_int("NEURX_PRETRAIN_MICRO_BATCH",4)),ga=std::max(1,env_int("NEURX_GRADIENT_ACCUMULATION_STEPS",1));
  if(dim%heads){std::fprintf(stderr,"hidden size must be divisible by heads\n");return 2;}Model model(tok.size(),seq,dim,heads,ffn,nl);TrainCache cache(model);JsonlStream reader;reader.tok=&tok;if(!reader.load_list(env_str("NEURX_PRETRAIN_SHARD_LIST_FILE",root+"/artifacts/build/run_large_pretrain/shard_list.txt"))){std::fprintf(stderr,"empty shard list\n");return 3;}
  uint64_t step=0,optstep=0,micro=0,tokens=0;std::string resume=env_str("NEURX_PRETRAIN_RESUME_FROM",out+"/transformer_v2.ckpt");if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(resume)){if(!load_v2(model,tok,reader,resume,step,optstep,micro,tokens,mb,ga))return 4;std::printf("[checkpoint] restored v2 step=%llu shard=%d line=%llu micro=%llu\n",(unsigned long long)step,reader.cur.shard,(unsigned long long)reader.cur.line,(unsigned long long)micro);}else if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(out+"/transformer.ckpt")){if(!load_v1(model,tok,out+"/transformer.ckpt",step))return 4;optstep=step;if(!save_v2(model,tok,reader,out,step,optstep,0,mb,ga,tokens))return 5;}
  if(env_int("NEURX_VALIDATE_CHECKPOINT",0)){
    std::vector<int>sample(seq+1);if(!reader.sequence(sample)){std::fprintf(stderr,"checkpoint validation could not read a token sequence\n");return 6;}
    zero_grads(model);for(int i=0;i<seq;i++){cache.ids[i]=sample[i];cache.targets[i]=sample[i+1];}if(!forward_backward(model,cache))return 7;
    int active=0;bool finite=std::isfinite(*cache.loss);for(Param*p:model.params()){double l1=0;for(int64_t i=0;i<p->n;i++){finite=finite&&std::isfinite(p->v[i])&&std::isfinite(p->g[i])&&std::isfinite(p->m[i])&&std::isfinite(p->s[i]);l1+=std::abs(double(p->g[i]));}if(l1>0)active++;}
    std::printf("[checkpoint-test] step=%llu loss=%.6f finite=%s active_gradients=%d/%zu\n",(unsigned long long)step,*cache.loss,finite?"true":"false",active,model.params().size());return finite&&active==int(model.params().size())?0:9;
  }
  uint64_t total=std::max(1,env_int("NEURX_PRETRAIN_STEPS",1000)),save_every=std::max(1,env_int("NEURX_PRETRAIN_SAVE_INTERVAL",100)),log_every=std::max(1,env_int("NEURX_PRETRAIN_LOG_INTERVAL",10));float lr=env_float("NEURX_PRETRAIN_LR",2e-4f);std::vector<int>ids(seq+1);float loss_sum=0;int accumulated=int(micro);
  if(accumulated==0)zero_grads(model);std::printf("[trainer-v2] tokenizer=%s vocab=%d layers=%d seq=%d dim=%d heads=%d ffn=%d micro_batch=%d grad_accum=%d effective_sequences=%d\n",tok.kind.c_str(),model.vocab,nl,seq,dim,heads,ffn,mb,ga,mb*ga);
  while(step<total){int this_batch=0;for(int b=0;b<mb;b++){if(!reader.sequence(ids))return 6;for(int i=0;i<seq;i++){cache.ids[i]=ids[i];cache.targets[i]=ids[i+1];}if(!forward_backward(model,cache))return 7;loss_sum+=*cache.loss;this_batch++;tokens+=seq;}micro++;accumulated++;step++;
    if(accumulated>=ga){optstep++;optimizer_step(model,optstep,lr,1.0f/float(accumulated*mb));zero_grads(model);accumulated=0;micro=0;}
    if(step==1||step%log_every==0)std::printf("[trainer-v2] step=%llu/%llu optimizer_step=%llu loss=%.6f tokens=%llu shard=%d line=%llu accum=%d/%d\n",(unsigned long long)step,(unsigned long long)total,(unsigned long long)optstep,loss_sum/std::max(1,this_batch),(unsigned long long)tokens,reader.cur.shard,(unsigned long long)reader.cur.line,accumulated,ga);loss_sum=0;
    if(step%save_every==0&&!save_v2(model,tok,reader,out,step,optstep,accumulated,mb,ga,tokens))return 8;
  }
  if(!save_v2(model,tok,reader,out,step,optstep,accumulated,mb,ga,tokens))return 8;std::printf("[trainer-v2] complete checkpoint=%s/transformer_v2.ckpt\n",out.c_str());return 0;
}
#endif
