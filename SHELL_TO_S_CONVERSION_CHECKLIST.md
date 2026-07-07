# Shell 脚本到 S 语言转换清单

**总计：112 个 .sh 文件待转换**  
**已完成：数据处理管道（Phase 1）**  
**待转换：其他 112 个脚本**

---

## 🔴 优先级 1：核心功能（必须转换）

### 数据处理（5 个）
- [ ] `clean_data.sh` — 数据清洗主脚本
- [ ] `generate_shards.sh` — 数据分片主脚本
- [ ] `generate_training_data.sh` — 生成训练数据
- [ ] `split_data.sh` — 数据分割
- [ ] `split_industrial_dataset.sh` — 工业数据集分割

### 训练相关（6 个）
- [ ] `run_training.sh` — 通用训练启动
- [ ] `run_large_pretrain.sh` — 大模型预训练（**最重要**）
- [ ] `run_llm_training.sh` — LLM 训练
- [ ] `run_llm_training_with_compiler.sh` — 编译器训练
- [ ] `train_1t_moe.sh` — 1T MoE 训练
- [ ] `monitor_training.sh` — 训练监控

### 推理相关（5 个）
- [ ] `run_inference.sh` — 通用推理
- [ ] `run_inference_llm.sh` — LLM 推理（**重要**）
- [ ] `run_interactive_inference.sh` — 交互推理
- [ ] `run_infer_local.sh` — 本地推理
- [ ] `chat.sh` — 交互聊天

**小计：16 个核心脚本**

---

## 🟠 优先级 2：重要工具（应该转换）

### 构建和编译（4 个）
- [ ] `build_ml_complete.sh` — 完整 ML 构建
- [ ] `compile_all_components.sh` — 编译所有组件
- [ ] `compile_training_integration.sh` — 训练集成编译
- [ ] `build_smart_inference.sh` — 智能推理构建

### 验证和测试（5 个）
- [ ] `verify_setup.sh` — 验证设置
- [ ] `verify_framework.sh` — 验证框架
- [ ] `verify_inference_pipeline.sh` — 验证推理管道
- [ ] `verify_training_pipeline.sh` — 验证训练管道
- [ ] `run_integration_tests.sh` — 集成测试

### 演示和快速开始（3 个）
- [ ] `quick_start.sh` — 快速开始
- [ ] `quickstart.sh` — 快速开始（备用）
- [ ] `quick_test.sh` — 快速测试

**小计：12 个重要工具**

---

## 🟡 优先级 3：辅助功能（可以转换）

### 启动脚本（8 个）
- [ ] `start_train.sh` — 启动训练
- [ ] `LAUNCH_7B_TRAINING.sh` — 启动 7B 训练
- [ ] `LAUNCH_70B_TRAINING.sh` — 启动 70B 训练
- [ ] `LAUNCH_1T_TRAINING.sh` — 启动 1T 训练
- [ ] `launch_8card_run_train_ir.sh` — 8卡训练启动
- [ ] `launch_70b_now.sh` — 立即启动 70B
- [ ] `launch_smart_inference.sh` — 启动智能推理
- [ ] `cluster_launch.sh` — 集群启动

### 演示脚本（5 个）
- [ ] `demo_training.sh` — 训练演示
- [ ] `demo_complete_pipeline.sh` — 完整管道演示
- [ ] `demo_chat.sh` — 聊天演示
- [ ] `demo_smart_inference.sh` — 智能推理演示
- [ ] `training_demo.sh` — 训练演示（备用）

### 测试脚本（7 个）
- [ ] `test_build.sh` — 构建测试
- [ ] `test_optimizer_compile.sh` — 优化器编译测试
- [ ] `test_tokenizer_compile.sh` — 分词器编译测试
- [ ] `test_attention_compile.sh` — 注意力编译测试
- [ ] `test_smart_inference.sh` — 智能推理测试
- [ ] `test_file_creation.sh` — 文件创建测试
- [ ] `test-editor-sync.sh` — 编辑器同步测试

### 管道和工作流（6 个）
- [ ] `complete_training_cycle.sh` — 完整训练周期
- [ ] `run_complete_pipeline.sh` — 完整管道
- [ ] `neurx_complete_pipeline.sh` — NeurX 完整管道
- [ ] `run_train_and_infer.sh` — 训练和推理
- [ ] `run_end_to_end_verification.sh` — 端到端验证
- [ ] `run_training_pipeline.sh` — 训练管道

**小计：26 个辅助功能**

---

## 💜 优先级 4：特殊功能（可选转换）

### 数据操作（5 个）
- [ ] `load_shards.sh` — 加载分片
- [ ] `print_training_data_info.sh` — 打印训练数据信息
- [ ] `quick_data_acquisition.sh` — 快速数据获取
- [ ] `batch_standardize.sh` — 批量标准化
- [ ] `convert_data.sh` — 数据转换

