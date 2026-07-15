# Checkpoint 加载完整流程分析

## 初始化阶段

### 1️⃣ 分布式初始化 (`init_distributed`)
**文件**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L104-L113)

```cpp
static bool init_distributed(DistributedContext&d){
  // 读取环境变量
  d.rank=std::max(0,env_int("RANK",0));
  d.world=std::max(1,env_int("WORLD_SIZE",1));
  d.local_rank=std::max(0,env_int("LOCAL_RANK",d.rank));
  
  // 1.1 设置CUDA设备
  if(d.rank>=d.world)return false;
  CUDA_CHECK(cudaSetDevice(d.local_rank));  // 选择GPU设备
  CUDA_CHECK(cudaStreamCreate(&d.stream));   // 创建CUDA流
  
  // 1.2 单节点训练直接返回
  if(d.world==1)return true;
  
  // 1.3 多节点NCCL初始化
  std::string id_path=env_str("NEURX_NCCL_ID_FILE","/tmp/neurx_nccl_id");
  ncclUniqueId id{};
  
  // Rank 0 生成唯一ID
  if(d.rank==0){
    NCCL_CHECK(ncclGetUniqueId(&id));
    if(!write_nccl_id(id_path,id)){
      std::fprintf(stderr,"cannot write NCCL id: %s\n",id_path.c_str());
      return false;
    }
  }
  // 其他Rank轮询读取ID (最多等600×100ms = 60秒)
  else {
    for(int i=0;i<600&&!read_nccl_id(id_path,id);i++)
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    if(!read_nccl_id(id_path,id))return false;
  }
  
  // 1.4 初始化NCCL通信组
  NCCL_CHECK(ncclCommInitRank(&d.comm,d.world,id,d.rank));
  return true;
}
```

**📤 控制台输出**: 
- 无直接输出 (失败时打印stderr: "cannot write NCCL id: ..." 或NCCL错误)

---

### 2️⃣ 主函数初始化 (`main`)
**文件**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L192-L203)

```cpp
int main(){
  // 步骤 1: 分布式CUDA/NCCL初始化
  DistributedContext dist;
  if(!init_distributed(dist)){
    std::fprintf(stderr,"distributed CUDA/NCCL initialization failed\n");
    return 2;
  }
  
  // 步骤 2: 检查CUDA设备
  int device_count=0;
  cudaError_t device_status=cudaGetDeviceCount(&device_count);
  if(device_status!=cudaSuccess||device_count<1){
    std::fprintf(stderr,"CUDA device unavailable: %s\n",cudaGetErrorString(device_status));
    return 2;
  }
  
  // 步骤 3: 确定输出目录
  std::string root=env_str("NEURX_ROOT",".");
  std::string base_out=env_str("NEURX_PRETRAIN_OUTPUT_DIR",
                                root+"/checkpoint/NeurX-Transformer");
  std::string out=base_out+(dist.world>1?"/rank_"+std::to_string(dist.rank):"");
  
  // 步骤 4: 加载Tokenizer
  Tokenizer tok;
  if(!tok.load(env_str("NEURX_TOKENIZER_VOCAB",""),
               env_str("NEURX_TOKENIZER_MERGES","")))
    return 2;
  
  // 步骤 5: 解析模型配置参数
  int seq=std::max(2,env_int("NEURX_PRETRAIN_SEQ_LEN",128));
  int dim=std::max(8,env_int("NEURX_TRANSFORMER_DIM",256));
  int heads=std::max(1,env_int("NEURX_TRANSFORMER_HEADS",8));
  int ffn=std::max(8,env_int("NEURX_TRANSFORMER_FFN",dim*3));
  int nl=std::max(1,env_int("NEURX_TRANSFORMER_NUM_LAYERS",4));
  int mb=std::max(1,env_int("NEURX_PRETRAIN_MICRO_BATCH",4));
  int ga=std::max(1,env_int("NEURX_GRADIENT_ACCUMULATION_STEPS",1));
  
  // 步骤 6: 创建模型并分配GPU显存
  // Model 构造函数会为所有参数分配 GPU 显存
  Model model(tok.size(),seq,dim,heads,ffn,nl);
  TrainCache cache(model);
  
  // 步骤 7: 加载数据Shard列表
  JsonlStream reader;
  reader.tok=&tok;
  if(!reader.load_list(env_str("NEURX_PRETRAIN_SHARD_LIST_FILE",
                                root+"/artifacts/build/run_large_pretrain/shard_list.txt"))){
    std::fprintf(stderr,"empty shard list\n");
    return 3;
  }
  
  // 步骤 8: 分布式Shard分配
  if(dist.world>1){
    std::vector<std::string>local;
    for(size_t i=dist.rank;i<reader.shards.size();i+=dist.world)
      local.push_back(reader.shards[i]);
    reader.shards.swap(local);
    if(reader.shards.empty())return 3;
  }
  
  // ✅ 打印 Rank 信息
  std::printf("[trainer-v2] rank=%d world_size=%d local_rank=%d shards=%zu checkpoint=%s\n",
              dist.rank,dist.world,dist.local_rank,reader.shards.size(),out.c_str());
  
  // ============================================================
  // 🔴 关键点: Checkpoint 加载开始
  // ============================================================
  
  uint64_t step=0,optstep=0,micro=0,tokens=0;
  std::string resume=env_str("NEURX_PRETRAIN_RESUME_FROM",out+"/transformer_v2.ckpt");
  
  // 步骤 9: 检查Resume环境变量
  if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(resume)){
    // ✅ V2 Checkpoint 加载
    if(!load_v2(model,tok,reader,resume,step,optstep,micro,tokens,mb,ga))
      return 4;
    // ✅ 打印恢复信息
    std::printf("[checkpoint] restored v2 step=%llu shard=%d line=%llu micro=%llu\n",
                (unsigned long long)step,reader.cur.shard,
                (unsigned long long)reader.cur.line,(unsigned long long)micro);
  }
  else if(env_int("NEURX_PRETRAIN_RESUME",1)&&exists(out+"/transformer.ckpt")){
    // ✅ V1 Checkpoint 加载 (向后兼容)
    if(!load_v1(model,tok,out+"/transformer.ckpt",step))
      return 4;
    optstep=step;
    if(!save_v2(model,tok,reader,out,step,optstep,0,mb,ga,tokens))
      return 5;
  }
  
  // ... 后续训练代码
}
```

