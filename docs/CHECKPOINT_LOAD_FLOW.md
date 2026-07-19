# Checkpoint loadcompletepipelineEnglish text

## initializephase

### 1️⃣ English textinitialize (`init_distributed`)
**file**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L104-L113)

```cpp
static bool init_distributed(DistributedContext&d){
  // English text
  d.rank=std::max(0,env_int("RANK",0));
  d.world=std::max(1,env_int("WORLD_SIZE",1));
  d.local_rank=std::max(0,env_int("LOCAL_RANK",d.rank));

  // 1.1 English textCUDAEnglish text
  if(d.rank>=d.world)return false;
  CUDA_CHECK(cudaSetDevice(d.local_rank));  // English textGPUEnglish text
  CUDA_CHECK(cudaStreamCreate(&d.stream));   // English textCUDAEnglish text

  // 1.2 English texttrainingEnglish text
  if(d.world==1)return true;

  // 1.3 English textNCCLinitialize
  std::string id_path=env_str("NEURX_NCCL_ID_FILE","/tmp/neurx_nccl_id");
  ncclUniqueId id{};

  // Rank 0 generateEnglish textID
  if(d.rank==0){
    NCCL_CHECK(ncclGetUniqueId(&id));
    if(!write_nccl_id(id_path,id)){
      std::fprintf(stderr,"cannot write NCCL id: %s\n",id_path.c_str());
      return false;
    }
  }
  // English textRankEnglish textID (English text600×100ms = 60English text)
  else {
    for(int i=0;i<600&&!read_nccl_id(id_path,id);i++)
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    if(!read_nccl_id(id_path,id))return false;
  }

  // 1.4 initializeNCCLEnglish text
  NCCL_CHECK(ncclCommInitRank(&d.comm,d.world,id,d.rank));
  return true;
}
```

**📤 English textoutput**:
- English textoutput (failureEnglish textstderr: "cannot write NCCL id: ..." English textNCCLerror)

---

### 2️⃣ mainfunctioninitialize (`main`)
**file**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L192-L203)

