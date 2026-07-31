# VERL vs NeurX 功能审计报告
生成时间: 2026-08-01
基准: /app/shuwen/train/verl 源码

---

## 审计方法论

### 数据来源
- **VERL**: `/app/shuwen/train/verl/verl/` 实际Python源码
- **NeurX**: `/app/shuwen/neurx/` 实际s语言源码
- **严格要求**: 必须找到实际可调用函数，不接受文档或文件名作为证据

### 等级定义
- **A级**: 真实训练运行通过（有测试记录/日志）
- **B级**: 编译和数值测试通过（有golden测试）
- **C级**: 可编译但未验证（语法正确，无运行证据）
- **D级**: 仅接口/骨架/模拟（有代码但不完整/不可用）
- **E级**: 完全缺失（verl有，neurx无）

---

## 第1部分：核心RL算法（Advantage Estimators）

基准文件: `/app/shuwen/train/verl/verl/trainer/ppo/core_algos.py`

| 算法 | VERL函数 | NeurX文件 | 等级 | 说明 |
|------|----------|-----------|------|------|
| GAE | `compute_gae_advantage_return()` | posttrain/alignment/ppo/ppo.s | ? | 需验证 |
| GRPO | `compute_grpo_outcome_advantage()` | posttrain/alignment/grpo/grpo.s | ? | 需验证 |
| GRPO_VECTORIZED | `compute_grpo_vectorized_outcome_advantage()` | posttrain/alignment/vectorized/vectorized_estimators.s | C | 2026-08-01创建，未编译 |
| GRPO_PASSK | `compute_grpo_passk_outcome_advantage()` | posttrain/alignment/grpo_passk/grpo_passk.s | C | 2026-08-01创建，未编译 |
| RLOO | `compute_rloo_outcome_advantage()` | posttrain/alignment/rloo/rloo.s | ? | 需验证 |
| RLOO_VECTORIZED | `compute_rloo_vectorized_outcome_advantage()` | posttrain/alignment/vectorized/vectorized_estimators.s | C | 2026-08-01创建，未编译 |
| OPO | `compute_opo_outcome_advantage()` | posttrain/alignment/opo/opo.s | ? | 需验证 |
| REINFORCE++ | `compute_reinforce_plus_plus_outcome_advantage()` | posttrain/alignment/reinforce_pp/reinforce_pp.s | ? | 需验证 |
| REINFORCE++_BASELINE | `compute_reinforce_plus_plus_baseline_outcome_advantage()` | ❌ 未找到 | E | 完全缺失 |
| REMAX | `compute_remax_outcome_advantage()` | posttrain/alignment/remax/remax.s | ? | 需验证 |
| GPG | `compute_gpg_outcome_advantage()` | posttrain/alignment/gpg/gpg.s | ? | 需验证 |
| OPTIMAL_TOKEN_BASELINE | `compute_optimal_token_baseline_advantage()` | posttrain/alignment/otb/otb.s | ? | 需验证 |
| MULTI_TURN_OTB | `compute_multi_turn_optimal_token_baseline_advantage()` | ❌ 未找到 | E | 完全缺失 |

**注**: "?" 表示文件存在但需要进一步验证是否可编译/运行

---

## 第2部分：Rollout Correction框架

基准文件: `/app/shuwen/train/verl/verl/trainer/ppo/rollout_corr_helper.py`

### 2.1 核心函数对比

| VERL函数 | 行数 | NeurX对应 | 等级 | 说明 |
|----------|------|-----------|------|------|
| `_parse_rollout_is_threshold()` | L93 | config.s | C | 配置解析，未测试 |
| `_parse_rollout_rs_thresholds()` | L132 | config.s | C | 配置解析，未测试 |
| `compute_rollout_rejection_mask()` | L197 | rejection_sampling.s:`compute_rejection_sampling()` | C | 2026-08-01创建，未编译 |
| `compute_rs_metrics()` | L416 | rejection_sampling.s:`compute_rs_statistics()` | C | 2026-08-01创建，未编译 |
| `compute_rollout_correction_weights()` | L522 | importance_sampling.s:`compute_is_weights()` | C | 2026-08-01创建，未编译 |
| `compute_is_metrics()` | L660 | importance_sampling.s:`compute_is_statistics()` | C | 2026-08-01创建，未编译 |
| `compute_rollout_correction_and_rejection_mask()` | L786 | rollout_correction.s:`apply_rollout_correction_to_loss()` | C | 2026-08-01创建，未编译 |
| `compute_offpolicy_metrics()` | L904 | ❌ 未实现 | E | 缺失KL/PPL/χ²诊断 |
| `compute_rollout_correction_and_add_to_batch()` | L1013 | ❌ 未实现 | E | 缺失批处理集成 |
| `compute_rollout_corr_metrics_from_logprobs()` | L1070 | ❌ 未实现 | E | 缺失指标计算 |
| `apply_bypass_mode()` | L1109 | rollout_correction.s:`compute_policy_loss_bypass_mode()` | C | 2026-08-01创建，未编译 |

