# ⚡ NeurX Claude级别升级 - P0优先行动计划 (立即执行)

**生效日期**: 2026-07-16  
**执行周期**: 第1-2周（第1阶段前期）  
**目标**: 确立4个关键基础，决定后续方向  

---

## 📋 P0 优先行动清单

### 🔴 行动1: 审视 Flash Attention v3 实现
**估时**: 3-4 天 | **优先级**: P0 | **负责**: AI 系统专家  
**目标**: 确认实现正确性，为推理优化奠定基础

#### 任务细节
```
1. 文件审视 (1天)
   - 打开: /train/neurx/attention/flash_attention_v3.s
   - 检查清单:
     ☐ Forward pass 是否实现 tiling 策略
     ☐ Backward pass 是否支持梯度计算
     ☐ online softmax 是否正确实现
     ☐ GQA (Grouped Query Attention) 广播逻辑
     ☐ 因果掩码是否正确处理

2. 对标验证 (1天)
   - 比对论文: "Flash-2: Faster Attention with Better Parallelism..."
   - 关键指标:
     ☐ Flops/byte ratio
     ☐ HBM accesses (应接近理论下界)
     ☐ 精度 (BFLOAT16 下 VS 标准注意力)

3. 性能测试 (1-2天)
   - 测试条件: seq_len=4096, batch=32, hidden=768, heads=12
   - 预期结果:
     ☐ 相对标准注意力: 1.5-2.0 倍加速
     ☐ 内存使用: -30-40%
     ☐ 精度loss: <0.1%

4. 缺陷记录 (即时)
   - 格式: GitHub Issues 或 Confluence
   - 模板:
     ```
     [FA-v3-001] 问题描述
     - 影响: 【高|中|低】
     - 修复工作量: X 天
     - 阻塞: 【是|否】
     ```
```

#### 验收标准
```
✅ 代码审查完成 (对标论文)
✅ 性能测试报告 (数值在预期范围)
✅ 缺陷列表 (优先级排序)
✅ 改进建议文档 (3页以内)
```

#### 相关文件
- 实现: `attention/flash_attention_v3.s`
- 相关: `model/llm/gpt.s` (调用点), `model/transformer/transformer_block.s`
- 参考: Flash-Attention 论文集 & DeepSeek/Ollama 实现

---

### 🔴 行动2: 集成 MMLU 基准数据
**估时**: 2-3 天 | **优先级**: P0 | **负责**: 评估框架负责人  
**目标**: 建立 NeurX 的质量基线，对标 Claude/GPT-4

#### 任务细节
```
1. 数据采集 (0.5天)
   - 下载 MMLU 数据集 (57 个学科)
   - 源: https://github.com/hendrycks/MMLU
   - 验证:
     ☐ 5-shot 子集是否正确 (应该 ~14,000 个样例)
     ☐ 格式是否为 {question, options_A/B/C/D, answer}
     ☐ 编码是否为 UTF-8

2. 数据集成到 benchmark_eval.s (1-1.5天)
   - 修改: eval/benchmark_eval.s
   - 步骤:
     ☐ 添加 MMLU 数据加载器
     ☐ 实现 5-shot prompt 构建
     ☐ 实现多选评分逻辑 (log-likelihood)
     ☐ 添加 subject-wise 报告
   - 代码框架:
     ```s
     struct MMULUEval {
         dataset: []MMULUSample
         num_shots: int
         results: map[string]float32  // subject -> accuracy
     }
     
     func eval_mmlu(model, data) MMULUResult {
         // For each subject (math, science, history, etc.)
         // For each question:
         //   1. Build 5-shot prompt
         //   2. Get model logits for each choice
         //   3. Compute log-likelihood
         //   4. Select argmax
         //   5. Compare with gold answer
     }
     ```

3. 基准线测试 (1天)
   - 小规模模型测试 (7B 参数)
   - 预期结果:
     ☐ MMLU 总体: 60-70% (基线)
     ☐ 最强科目: 80%+ (如数学)
     ☐ 最弱科目: 40-50% (如历史)
     ☐ 性能对标: 与 Llama2-7B 的 46% 比较

4. 报告生成 (0.5天)
   - 输出格式: 
     ```
     MMLU Evaluation Report
     ========================
     Model: NeurX-7B
     Date: 2026-07-XX
     
     Overall: 65.3% ± 2.1%
     
     By Subject:
       STEM (24 subjects): 72.1%
       Humanities (13): 58.2%
       Social Sciences (11): 61.5%
       Other (9): 62.8%
     
     Detailed Results:
       abstract_algebra: 58%
       anatomy: 64%
       ...
     ```
```