```cpp
int main(){
  // stepEnglish text 1: English textCUDA/NCCLinitialize
  DistributedContext dist;
  if(!init_distributed(dist)){
    std::fprintf(stderr,"distributed CUDA/NCCL initialization failed\n");
    return 2;
  }

  // stepEnglish text 2: English textCUDAEnglish text
  int device_count=0;
  cudaError_t device_status=cudaGetDeviceCount(&device_count);
  if(device_status!=cudaSuccess||device_count<1){
    std::fprintf(stderr,"CUDA device unavailable: %s\n",cudaGetErrorString(device_status));
    return 2;
  }

  // stepEnglish text 3: English textoutputdirectory
  std::string root=env_str("NEURX_ROOT",".");
  std::string base_out=env_str("NEURX_PRETRAIN_OUTPUT_DIR",
                                root+"/checkpoint/NeurX-Transformer");
  std::string out=base_out+(dist.world>1?"/rank_"+std::to_string(dist.rank):"");

  // stepEnglish text 4: loadTokenizer
  Tokenizer tok;
  if(!tok.load(env_str("NEURX_TOKENIZER_VOCAB",""),
               env_str("NEURX_TOKENIZER_MERGES","")))
    return 2;

  // stepEnglish text 5: English textmodelconfigurationparameter
  int seq=std::max(2,env_int("NEURX_PRETRAIN_SEQ_LEN",128));
  int dim=std::max(8,env_int("NEURX_TRANSFORMER_DIM",256));
  int heads=std::max(1,env_int("NEURX_TRANSFORMER_HEADS",8));
  int ffn=std::max(8,env_int("NEURX_TRANSFORMER_FFN",dim*3));
  int nl=std::max(1,env_int("NEURX_TRANSFORMER_NUM_LAYERS",4));
  int mb=std::max(1,env_int("NEURX_PRETRAIN_MICRO_BATCH",4));
  int ga=std::max(1,env_int("NEURX_GRADIENT_ACCUMULATION_STEPS",1));

  // stepEnglish text 6: English textmodelEnglish textGPUEnglish text
  // Model English textfunctionEnglish textparameterEnglish text GPU English text
  Model model(tok.size(),seq,dim,heads,ffn,nl);
  TrainCache cache(model);

  // stepEnglish text 7: loaddataShardEnglish text
  JsonlStream reader;
  reader.tok=&tok;
  if(!reader.load_list(env_str("NEURX_PRETRAIN_SHARD_LIST_FILE",
                                root+"/artifacts/build/run_large_pretrain/shard_list.txt"))){
    std::fprintf(stderr,"empty shard list\n");
    return 3;
  }

  // stepEnglish text 8: English textShardEnglish text
  if(dist.world>1){
    std::vector<std::string>local;
    for(size_t i=dist.rank;i<reader.shards.size();i+=dist.world)
      local.push_back(reader.shards[i]);
    reader.shards.swap(local);
    if(reader.shards.empty())return 3;
  }

  // ✅ English text Rank information
  std::printf("[trainer-v2] rank=%d world_size=%d local_rank=%d shards=%zu checkpoint=%s\n",
              dist.rank,dist.world,dist.local_rank,reader.shards.size(),out.c_str());

  // ============================================================
  // 🔴 English text: Checkpoint loadstart
  // ============================================================

  uint64_t step=0,optstep=0,micro=0,tokens=0;
  std::string resume=env_str("NEURX_PRETRAIN_RESUME_FROM",out+"/transformer_v2.ckpt");

  // stepEnglish text 9: English textResumeEnglish text
  if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(resume)){
    // ✅ V2 Checkpoint load
    if(!load_v2(model,tok,reader,resume,step,optstep,micro,tokens,mb,ga))
      return 4;
    // ✅ English textrecoverinformation
    std::printf("[checkpoint] restored v2 step=%llu shard=%d line=%llu micro=%llu\n",
                (unsigned long long)step,reader.cur.shard,
                (unsigned long long)reader.cur.line,(unsigned long long)micro);
  }
  else if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(out+"/transformer.ckpt")){
    // ✅ V1 Checkpoint load (English text)
    if(!load_v1(model,tok,out+"/transformer.ckpt",step))
      return 4;
    optstep=step;
    if(!save_v2(model,tok,reader,out,step,optstep,0,mb,ga,tokens))
      return 5;
  }

  // ... English texttrainingEnglish text
}
```

**📤 English textoutput**:
```
[trainer-v2] rank=0 world_size=1 local_rank=0 shards=1 checkpoint=/home/shuwen/shuwen/train/neurx/checkpoint/NeurX-1.3
[checkpoint] restored v2 step=360 shard=0 line=2 micro=0
```

---

## Checkpoint loadphase

### 3️⃣ V2English textload (`load_v2`)
**file**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L186)