### 2.2 IS/RS模式覆盖

#### Importance Sampling
| 模式 | VERL | NeurX | 状态 |
|------|------|-------|------|
| Token-level IS | ✅ | importance_sampling.s:`compute_token_is_weights()` | C-未测试 |
| Sequence-level IS | ✅ | importance_sampling.s:`compute_sequence_is_weights()` | C-未测试 |
| TIS (Truncated IS) | ✅ | config.s:`ISThreshold` | C-未测试 |
| IcePop | ✅ | config.s:`is_icepop` flag | C-未测试 |
| Batch Normalization | ✅ | importance_sampling.s:`batch_normalize_is_weights()` | C-未测试 |

#### Rejection Sampling (12种模式)
| 模式 | VERL | NeurX | 状态 |
|------|------|-------|------|
| token_k1 | ✅ | rejection_sampling.s:`compute_k1_divergence()` | C-未测试 |
| token_k2 | ✅ | rejection_sampling.s:`compute_k2_divergence()` | C-未测试 |
| token_k3 | ✅ | rejection_sampling.s:`compute_k3_divergence()` | C-未测试 |
| seq_sum_k1/k2/k3 | ✅ | rejection_sampling.s (SEQ_SUM模式) | C-未测试 |
| seq_mean_k1/k2/k3 | ✅ | rejection_sampling.s (SEQ_MEAN模式) | C-未测试 |
| seq_max_k2/k3 | ✅ | rejection_sampling.s (SEQ_MAX模式) | C-未测试 |

### 2.3 预设配置
| 预设 | VERL | NeurX | 状态 |
|------|------|-------|------|
| decoupled_token_is | ✅ | config.s:`decoupled_token_is()` | C-未测试 |
| decoupled_seq_is | ✅ | config.s:`decoupled_seq_is()` | C-未测试 |
| decoupled_token_icepop | ✅ | config.s:`decoupled_token_icepop()` | C-未测试 |
| decoupled_seq_is_rs | ✅ | config.s:`decoupled_seq_is_rs()` | C-未测试 |
| decoupled_geo_rs | ✅ | config.s:`decoupled_geo_rs()` | C-未测试 |
| decoupled_k3_rs | ✅ | config.s:`decoupled_k3_rs()` | C-未测试 |
| bypass_ppo_clip | ✅ | config.s:`bypass_ppo_clip()` | C-未测试 |
| bypass_pg_is | ✅ | config.s:`bypass_pg_is()` | C-未测试 |
| bypass_pg_geo_rs | ✅ | config.s:`bypass_pg_geo_rs()` | C-未测试 |
| (其他5个预设) | ✅ | config.s | C-未测试 |

---

## 第3部分：Policy Loss函数

基准文件: `/app/shuwen/train/verl/verl/trainer/ppo/core_algos.py`

| Loss类型 | VERL函数 | NeurX对应 | 等级 | 说明 |
|----------|----------|-----------|------|------|
| PPO Standard | `compute_policy_loss()` | ? | ? | 需验证 |
| PPO Vanilla | `compute_policy_loss_vanilla()` | ? | ? | 需验证 |
| DPPO-TV | `compute_policy_loss_dppo_tv()` | ? | ? | 需验证 |
| DPPO-KL | `compute_policy_loss_dppo_kl()` | ? | ? | 需验证 |
| GSPO | `compute_policy_loss_gspo()` | ? | ? | 需验证 |
| SAPO | `compute_policy_loss_sapo()` | ? | ? | 需验证 |
| GPG | `compute_policy_loss_gpg()` | ? | ? | 需验证 |
| CLIP-COV | `compute_policy_loss_clip_cov()` | ? | ? | 需验证 |
| KL-COV | `compute_policy_loss_kl_cov()` | ? | ? | 需验证 |
| GEO-MEAN | `compute_policy_loss_geo_mean()` | ? | ? | 需验证 |
| CISPO | `compute_policy_loss_cispo()` | ? | ? | 需验证 |
| REINFORCE | `compute_policy_loss_reinforce()` | ? | ? | 需验证 |
| Bypass Mode | `compute_policy_loss_bypass_mode()` | rollout_correction.s | C | 2026-08-01创建 |