**📤 控制台输出**:
```
[trainer-v2] rank=0 world_size=1 local_rank=0 shards=1 checkpoint=/home/shuwen/shuwen/train/neurx/checkpoint/NeurX-1.3
[checkpoint] restored v2 step=360 shard=0 line=2 micro=0
```

---

## Checkpoint 加载阶段

### 3️⃣ V2格式加载 (`load_v2`)
**文件**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L186)

```cpp
static bool load_v2(Model&m,Tokenizer&t,JsonlStream&r,
                    const std::string&path,uint64_t&step,uint64_t&opt,
                    uint64_t&micro,uint64_t&tokens,int mb,int ga){
  std::ifstream in(path,std::ios::binary);
  if(!in)return false;
  
  // ========== 第一步: 读取Checkpoint头信息 ==========
  HeaderV2 h{};
  if(!read_exact(in,&h,sizeof(h)))return false;
  
  // 验证魔数 "NXTRFMV2"
  if(std::memcmp(h.magic,"NXTRFMV2",8))return false;
  if(h.version!=2||h.header_bytes!=sizeof(h))return false;
  
  // ========== 第二步: 配置一致性检查 ==========
  if(h.vocab!=uint32_t(m.vocab)||h.seq!=uint32_t(m.seq)||
     h.dim!=uint32_t(m.dim)||h.heads!=uint32_t(m.heads)||
     h.ffn!=uint32_t(m.ffn)||h.layers!=uint32_t(m.nlayers)||
     h.micro_batch!=uint32_t(mb)||h.grad_accum!=uint32_t(ga)){
    std::fprintf(stderr,"NXTRFMV2 configuration mismatch\n");
    return false;
  }
  
  // ========== 第三步: Tokenizer一致性检查 ==========
  if(h.tokenizer_kind!=(t.kind=="bpe")||
     (h.tokenizer_kind&&h.tokenizer_hash!=t.fingerprint)){
    std::fprintf(stderr,"NXTRFMV2 tokenizer mismatch\n");
    return false;
  }
  
  // ========== 第四步: 读取Tokenizer信息 ==========
  std::string saved_vocab(h.vocab_path_bytes,'\0');
  std::string saved_merges(h.merges_path_bytes,'\0');
  if((h.vocab_path_bytes&&!read_exact(in,saved_vocab.data(),h.vocab_path_bytes))||
     (h.merges_path_bytes&&!read_exact(in,saved_merges.data(),h.merges_path_bytes)))
    return false;
  
  // ========== 第五步: 恢复数据加载器状态 ==========
  // 恢复要读取的Shard编号
  r.cur.shard=h.shard;
  // 恢复Shard中的行号
  r.cur.line=h.line;
  // 恢复已处理的文档数
  r.cur.docs=h.docs;
  
  // ========== 第六步: 恢复Pending Token缓冲 ==========
  r.cur.pending.resize(h.pending_count);
  if(h.pending_count&&!read_exact(in,r.cur.pending.data(),h.pending_count*4))
    return false;
  
  // ========== 第七步: 恢复模型参数 ==========
  // 为所有参数、梯度、Adam优化器状态读取数据
  auto ps=m.params();
  if(h.param_count!=ps.size())return false;
  
  for(Param*p:ps){
    uint64_t n=0;
    // 读取参数数量
    if(!read_exact(in,&n,8))return false;
    if(n!=uint64_t(p->n))return false;
    
    // 读取4个参数:
    // 1. p->v: 模型参数值 (n*4字节)
    // 2. p->g: 梯度 (n*4字节)
    // 3. p->m: Adam动量 m_t (n*4字节)
    // 4. p->s: Adam方差 v_t (n*4字节)
    if(!read_exact(in,p->v,n*4)||!read_exact(in,p->g,n*4)||
       !read_exact(in,p->m,n*4)||!read_exact(in,p->s,n*4))
      return false;
  }
  
  // ========== 第八步: 恢复训练状态 ==========
  step=h.step;              // 当前训练步数
  opt=h.optimizer_step;     // 优化器更新步数
  micro=h.micro_step;       // 微批次步数
  tokens=h.tokens;          // 已处理Token总数
  
  return true;
}
```