```cpp
static bool load_v2(Model&m,Tokenizer&t,JsonlStream&r,
                    const std::string&path,uint64_t&step,uint64_t&opt,
                    uint64_t&micro,uint64_t&tokens,int mb,int ga){
  std::ifstream in(path,std::ios::binary);
  if(!in)return false;

  // ========== English textstep: English textCheckpointEnglish textinformation ==========
  HeaderV2 h{};
  if(!read_exact(in,&h,sizeof(h)))return false;

  // English text "NXTRFMV2"
  if(std::memcmp(h.magic,"NXTRFMV2",8))return false;
  if(h.version!=2||h.header_bytes!=sizeof(h))return false;

  // ========== English textstep: configurationEnglish text ==========
  if(h.vocab!=uint32_t(m.vocab)||h.seq!=uint32_t(m.seq)||
     h.dim!=uint32_t(m.dim)||h.heads!=uint32_t(m.heads)||
     h.ffn!=uint32_t(m.ffn)||h.layers!=uint32_t(m.nlayers)||
     h.micro_batch!=uint32_t(mb)||h.grad_accum!=uint32_t(ga)){
    std::fprintf(stderr,"NXTRFMV2 configuration mismatch\n");
    return false;
  }

  // ========== English textstep: TokenizerEnglish text ==========
  if(h.tokenizer_kind!=(t.kind=="bpe")||
     (h.tokenizer_kind&&h.tokenizer_hash!=t.fingerprint)){
    std::fprintf(stderr,"NXTRFMV2 tokenizer mismatch\n");
    return false;
  }

  // ========== English textstep: English textTokenizerinformation ==========
  std::string saved_vocab(h.vocab_path_bytes,'\0');
  std::string saved_merges(h.merges_path_bytes,'\0');
  if((h.vocab_path_bytes&&!read_exact(in,saved_vocab.data(),h.vocab_path_bytes))||
     (h.merges_path_bytes&&!read_exact(in,saved_merges.data(),h.merges_path_bytes)))
    return false;

  // ========== English textstep: recoverdataloadEnglish textstate ==========
  // recoverEnglish textShardEnglish text
  r.cur.shard=h.shard;
  // recoverShardEnglish text
  r.cur.line=h.line;
  // recoverEnglish text
  r.cur.docs=h.docs;

  // ========== English textstep: recoverPending TokenEnglish text ==========
  r.cur.pending.resize(h.pending_count);
  if(h.pending_count&&!read_exact(in,r.cur.pending.data(),h.pending_count*4))
    return false;

  // ========== English textstep: recovermodelparameter ==========
  // English textparameter, gradient, AdamoptimizeEnglish textstateEnglish textdata
  auto ps=m.params();
  if(h.param_count!=ps.size())return false;

  for(Param*p:ps){
    uint64_t n=0;
    // English textparametercount
    if(!read_exact(in,&n,8))return false;
    if(n!=uint64_t(p->n))return false;

    // English text4English textparameter:
    // 1. p->v: modelparameterEnglish text (n*4English text)
    // 2. p->g: gradient (n*4English text)
    // 3. p->m: AdamEnglish text m_t (n*4English text)
    // 4. p->s: AdamEnglish text v_t (n*4English text)
    if(!read_exact(in,p->v,n*4)||!read_exact(in,p->g,n*4)||
       !read_exact(in,p->m,n*4)||!read_exact(in,p->s,n*4))
      return false;
  }

  // ========== English textstep: recovertrainingstate ==========
  step=h.step;              // English texttrainingstepEnglish text
  opt=h.optimizer_step;     // optimizeEnglish textstepEnglish text
  micro=h.micro_step;       // English textbatchstepEnglish text
  tokens=h.tokens;          // English textTokenEnglish text

  return true;
}
```

**📤 English textoutput**: English textoutput (failureEnglish textstderr)

**📊 recoverEnglish textdata**:
| English text | English text | explanation |
|------|--------|------|
| magic | 8 | "NXTRFMV2" |
| version | 4 | English text = 2 |
| header_bytes | 4 | English text |
| step | 8 | **English texttrainingstepEnglish text** ← English text 360 |
| optimizer_step | 8 | **optimizeEnglish textstepEnglish text** |
| micro_step | 8 | English textbatchEnglish text |
| shard | 8 | **English textShardEnglish text** |
| line | 8 | **English text** |
| docs | 8 | English text |
| tokens | 8 | **English textTokenEnglish text** |
| vocab_path_bytes | 4 | VocabfileEnglish text |
| ... | ... | (English textconfigurationEnglish text) |
| **parameterdata** | **~6GB** | **p->v, p->g, p->m, p->s** |

---

### 4️⃣ V1English textload (English text)
**file**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L188)