---

## 第4部分：Workers & Rollout Backends

基准目录: `/app/shuwen/train/verl/verl/workers/`

### 4.1 Rollout Backends
| Backend | VERL文件 | NeurX对应 | 等级 | 说明 |
|---------|----------|-----------|------|------|
| vLLM | rollout/vllm_rollout/ | ❌ | E | 完全缺失 |
| TRT-LLM | rollout/trtllm_rollout/ | ❌ | E | 完全缺失 |
| SGLang | rollout/sglang_rollout/ | ❌ | E | 完全缺失 |
| HuggingFace | rollout/hf_rollout.py | ❌ | E | 完全缺失 |
| LLM Server | rollout/llm_server.py | ❌ | E | 完全缺失 |

### 4.2 Reward Managers
| Manager | VERL文件 | NeurX对应 | 等级 | 说明 |
|---------|----------|-----------|------|------|
| Naive | reward_manager/naive.py | ? | ? | 需验证 |
| Batch | reward_manager/batch.py | ? | ? | 需验证 |
| DAPO | reward_manager/dapo.py | ? | ? | 需验证 |
| PRIME | reward_manager/prime.py | ? | ? | 需验证 |
| Remote | reward_manager/remote.py (假设) | ❌ | E | 完全缺失 |

---

## 第5部分：Distillation

基准目录: `/app/shuwen/train/verl/verl/trainer/distillation/`

| 功能 | VERL | NeurX | 等级 | 说明 |
|------|------|-------|------|------|
| Multi-teacher | ? | distillation/multi_teacher_distillation.s | ? | 需验证 |
| Top-K KL | losses.py:`_chunked_topk_log_probs()` | ❌ | E | 缺失内存优化 |
| Loss Registry | ? | ❌ | E | 缺失注册系统 |

---

## 第6部分：Experimental功能

基准目录: `/app/shuwen/train/verl/verl/experimental/`

| 功能 | VERL目录 | NeurX对应 | 等级 | 说明 |
|------|----------|-----------|------|------|
| Fully Async Policy | fully_async_policy/ | ❌ | E | 完全缺失 |
| One-Step Off-Policy | one_step_off_policy/ | ❌ | E | 完全缺失 |
| Dynamic Scheduling | fully_async_policy/dynamic_schedule/ | ❌ | E | 完全缺失 |

---

## 第7部分：性能优化工具

基准目录: `/app/shuwen/train/verl/verl/trainer/ppo/` 和 `verl/utils/`

| 工具 | VERL文件 | NeurX对应 | 等级 | 说明 |
|------|----------|-----------|------|------|
| Prefix Grouping | ppo/prefix_grouper_utils.py | ❌ | E | 完全缺失 |
| Seqlen Balancing | utils/seqlen_balancing.py | ❌ | E | 完全缺失 |
| Transfer Queue | utils/transferqueue_utils.py | ❌ | E | 完全缺失 |

---

## 第8部分：新增代码验证状态（2026-08-01）

### 8.1 文件清单
| 文件 | 行数 | 创建时间 | 编译状态 | 测试状态 |
|------|------|----------|----------|----------|
| rollout_correction/config.s | ~350 | 2026-08-01 | ❌ 未编译 | ❌ 无测试 |
| rollout_correction/importance_sampling.s | ~280 | 2026-08-01 | ❌ 未编译 | ❌ 无测试 |
| rollout_correction/rejection_sampling.s | ~380 | 2026-08-01 | ❌ 未编译 | ❌ 无测试 |
| rollout_correction/rollout_correction.s | ~250 | 2026-08-01 | ❌ 未编译 | ❌ 无测试 |
| grpo_passk/grpo_passk.s | ~420 | 2026-08-01 | ❌ 未编译 | ❌ 无测试 |
| tir_otb/tir_optimal_token_baseline.s | ~380 | 2026-08-01 | ❌ 未编译 | ❌ 无测试 |
| vectorized/vectorized_estimators.s | ~320 | 2026-08-01 | ❌ 未编译 | ❌ 无测试 |
| **总计** | **~2380行** | - | **0/7通过** | **0/7通过** |