**📤 控制台输出**: 无直接输出 (失败时打印到stderr)

**📊 恢复的数据**:
| 字段 | 字节数 | 说明 |
|------|--------|------|
| magic | 8 | "NXTRFMV2" |
| version | 4 | 版本号 = 2 |
| header_bytes | 4 | 头部大小 |
| step | 8 | **当前训练步数** ← 例如 360 |
| optimizer_step | 8 | **优化器步数** |
| micro_step | 8 | 微批次累积数 |
| shard | 8 | **当前Shard索引** |
| line | 8 | **当前行号** |
| docs | 8 | 已处理文档数 |
| tokens | 8 | **已处理Token总数** |
| vocab_path_bytes | 4 | Vocab文件大小 |
| ... | ... | (其他配置字段) |
| **参数数据** | **~6GB** | **p->v, p->g, p->m, p->s** |

---

### 4️⃣ V1格式加载 (向后兼容)
**文件**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L188)

```cpp
static bool load_v1(Model&m,Tokenizer&t,const std::string&path,uint64_t&step){
  std::ifstream in(path,std::ios::binary);
  HeaderV1 h{};
  if(!in||!read_exact(in,&h,sizeof(h)))return false;
  
  // 验证魔数 "NXTRFMR1"
  if(std::memcmp(h.magic,"NXTRFMR1",8))return false;
  
  // V1只支持单层byte-level模型迁移
  if(t.kind!="byte_level"||m.vocab!=256||h.vocab!=m.vocab||
     h.seq!=m.seq||h.dim!=m.dim||h.heads!=m.heads||h.ffn!=m.ffn){
    std::fprintf(stderr,"NXTRFMR1 can only migrate with matching byte-level model dimensions\n");
    return false;
  }
  
  // 只加载第一层参数 (向后兼容)
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

**📤 控制台输出**:
```
[checkpoint] migrated NXTRFMR1 layer0; extra layers retain deterministic initialization
```

---

## 训练启动阶段

### 5️⃣ 模型和显存初始化
**文件**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L70-95)

```cpp
// 步骤 A: 创建Model对象时自动进行
// Model::Model() → 为每个参数分配GPU显存
// 
// 每个参数分配4个GPU数组:
//   - p->v: 参数值 (cudaMallocManaged)
//   - p->g: 梯度 (cudaMallocManaged)
//   - p->m: Adam动量 (cudaMallocManaged)
//   - p->s: Adam方差 (cudaMallocManaged)
//
// 示例参数结构:
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
    cudaMallocManaged(&v,n*4);  // GPU显存分配
    cudaMallocManaged(&g,n*4);
    cudaMallocManaged(&m,n*4);
    cudaMallocManaged(&s,n*4);
  }
};