```cpp
static bool load_v1(Model&m,Tokenizer&t,const std::string&path,uint64_t&step){
  std::ifstream in(path,std::ios::binary);
  HeaderV1 h{};
  if(!in||!read_exact(in,&h,sizeof(h)))return false;

  // English text "NXTRFMR1"
  if(std::memcmp(h.magic,"NXTRFMR1",8))return false;

  // V1English textsupportEnglish textbyte-levelmodelmigration
  if(t.kind!="byte_level"||m.vocab!=256||h.vocab!=m.vocab||
     h.seq!=m.seq||h.dim!=m.dim||h.heads!=m.heads||h.ffn!=m.ffn){
    std::fprintf(stderr,"NXTRFMR1 can only migrate with matching byte-level model dimensions\n");
    return false;
  }

  // English textloadEnglish textparameter (English text)
  std::vector<Param*>old{&m.emb,&m.layers[0]->nq,&m.layers[0]->nk,
                         &m.layers[0]->wq,&m.layers[0]->wk,&m.layers[0]->wv,
                         &m.layers[0]->wo,&m.layers[0]->nf,&m.layers[0]->wg,
                         &m.layers[0]->wu,&m.layers[0]->wd,&m.out};

  for(Param*p:old)
    if(!read_exact(in,p->v,p->n*4)||!read_exact(in,p->m,p->n*4)||
       !read_exact(in,p->s,p->n*4))
      return false;

  step=h.step;
  std::printf("[checkpoint] migrated NXTRFMR1 layer0; extra layers retain deterministic initialization\n");
  return true;
}
```

**📤 English textoutput**:
```
[checkpoint] migrated NXTRFMR1 layer0; extra layers retain deterministic initialization
```

---

## trainingstartphase

### 5️⃣ modelEnglish textinitialize
**file**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L70-95)

```cpp
// stepEnglish text A: English textModelEnglish text
// Model::Model() → English textparameterEnglish textGPUEnglish text
//
// English textparameterEnglish text4English textGPUEnglish text:
//   - p->v: parameterEnglish text (cudaMallocManaged)
//   - p->g: gradient (cudaMallocManaged)
//   - p->m: AdamEnglish text (cudaMallocManaged)
//   - p->s: AdamEnglish text (cudaMallocManaged)
//
// exampleparameterEnglish text:
//   Embedding: vocab_size × dim
//   Query/Key/Value Projections: dim × dim
//   Output Projections: dim × dim
//   FFN Up/Down: dim × ffn_dim
//   Layer Norms: dim

struct Param {
  float *v=nullptr,*g=nullptr,*m=nullptr,*s=nullptr;
  int64_t n=0;
  explicit Param(int64_t count=0):n(count){
    if(!n)return;
    cudaMallocManaged(&v,n*4);  // GPUEnglish text
    cudaMallocManaged(&g,n*4);
    cudaMallocManaged(&m,n*4);
    cudaMallocManaged(&s,n*4);
  }
};

// stepEnglish text B: English textTrainCacheEnglish text
TrainCache cache(model);  // English textgradientEnglish textGPUEnglish text
```

**📤 English textoutput**: English textoutput (failureEnglish textCUDAerror)

**📊 GPUEnglish text**:
```
parameterName           count              English text(float32)
─────────────────────────────────────────────
embedding:         vocab×dim         1.5GB
attention.q_proj:  dim×dim           0.3GB
attention.k_proj:  dim×dim           0.3GB
attention.v_proj:  dim×dim           0.3GB
attention.o_proj:  dim×dim           0.3GB
ffn.gate:          dim×ffn           0.9GB
ffn.up:            dim×ffn           0.9GB
ffn.down:          ffn×dim           0.9GB
layer_norm:        2×dim             English text
output_proj:       dim×vocab         1.5GB
─────────────────────────────────────────────
English textparameterEnglish text(v):       ~1.5B params       6.0GB
gradient(g):           English text               6.0GB  ← English textcheckpoint
Adam m(m):         English text               6.0GB  ← English textcheckpoint
Adam s(s):         English text               6.0GB  ← English textcheckpoint
─────────────────────────────────────────────
English text(cache):   seq×dimEnglish text         ~2GB
─────────────────────────────────────────────
English textGPUEnglish text:         ~20-24GB (English text)
```

---

### 6️⃣ cuBLASinitialize
**file**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L140-141)

```cpp
static cublasHandle_t blas=nullptr;

static bool gemm(float*a,float*b,float*c,int m,int k,int n){
  if(!blas)CUBLAS_CHECK(cublasCreate(&blas));  // ← English textuseEnglish texthandle
  const float one=1,zero=0;
  CUBLAS_CHECK(cublasSgemm(blas,CUBLAS_OP_N,CUBLAS_OP_N,n,m,k,
                           &one,b,n,a,k,&zero,c,n));
  return true;
}
```