### 8.2 编译测试计划
```bash
# 待执行的编译命令
s compile posttrain/alignment/rollout_correction/config.s
s compile posttrain/alignment/rollout_correction/importance_sampling.s
s compile posttrain/alignment/rollout_correction/rejection_sampling.s
s compile posttrain/alignment/rollout_correction/rollout_correction.s
s compile posttrain/alignment/grpo_passk/grpo_passk.s
s compile posttrain/alignment/tir_otb/tir_optimal_token_baseline.s
s compile posttrain/alignment/vectorized/vectorized_estimators.s
```

### 8.3 数值验证需求

#### Importance Sampling Golden Test
需要验证:
- [ ] Token-level IS weights计算正确性
- [ ] Sequence-level IS weights计算正确性
- [ ] TIS截断行为
- [ ] IcePop零权重行为
- [ ] Batch normalization数值

测试方法:
```python
# 使用verl生成golden输出
# 对比neurx实现输出
```

#### Rejection Sampling Golden Test
需要验证:
- [ ] K1/K2/K3散度计算
- [ ] Token vs Sequence聚合
- [ ] Sum/Mean/Max聚合
- [ ] Rejection mask正确性

#### Vectorized vs Scalar一致性
需要验证:
- [ ] RLOO vectorized == RLOO scalar
- [ ] GRPO vectorized == GRPO scalar
- [ ] 性能提升测量

### 8.4 训练集成验证

需要证明:
- [ ] Rollout Correction进入真实policy loss计算
- [ ] 产生非零梯度
- [ ] 梯度可反向传播
- [ ] Loss收敛曲线

---

## 审计总结

### 统计数据

#### 按等级分布
- **A级（真实运行通过）**: 0项
- **B级（编译+数值测试）**: 0项
- **C级（可编译未验证）**: ~20项 (2026-08-01新增)
- **D级（仅骨架）**: 待统计
- **E级（完全缺失）**: ~15项

#### 关键发现
1. **Rollout Correction**: 有代码骨架（C级），但无编译/测试/训练验证
2. **Vectorized算法**: 有代码骨架（C级），但无性能对比
3. **GRPO_PASSK**: 有代码骨架（C级），但无pass@k测试
4. **TIR-OTB**: 有代码骨架（C级），但无IS+OTB数值验证
5. **Async Training**: 完全缺失（E级）
6. **Rollout Backends**: 完全缺失（E级）- vLLM/TRT-LLM/SGLang
7. **Off-policy Metrics**: 完全缺失（E级）- KL/PPL/χ²诊断
8. **Prefix Grouping**: 完全缺失（E级）
9. **REINFORCE++_BASELINE**: 完全缺失（E级）
10. **Multi-turn OTB**: 完全缺失（E级）

### 验证缺口

#### 高优先级（阻塞训练）
1. ❌ **编译测试**: 2380行新代码未编译
2. ❌ **数值测试**: 无golden对比
3. ❌ **训练集成**: 无loss/梯度证明
4. ❌ **Rollout Backend**: 无推理引擎支持

#### 中优先级（影响功能完整性）
5. ❌ **Off-policy诊断**: 缺失KL/PPL指标
6. ❌ **向量化性能**: 无性能对比数据
7. ❌ **Pass@k评估**: 无代码执行引擎

### 下一步行动

**禁止**:
- ❌ 继续创建新文件/新功能
- ❌ 实现Fully Async Training
- ❌ 更新宣传文档

**必须**:
1. ✅ 编译所有2380行新代码
2. ✅ 运行IS/RS/Vectorized数值测试
3. ✅ 证明Rollout Correction进入训练循环
4. ✅ 提供梯度非零证据
5. ✅ 补充verl对比的golden测试

---

## 结论

**当前状态**:
> NeurX已为Rollout Correction、GRPO_PASSK、TIR-OTB和向量化估计器创建候选代码（~2380行），尚未验证。

**不能声称**:
> ~~核心高优先级功能已全部实现~~ ❌

**验证等级**:
- 0项达到A级（真实运行）
- 0项达到B级（编译+测试）
- ~20项达到C级（代码存在）
- ~15项为E级（完全缺失）

**阻塞问题**:
1. 无编译证明
2. 无数值验证
3. 无训练集成
4. 无推理后端

**建议**:
专注验证现有实现，暂停新功能开发。