#### 验收标准
```
✅ 数据集完整集成 (57 个学科, ~14K 样例)
✅ 评分逻辑正确 (对比参考实现 lm-evaluation-harness)
✅ 基准线报告 (总体准确率, 分学科分析)
✅ 性能满足预期 (7B 模型 60-70% 准确率)
```

#### 相关文件
- 框架: `eval/benchmark_eval.s` (已有435行基础框架)
- 模型接口: `model/llm/gpt.s` (需要 gpt_forward, gpt_generate)
- 参考实现: `github.com/EleutherAI/lm-evaluation-harness`

---

### 🔴 行动3: 验证 RoPE 长序列支持
**估时**: 2-3 天 | **优先级**: P0 | **负责**: 架构优化负责人  
**目标**: 验证 64K-128K token 上的位置插值正确性

#### 任务细节
```
1. 代码审视 (1天)
   - 打开: model/transformer/rope_scaling.s
   - 检查清单:
     ☐ YaRN 缩放因子计算 (公式是否正确)
     ☐ NTK-by-Parts 的分段逻辑
     ☐ LongRoPE 的模式混合
     ☐ Forward/backward pass 完整性

2. 理论对标 (0.5天)
   - YaRN 论文核心:
     ☐ alpha = 1 + (base - 1) * (L_new/L_orig)^a
     ☐ beta_scale 应该线性缩放
   - 检查实现是否与论文一致

3. 精度测试 (1day)
   - 测试条件:
     ☐ 基础长度: 2048 (标准)
     ☐ 扩展长度: 4096, 8192, 16384, 65536, 131072
     ☐ 批大小: 8
     ☐ 模型: 7B 参数
   
   - 度量指标:
     ☐ Perplexity (应该缓慢增长, 而非陡增)
     ☐ Attention pattern (长距离关联是否正常)
     ☐ 精度衰减 (vs 标准长度的差异)
   
   - 预期结果:
     ```
     Seq Length | Perplexity | Degradation
     2048       | 15.3       | 0% (baseline)
     4096       | 15.8       | +3.3%
     8192       | 16.2       | +5.9%
     16384      | 17.1       | +11.8%
     65536      | 21.5       | +40.5% ⚠️ (可接受上限)
     131072     | 29.8       | +94.8% ❌ (需要改进)
     ```

4. 缺陷与改进 (0.5day)
   - 如果衰减超预期 (>50% at 64K):
     ☐ 检查插值是否平滑
     ☐ 考虑混合 LongRoPE
     ☐ 评估成本-质量权衡
```

#### 验收标准
```
✅ RoPE 实现审视完成
✅ 精度测试报告 (至少测试到 65536 tokens)
✅ 长序列性能指标 (Perplexity@64K 可接受)
✅ 改进建议 (如需要)
```

#### 相关文件
- 实现: `model/transformer/rope_scaling.s` (352 行)
- 测试数据: 长序列评估集 (可用 WikiText 或 PG19)
- 参考: YaRN 论文, LongRoPE (Meta), NTK-by-Parts (Eleuther)

---

### 🔴 行动4: 启动 Medusa 头训练框架
**估时**: 3-4 天 | **优先级**: P0 | **负责**: 推理优化负责人  
**目标**: 为投机解码准备快速验证框架