**📤 English textoutput**: English text (failureEnglish textcuBLASerrorEnglish textstderr)

---

### 7️⃣ trainingstartEnglish textlog
**file**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L220-230)

```cpp
  // English texttrainingconfiguration
  std::printf("[trainer-v2] tokenizer=%s vocab=%d layers=%d seq=%d dim=%d heads=%d ffn=%d micro_batch=%d grad_accum=%d effective_sequences=%d\n",
              tok.kind.c_str(),model.vocab,nl,seq,dim,heads,ffn,mb,ga,mb*ga);

  // trainingEnglish text
  while(step<total){
    // ... English text, English text, gradientEnglish textstep, optimizeEnglish text ...

    // English textlog
    if(step==1||step%log_every==0)
      std::printf("[trainer-v2] step=%llu/%llu optimizer_step=%llu loss=%.6f tokens=%llu shard=%d line=%llu accum=%d/%d\n",
                  (unsigned long long)step,(unsigned long long)total,
                  (unsigned long long)optstep,loss_sum/std::max(1,this_batch),
                  (unsigned long long)tokens,reader.cur.shard,
                  (unsigned long long)reader.cur.line,accumulated,ga);

    // English textsavecheckpoint
    if(step%save_every==0&&!save_v2(model,tok,reader,out,
                                     step,optstep,accumulated,mb,ga,tokens))
      return 8;
  }

  // English textsave
  if(!save_v2(model,tok,reader,out,step,optstep,accumulated,mb,ga,tokens))
    return 8;
  std::printf("[trainer-v2] complete checkpoint=%s/transformer_v2.ckpt\n",out.c_str());
  return 0;
```

**📤 English textoutput**:
```
[trainer-v2] tokenizer=bpe vocab=374 layers=24 seq=256 dim=1024 heads=16 ffn=4096 micro_batch=1 grad_accum=8 effective_sequences=8
[trainer-v2] step=1/1000000000 optimizer_step=0 loss=6.896284 tokens=256 shard=0 line=1 accum=1/8
[trainer-v2] step=10/1000000000 optimizer_step=1 loss=5.646239 tokens=2560 shard=0 line=1 accum=2/8
...
[trainer-v2] step=360/1000000000 optimizer_step=45 loss=12.482535 tokens=92160 shard=0 line=2 accum=0/8
...
[trainer-v2] complete checkpoint=/home/shuwen/shuwen/train/neurx/checkpoint/NeurX-1.3/transformer_v2.ckpt
```

---

## completeEnglish textoutputEnglish text (English textrecoverstart)

```bash
# ===== startEnglish text =====
[multinode] nodes=1 world_size=1 master=localhost:29500
[multinode] shared NCCL id: /home/shuwen/shuwen/train/neurx/artifacts/nccl/unique_id
[multinode] rank=0 host=localhost local_rank=0

# ===== initializeEnglish text =====
[trainer-v2] rank=0 world_size=1 local_rank=0 shards=1 checkpoint=/home/shuwen/shuwen/train/neurx/checkpoint/NeurX-1.3

# ===== Checkpoint loadEnglish text ✅ =====
[checkpoint] restored v2 step=360 shard=0 line=2 micro=0

# ===== modelconfigurationEnglish texttrainingstart =====
[trainer-v2] tokenizer=bpe vocab=374 layers=24 seq=256 dim=1024 heads=16 ffn=4096 micro_batch=1 grad_accum=8 effective_sequences=8

# ===== English textlogoutput (English textstep=360English text) =====
[trainer-v2] step=360/1000000000 optimizer_step=45 loss=12.482535 tokens=92160 shard=0 line=2 accum=0/8
[trainer-v2] step=370/1000000000 optimizer_step=46 loss=11.923145 tokens=94720 shard=0 line=2 accum=2/8
[trainer-v2] step=380/1000000000 optimizer_step=47 loss=10.654321 tokens=97280 shard=0 line=2 accum=4/8
...
```

---

## dataEnglish text