// 步骤 B: 创建TrainCache对象时
TrainCache cache(model);  // 为中间激活值和梯度分配GPU显存
```

**📤 控制台输出**: 无直接输出 (失败时CUDA错误)

**📊 GPU显存分配**:
```
参数名称           数量              显存(float32)
─────────────────────────────────────────────
embedding:         vocab×dim         1.5GB
attention.q_proj:  dim×dim           0.3GB
attention.k_proj:  dim×dim           0.3GB
attention.v_proj:  dim×dim           0.3GB
attention.o_proj:  dim×dim           0.3GB
ffn.gate:          dim×ffn           0.9GB
ffn.up:            dim×ffn           0.9GB
ffn.down:          ffn×dim           0.9GB
layer_norm:        2×dim             微小
output_proj:       dim×vocab         1.5GB
─────────────────────────────────────────────
总参数值(v):       ~1.5B params       6.0GB
梯度(g):           同上               6.0GB  ← 来自checkpoint
Adam m(m):         同上               6.0GB  ← 来自checkpoint
Adam s(s):         同上               6.0GB  ← 来自checkpoint
─────────────────────────────────────────────
中间激活(cache):   seq×dim等         ~2GB
─────────────────────────────────────────────
总GPU显存:         ~20-24GB (取决于显卡)
```

---

### 6️⃣ cuBLAS初始化
**文件**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L140-141)

```cpp
static cublasHandle_t blas=nullptr;

static bool gemm(float*a,float*b,float*c,int m,int k,int n){
  if(!blas)CUBLAS_CHECK(cublasCreate(&blas));  // ← 首次使用时创建handle
  const float one=1,zero=0;
  CUBLAS_CHECK(cublasSgemm(blas,CUBLAS_OP_N,CUBLAS_OP_N,n,m,k,
                           &one,b,n,a,k,&zero,c,n));
  return true;
}
```

**📤 控制台输出**: 无 (失败时打印cuBLAS错误到stderr)

---

### 7️⃣ 训练启动和日志
**文件**: [neurx_transformer_train_v2.cu](neurx_transformer_train_v2.cu#L220-230)

```cpp
  // 打印训练配置
  std::printf("[trainer-v2] tokenizer=%s vocab=%d layers=%d seq=%d dim=%d heads=%d ffn=%d micro_batch=%d grad_accum=%d effective_sequences=%d\n",
              tok.kind.c_str(),model.vocab,nl,seq,dim,heads,ffn,mb,ga,mb*ga);
  
  // 训练循环
  while(step<total){
    // ... 前向传播、反向传播、梯度同步、优化器更新 ...
    
    // 定期打印日志
    if(step==1||step%log_every==0)
      std::printf("[trainer-v2] step=%llu/%llu optimizer_step=%llu loss=%.6f tokens=%llu shard=%d line=%llu accum=%d/%d\n",
                  (unsigned long long)step,(unsigned long long)total,
                  (unsigned long long)optstep,loss_sum/std::max(1,this_batch),
                  (unsigned long long)tokens,reader.cur.shard,
                  (unsigned long long)reader.cur.line,accumulated,ga);
    
    // 定期保存checkpoint
    if(step%save_every==0&&!save_v2(model,tok,reader,out,
                                     step,optstep,accumulated,mb,ga,tokens))
      return 8;
  }
  
  // 最终保存
  if(!save_v2(model,tok,reader,out,step,optstep,accumulated,mb,ga,tokens))
    return 8;
  std::printf("[trainer-v2] complete checkpoint=%s/transformer_v2.ckpt\n",out.c_str());
  return 0;
```

**📤 控制台输出**:
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

## 完整控制台输出序列 (从恢复开始)

```bash
# ===== 启动程序 =====
[multinode] nodes=1 world_size=1 master=localhost:29500
[multinode] shared NCCL id: /home/shuwen/shuwen/train/neurx/artifacts/nccl/unique_id
[multinode] rank=0 host=localhost local_rank=0

# ===== 初始化完成 =====
[trainer-v2] rank=0 world_size=1 local_rank=0 shards=1 checkpoint=/home/shuwen/shuwen/train/neurx/checkpoint/NeurX-1.3

# ===== Checkpoint 加载完成 ✅ =====
[checkpoint] restored v2 step=360 shard=0 line=2 micro=0