### 状态和报告（7 个）
- [ ] `PROJECT_STATUS.sh` — 项目状态
- [ ] `FINAL_STATUS_REPORT.sh` — 最终状态报告
- [ ] `PHASE7_COMPLETE_STATUS.sh` — Phase 7 状态
- [ ] `PHASE8_COMPLETION_SUMMARY.sh` — Phase 8 总结
- [ ] `PHASE9_INDUSTRIAL_SYSTEMS_COMPLETE.sh` — Phase 9 完成
- [ ] `PHASE8_QUICK_START.sh` — Phase 8 快速开始
- [ ] `MIGRATION_COMPLETE.sh` — 迁移完成

### 迁移和转换（4 个）
- [ ] `migrate_infer_to_serving.sh` — 推理服务迁移
- [ ] `convert_to_industrial_format.sh` — 工业格式转换
- [ ] `git_push_simple.sh` — Git 推送
- [ ] `push_phase8.sh` — 推送 Phase 8
- [ ] `push_advanced_features.sh` — 推送高级功能

### 诊断和配置（6 个）
- [ ] `diagnose_autoscroll.sh` — 自动滚动诊断
- [ ] `diagnose_file_creation.sh` — 文件创建诊断
- [ ] `diagnose_tool_registration.sh` — 工具注册诊断
- [ ] `minimal_diagnostic.sh` — 最小诊断
- [ ] `setup_production_deployment.sh` — 生产部署设置
- [ ] `install_auto_push_service.sh` — 自动推送服务安装

**小计：22 个特殊功能**

---

## ⚪ 优先级 5：外部和其他（低优先级）

### 构建系统（5 个）
- [ ] `build-linux.sh` — Linux 构建
- [ ] `build-macos.sh` — macOS 构建
- [ ] `setup-llm.sh` — LLM 设置
- [ ] `setup-tool-system.sh` — 工具系统设置
- [ ] `link_s_ir_module.sh` — S IR 模块链接

### 其他（9 个）
- [ ] `file-manifest.sh` — 文件清单
- [ ] `cleanup_make_commands.sh` — Makefile 清理
- [ ] `make_launcher.sh` — Makefile 启动器
- [ ] `integration.sh` — 集成
- [ ] `gen_industrial_data.sh` — 生成工业数据
- [ ] `gen_neurx_training_data.sh` — 生成 NeurX 训练数据
- [ ] `generate_industrial_data.sh` — 生成工业数据（备用）
- [ ] `BPE_TOKENIZER_STATUS.sh` — BPE 分词器状态
- [ ] `QUICKREF_ML_IMPLEMENTATION.sh` — ML 实现快速参考

### 训练场景（3 个）
- [ ] `training_scenarios.sh` — 训练场景
- [ ] `run_small_model_training.sh` — 小模型训练
- [ ] `train_foundation_model.sh` — 基础模型训练

### 导出和验证（3 个）
- [ ] `run_full_inference.sh` — 完整推理
- [ ] `run_train_compiled.sh` — 编译训练
- [ ] `validate_enterprise_features.sh` — 企业功能验证

### 特殊集成（3 个）
- [ ] `submit_training_job.sh` — 提交训练任务
- [ ] `run_with_logs.sh` — 带日志运行
- [ ] `run_1t_moe.sh` — 1T MoE 运行

**小计：23 个低优先级**

---

## 📊 转换统计

| 优先级 | 数量 | 状态 | 预计工作量 |
|--------|------|------|-----------|
| 🔴 P1: 核心 | 16 | ⏳ | 2-3 周 |
| 🟠 P2: 重要 | 12 | ⏳ | 1-2 周 |
| 🟡 P3: 辅助 | 26 | ⏳ | 1-2 周 |
| 💜 P4: 特殊 | 22 | ⏳ | 1 周 |
| ⚪ P5: 其他 | 23 | ⏳ | 1-2 周 |
| ✅ 已完成 | 3 | ✅ | 已完成 |
| **总计** | **112** | **⏳** | **6-10 周** |

---

## 🎯 推荐转换顺序

### Phase 1：数据处理（已完成）✅
- ✅ data_pipeline.s
- ✅ training_runner.s
- ✅ inference_server.s

### Phase 2：核心训练（16 个）
1. `run_large_pretrain.sh` — 最关键的训练脚本
2. `run_inference_llm.sh` — 核心推理脚本
3. `clean_data.sh` + `generate_shards.sh` — 数据处理辅助
4. 其他 12 个核心脚本

### Phase 3：重要工具（12 个）
- 构建、验证、演示脚本

### Phase 4：其他（68 个）
- 辅助功能、特殊功能、低优先级脚本

---

## 💡 建议

1. **专注 P1（16 个）** — 这些是真正的生产脚本
2. **然后 P2（12 个）** — 这些支持生产环境
3. **可选 P3-P5** — 这些大多是演示和诊断

如果只能选择一个，建议先转换：
- **`run_large_pretrain.sh`** — 最重要的训练脚本

---

**版本：** 1.0  
**更新：** 2026-07-07