#### 任务细节
```
1. 框架设计 (1天)
   - 核心概念: Medusa 是 base model 上的轻量级 heads
   - 架构:
     ```
     [Base Model Output (hidden_dim)]
                    ↓
         ┌──────────┴──────────┐
         ↓                      ↓
     [Head-1]              [Head-K]
     (1 layer)              (1 layer)
         ↓                      ↓
    [vocab]                 [vocab]
     (概率分布 1)            (概率分布 K)
     ```
   
   - 关键参数:
     ☐ num_heads: 3-5 个 (平衡成本vs精度)
     ☐ hidden_dim: 与 base model 相同
     ☐ inference_depth: 1-3 (预测未来几个token)

2. 实现编码 (1.5天)
   - 文件: serving/speculative_decoding.s (已有336行框架)
   - 修改点:
     ☐ 添加 MedusaHeads struct (K个头的定义)
     ☐ 实现 medusa_forward (快速预测)
     ☐ 实现 medusa_verify (验证预测token)
     ☐ 修改采样逻辑 (接受/拒绝采样)
   
   - 代码框架:
     ```s
     struct MedusaHeads {
         heads: []*MedusaHead  // K个辅助头
         num_heads: int
         inference_depth: int
         base_model: *GPTModel
     }
     
     struct MedusaHead {
         linear: *Tensor  // (hidden_dim, vocab_size)
         params: *AdamW
     }
     
     func medusa_forward(heads, hidden_states) [][]int {
         // 返回 K 个快速预测的 token 序列
         predictions := make([][]int, len(heads))
         for i := 0; i < len(heads); i++ {
             logits := heads[i].linear(hidden_states)
             predictions[i] = sample_top_k(logits, k=5)
         }
         return predictions
     }
     
     func speculative_decode_with_medusa(base, medusa, prompt) {
         // 1. Base model 生成候选
         candidates := medusa_forward(medusa, last_hidden)
         
         // 2. 并行验证
         for each candidate_token:
             verified := base_forward_single(candidate_token)
             if P(verified) >= P(base):
                 accept_token
             else:
                 reject && sample_base
     }
     ```

3. 训练脚本 (1day)
   - 创建: scripts/train_medusa_heads.s (新增, ~200行)
   - 功能:
     ☐ 加载预训练的 base model
     ☐ 冻结 base model 权重
     ☐ 训练 Medusa heads (只有 0.5-1% 参数)
     ☐ 使用蒸馏损失: KL(P_base || P_head)
     ☐ 定期评估验证率
   
   - 伪代码:
     ```s
     func train_medusa_heads(base_model, dataset, num_epochs) {
         medusa := init_medusa_heads(base_model.hidden_dim, 5)
         optimizer := AdamW(medusa.parameters(), lr=1e-3)
         
         for epoch := 0; epoch < num_epochs; epoch++ {
             for batch := range dataset {
                 // 前向: 获取base和medusa的预测
                 base_out := base_model.forward(batch)
                 medusa_out := medusa_forward(medusa, base_out.hidden)
                 
                 // 计算蒸馏损失: KL divergence
                 loss := kl_divergence(
                     softmax(medusa_out),
                     softmax(base_out.logits)
                 )
                 
                 // 反向与优化
                 loss.backward()
                 optimizer.step()
                 
                 // 定期评估
                 if step % 100 == 0:
                     verify_rate := eval_verification_rate(
                         base, medusa, val_set, top_k=5
                     )
                     log("Step", step, "Verify Rate", verify_rate)
             }
     }
     ```

4. 验证框架 (0.5day)
   - 创建: eval/medusa_evaluation.s (新增, ~150行)
   - 度量:
     ☐ 验证率 (should be 80-95%)
     ☐ 加速比 (应该 3-5 倍)
     ☐ 预测精度 (接近 base model)
```

#### 验收标准
```
✅ MedusaHeads 架构实现完成
✅ speculative_decode 集成到 inference pipeline
✅ 训练脚本可运行 (在小数据集上)
✅ 验证框架建立 (能测量验证率与加速比)
✅ 初步实验报告 (验证率 >80% 目标)
```

#### 相关文件
- 框架: `serving/speculative_decoding.s` (已有336行)
- 训练: `training/end_to_end_training.s` (可参考)
- 参考论文: "Medusa: Simple LLM Inference Acceleration Framework"

---

## 📊 P0 行动综合进度表

```
第1周:
┌─ 周一-周二: 行动1 (Flash Attention审视) ─────────────┐
│  ├─ 0.5天: 代码审视 + 性能测试环境准备              │
│  ├─ 1.0天: 论文对标 + 精度验证                      │
│  ├─ 1.5天: 缺陷列表 + 改进建议                      │
│  └─ 📊 输出: Flash_Attention_v3_Review.md          │
├─────────────────────────────────────────────────────┤
│  周三-周四: 行动2 (MMLU集成) ──────────────────────│
│  ├─ 0.5天: 数据下载 + 格式检查                      │
│  ├─ 1.0天: 集成到 benchmark_eval.s                │
│  ├─ 1.0天: 7B模型基准线测试                        │
│  └─ 📊 输出: MMLU_Baseline_Report.md              │
└─────────────────────────────────────────────────────┘

第2周:
┌─ 周一-周二: 行动3 (RoPE长序列) ──────────────────┐
│  ├─ 1.0天: 代码审视 + 理论对标                      │
│  ├─ 1.5天: 精度测试 (到65536 tokens)             │
│  └─ 📊 输出: RoPE_Evaluation_Report.md            │
├─────────────────────────────────────────────────────┤
│  周三-周五: 行动4 (Medusa框架) ────────────────────│
│  ├─ 1.0天: 架构设计 + 代码框架                      │
│  ├─ 1.5天: 实现 MedusaHeads + speculative_decode  │
│  ├─ 1.0天: 训练脚本 + 验证框架                      │
│  └─ 📊 输出: Medusa_Implementation_Report.md      │
└─────────────────────────────────────────────────────┘

交付物汇总 (周末):
✅ Flash_Attention_v3_Review.md (详细审查 + 性能数据)
✅ MMLU_Baseline_Report.md (MMLU 准确率 + 分学科分析)
✅ RoPE_Evaluation_Report.md (长序列精度曲线)
✅ Medusa_Implementation_Report.md (框架 + 训练脚本)
✅ P0_Action_Progress_Dashboard.md (汇总进度)
```

---

## 🎯 P0 行动关键指标

### 行动1: Flash Attention v3 - 成功标准
```
☐ 论文对标: 实现与Flash-Attention论文 100% 匹配
☐ 性能目标: 相对标准注意力 1.5-2.0x 加速
☐ 内存目标: -30-40% 内存消耗
☐ 精度目标: <0.1% 的精度衰减
☐ 关键缺陷: <5个高优先级缺陷
```

### 行动2: MMLU 集成 - 成功标准
```
☐ 数据完整: 57个学科全部集成 (~14K样例)
☐ 评分准确: 与lm-evaluation-harness <1% 偏差
☐ 基线确立: 7B模型达到 60-70% 准确率
☐ 报告质量: 包含总体/分学科/分析
☐ 性能指标: 评估速度 >100 个样例/GPU小时
```

### 行动3: RoPE 长序列 - 成功标准
```
☐ 代码正确: 与论文实现一致性 100%
☐ 精度衰减: 64K token 时 <50% 衰减
☐ 测试覆盖: 至少覆盖 4 个长度 (4K/16K/64K/128K)
☐ 对标数据: 与参考实现 (如 LLaMA 2) 性能相近
```

### 行动4: Medusa 框架 - 成功标准
```
☐ 框架完整: 所有关键组件实现
☐ 可运行: 在小数据集上能成功训练
☐ 验证率: 初步实验达到 >80%
☐ 加速比: 初步实验达到 >2.0x
☐ 文档完善: 训练脚本注释 >30%
```

---

## 📋 P0 行动资源需求

### 人力配置
```
角色1: AI 系统专家 (推理优化)
  ├─ 行动1: Flash Attention 审视 (3-4天)
  ├─ 行动4: Medusa 框架设计 (1-2天)
  └─ 总计: 4-6 人天

角色2: 评估框架工程师 (数据 & 评估)
  ├─ 行动2: MMLU 集成 (2-3天)
  └─ 总计: 2-3 人天

角色3: 架构优化工程师 (模型优化)
  ├─ 行动3: RoPE 长序列验证 (2-3天)
  └─ 总计: 2-3 人天

总人力: 8-12 人天 (相当于 2-3 人 1-2 周全职)
```

### 计算资源需求
```
行动1: Flash Attention 性能测试
  ├─ GPU: 1x H100 (或 A100)
  ├─ 时间: 4-6 小时
  └─ 成本: ~$10-20

行动2: MMLU 基准线测试
  ├─ GPU: 1x H100
  ├─ 时间: 8-12 小时 (测试7B模型)
  └─ 成本: ~$30-50

行动3: RoPE 精度测试
  ├─ GPU: 1x H100
  ├─ 时间: 12-16 小时 (多个长度的测试)
  └─ 成本: ~$40-60

行动4: Medusa 训练框架
  ├─ GPU: 1x H100
  ├─ 时间: 6-8 小时 (小规模训练)
  └─ 成本: ~$20-30

总成本: ~$100-160 (可控)
```

### 工具与依赖
```
必需:
☐ Python 3.10+ (数据处理)
☐ PyTorch 2.0+ (参考实现)
☐ CUDA 12.0+ (GPU计算)
☐ 5-10 GB 磁盘空间 (数据集)

推荐:
☐ Jupyter Notebook (交互式分析)
☐ Weights & Biases (实验追踪)
☐ Git (版本控制)
```

---

## 🚀 P0 行动启动检查清单

在启动前，确保以下条件就位：

### 前置准备
- [ ] 核心团队已确认 (至少 2-3 人)
- [ ] GPU 资源已预留 (至少 1x H100)
- [ ] 项目代码库已 clone 本地
- [ ] NeurX 编译环境已搭建
- [ ] S 编译器版本 verified

### 知识准备
- [ ] 团队已阅读相关论文 (Flash-Attn, YaRN, Medusa)
- [ ] 熟悉 MMLU 评估框架
- [ ] 理解 RoPE 位置编码原理
- [ ] 了解投机解码的基本概念

### 环境准备
- [ ] GitHub Issues 模板已准备 (缺陷追踪)
- [ ] Confluence/Wiki 页面已创建 (进度报告)
- [ ] Slack 频道 #neurx-p0-actions 已创建
- [ ] 每日同步会议已排期 (15:00 UTC)

### 风险评估
- [ ] 已制定 Flash Attention 失败的备选方案
- [ ] 已制定 MMLU 集成延期的应对方案
- [ ] 已确认 GPU 不可用时的替代方案
- [ ] 已确认关键人员的 backup

---

## 📞 P0 行动支持体系

### 每日同步 (Daily Standup)
```
时间: 每日 15:00 UTC (8:00 AM PT / 5:00 PM CET)
参与: 4 个角色 + 项目经理
时间: 15 分钟
议程:
  - 昨日完成
  - 今日计划
  - 阻塞问题
```

### 周报告 (Weekly Report)
```
时间: 每周五 16:00 UTC
形式: Markdown 报告 + 短视频演示 (5 min)
内容:
  - 本周交付物
  - 性能指标
  - 风险与缺陷
  - 下周计划
```

### 里程碑评审 (Milestone Review)
```
时间: 第2周周末 (2026-07-28)
参与: 核心团队 + 决策层
议程:
  - 4 个行动的完成情况
  - 性能指标达成情况
  - 关键发现 (惊喜/问题)
  - GO/NO-GO 决策
```

---

## 💡 P0 行动成功的关键要素

### 必须具备
1. **时间承诺**: 核心人员 100% 投入 (不能兼职)
2. **GPU 资源**: 持续可用 (不能间断)
3. **技术深度**: 理解核心算法原理
4. **问题解决能力**: 面对技术难题不放弃

### 应该有
1. **文档规范**: 清晰的格式与模板
2. **团队协作**: 良好的沟通机制
3. **知识共享**: 经验教训记录
4. **工具支持**: CI/CD 自动化

### 可以有
1. **外部支持**: 论文作者咨询 (可选)
2. **基准对标**: 其他实现参考 (可选)
3. **营销宣传**: 进度分享 (可选)

---

## 📚 P0 行动参考资源

### 论文与文献
- Flash Attention v2/v3: https://github.com/Dao-AILab/flash-attention
- YaRN: https://arxiv.org/abs/2309.00071
- Medusa: https://github.com/jackcui/medusa
- MMLU: https://github.com/hendrycks/MMLU
- lm-evaluation-harness: https://github.com/EleutherAI/lm-evaluation-harness

### 实现参考
- Meta LLaMA 2: https://github.com/facebookresearch/llama
- Hugging Face Transformers: https://github.com/huggingface/transformers
- DeepSeek: https://github.com/deepseek-ai/

### 工具与平台
- Weights & Biases: https://wandb.ai/ (实验追踪)
- Paperswithcode: https://paperswithcode.com/ (基准对比)
- TensorBoard: https://www.tensorflow.org/tensorboard (可视化)

---

**准备好启动了吗?** 🚀

这 4 个行动是后续 3 阶段升级计划的基础。成功完成 P0 将确保:
1. ✅ 推理性能有确实的改进方向
2. ✅ 模型质量有量化的评估方法
3. ✅ 长序列支持有技术的可行性验证
4. ✅ 成本优化有工程的落地框架

预计在 **2026-07-28** 完成全部 P0 行动，为后续的 Sprint 1-5 铺平道路。