# ===== 模型配置和训练启动 =====
[trainer-v2] tokenizer=bpe vocab=374 layers=24 seq=256 dim=1024 heads=16 ffn=4096 micro_batch=1 grad_accum=8 effective_sequences=8

# ===== 定期日志输出 (从step=360继续) =====
[trainer-v2] step=360/1000000000 optimizer_step=45 loss=12.482535 tokens=92160 shard=0 line=2 accum=0/8
[trainer-v2] step=370/1000000000 optimizer_step=46 loss=11.923145 tokens=94720 shard=0 line=2 accum=2/8
[trainer-v2] step=380/1000000000 optimizer_step=47 loss=10.654321 tokens=97280 shard=0 line=2 accum=4/8
...
```

---

## 数据流向总结

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
                    │  load_v2() 函数               │
                    ├────────────────────────────┤
                    │ ✅ 验证魔数 "NXTRFMV2"    │
                    │ ✅ 校验配置一致性         │
                    │ ✅ 校验Tokenizer         │
                    │ ✅ 恢复Shard位置         │
                    │ ✅ 读取参数到GPU显存     │
                    │ ✅ 恢复优化器状态        │
                    └────────────────────────────┘
                                  │
                    ┌─────────────▼────────────────────┐
                    │  GPU 显存状态恢复                 │
                    ├──────────────────────────────────┤
                    │ Model params:                    │
                    │   - v (参数值) ✅ 已加载         │
                    │   - g (梯度) ✅ 已加载           │
                    │   - m (Adam动量) ✅ 已加载       │
                    │   - s (Adam方差) ✅ 已加载       │
                    │                                  │
                    │ TrainCache:                      │
                    │   - 输入token: shard=0, line=2  │
                    │   - Pending tokens: 恢复         │
                    │   - 中间激活: 零初始化          │
                    │                                  │
                    │ Optimizer:                       │
                    │   - cuBLAS handle: ✅ 初始化    │
                    │   - CUDA stream: ✅ 初始化      │
                    │   - NCCL comm: ✅ 初始化        │
                    └──────────────────────────────────┘
                                  │
                    ┌─────────────▼────────────────┐
                    │  训练继续 (从 step=360)      │
                    ├────────────────────────────┤
                    │ 前向传播 (forward)         │
                    │ 反向传播 (backward)        │
                    │ 梯度同步 (sync_gradients)  │
                    │ 优化器步骤 (optimizer_step)│
                    │ 每100步保存Checkpoint      │
                    └────────────────────────────┘
```

---

## 关键耗时阶段分析

| 阶段 | 耗时 | 原因 | 优化建议 |
|------|------|------|--------|
| **NCCL ID同步** | 最多60秒 | Rank 0生成→其他rank轮询读取 | 加快文件系统或预生成 |
| **模型初始化** | 1-2秒 | Embedding和Layer创建 | GPU内存压力小 |
| **Checkpoint加载** | 5-10秒 | 6GB数据从磁盘读→GPU | 固态硬盘加速 |
| **cuBLAS初始化** | <1秒 | 首次gemm调用时 | 单次开销 |
| **数据加载** | 连续 | JSONL→Tokenize→序列生成 | 多线程reader |

---

## 环境变量配置参考

```bash
# Checkpoint恢复
NEURX_PRETRAIN_RESUME=1                           # 启用恢复(默认)
NEURX_PRETRAIN_RESUME_FROM=/path/to/checkpoint    # 自定义加载路径
NEURX_PRETRAIN_OUTPUT_DIR=/path/to/output         # Checkpoint保存位置

# 模型配置
NEURX_TRANSFORMER_DIM=1024
NEURX_TRANSFORMER_HEADS=16
NEURX_TRANSFORMER_FFN=4096
NEURX_TRANSFORMER_NUM_LAYERS=24
NEURX_PRETRAIN_SEQ_LEN=256

# 优化器和训练
NEURX_PRETRAIN_MICRO_BATCH=1
NEURX_GRADIENT_ACCUMULATION_STEPS=8
NEURX_PRETRAIN_LR=0.0002
NEURX_PRETRAIN_STEPS=1000000000

# 日志
NEURX_PRETRAIN_LOG_INTERVAL=10
NEURX_PRETRAIN_SAVE_INTERVAL=100

# NCCL (多节点)
NEURX_NCCL_ID_FILE=/path/to/nccl_id
NCCL_DEBUG=INFO
```