```
┌─────────────────────────────────────────────────────────┐
│  transformer_v2.ckpt (6.1GB)                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Header: step=360, shard=0, line=2, tokens=92160 │   │
│  │ Embedding weights (p->v, p->g, p->m, p->s)      │   │
│  │ Layer 0-23 parameters (all 4 states)            │   │
│  │ Output projection weights                        │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────┬───────────────────────┘
                                  │
                    ┌─────────────▼────────────────┐
                    │  load_v2() function               │
                    ├────────────────────────────┤
                    │ ✅ English text "NXTRFMV2"    │
                    │ ✅ English textconfigurationEnglish text         │
                    │ ✅ English textTokenizer         │
                    │ ✅ recoverShardEnglish text         │
                    │ ✅ English textparameterEnglish textGPUEnglish text     │
                    │ ✅ recoveroptimizeEnglish textstate        │
                    └────────────────────────────┘
                                  │
                    ┌─────────────▼────────────────────┐
                    │  GPU English textstaterecover                 │
                    ├──────────────────────────────────┤
                    │ Model params:                    │
                    │   - v (parameterEnglish text) ✅ English textload         │
                    │   - g (gradient) ✅ English textload           │
                    │   - m (AdamEnglish text) ✅ English textload       │
                    │   - s (AdamEnglish text) ✅ English textload       │
                    │                                  │
                    │ TrainCache:                      │
                    │   - inputtoken: shard=0, line=2  │
                    │   - Pending tokens: recover         │
                    │   - English text: English textinitialize          │
                    │                                  │
                    │ Optimizer:                       │
                    │   - cuBLAS handle: ✅ initialize    │
                    │   - CUDA stream: ✅ initialize      │
                    │   - NCCL comm: ✅ initialize        │
                    └──────────────────────────────────┘
                                  │
                    ┌─────────────▼────────────────┐
                    │  trainingEnglish text (English text step=360)      │
                    ├────────────────────────────┤
                    │ English text (forward)         │
                    │ English text (backward)        │
                    │ gradientEnglish textstep (sync_gradients)  │
                    │ optimizeEnglish textstepEnglish text (optimizer_step)│
                    │ English text100stepsaveCheckpoint      │
                    └────────────────────────────┘
```

---

## English textphaseEnglish text

| phase | English text | English text | optimizeEnglish text |
|------|------|------|--------|
| **NCCL IDEnglish textstep** | English text60English text | Rank 0generate→English textrankEnglish text | English textfilesystemEnglish textgenerate |
| **modelinitialize** | 1-2English text | EmbeddingEnglish textLayerEnglish text | GPUEnglish text |
| **Checkpointload** | 5-10English text | 6GBdataEnglish text→GPU | English text |
| **cuBLASinitialize** | <1English text | English textgemmEnglish text | English text |
| **dataload** | English text | JSONL→Tokenize→English textgenerate | English textreader |

---

## English textconfigurationEnglish text

```bash
# Checkpointrecover
NEURX_PRETRAIN_RESUME=1                           # English textrecover(default)
NEURX_PRETRAIN_RESUME_FROM=/path/to/checkpoint    # English textloadpath
NEURX_PRETRAIN_OUTPUT_DIR=/path/to/output         # CheckpointsaveEnglish text

# modelconfiguration
NEURX_TRANSFORMER_DIM=1024
NEURX_TRANSFORMER_HEADS=16
NEURX_TRANSFORMER_FFN=4096
NEURX_TRANSFORMER_NUM_LAYERS=24
NEURX_PRETRAIN_SEQ_LEN=256

# optimizeEnglish texttraining
NEURX_PRETRAIN_MICRO_BATCH=1
NEURX_GRADIENT_ACCUMULATION_STEPS=8
NEURX_PRETRAIN_LR=0.0002
NEURX_PRETRAIN_STEPS=1000000000

# log
NEURX_PRETRAIN_LOG_INTERVAL=10
NEURX_PRETRAIN_SAVE_INTERVAL=100

# NCCL (English text)
NEURX_NCCL_ID_FILE=/path/to/nccl_id
NCCL_DEBUG=INFO
```
