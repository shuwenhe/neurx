#!/usr/bin/env python3
"""Enrich NeurX training data with more industrial-style samples.

This script appends diverse synthetic records to the JSONL corpus in a
deterministic way so the dataset can be regenerated consistently.
"""

from __future__ import annotations

import json
import os
import random
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "data" / "training_data.jsonl"
BACKUP_FILE = ROOT / "data" / "training_data.jsonl.bak"


def make_record(text: str) -> str:
    return json.dumps({"text": text}, ensure_ascii=False)


def add(records: list[str], text: str) -> None:
    text = " ".join(text.split())
    if text and len(text) > 8:
        records.append(make_record(text))


def generate() -> list[str]:
    rng = random.Random(42)
    records: list[str] = []

    domains = [
        "数据工程",
        "模型训练",
        "分布式系统",
        "推理部署",
        "可观测性",
        "安全合规",
        "搜索排序",
        "推荐系统",
        "多模态",
        "代码生成",
        "工具调用",
        "Agent 编排",
    ]
    roles = [
        "研究员",
        "平台工程师",
        "后端开发",
        "MLOps 工程师",
        "产品经理",
        "安全审计员",
        "数据标注员",
        "架构师",
    ]
    metrics = ["p50 延迟", "p95 延迟", "吞吐量", "困惑度", "准确率", "召回率", "F1", "OOM 率"]
    components = ["tokenizer", "dataloader", "optimizer", "scheduler", "checkpoint", "all_reduce", "pipeline stage", "KV cache"]

    # Long-form technical prose
    for i in range(180):
        domain = rng.choice(domains)
        role = rng.choice(roles)
        metric = rng.choice(metrics)
        comp = rng.choice(components)
        add(
            records,
            f"在{domain}场景中，{role}需要同时关注数据质量、训练稳定性和成本控制。"
            f"当{comp}成为瓶颈时，应通过分片读取、批次重排、缓存预热和异步预取来提升整体效率，"
            f"并用{metric}作为核心观测指标持续回归验证。",
        )

    # QA / instruction style
    instruction_topics = [
        ("如何降低训练不稳定性", "建议从学习率、梯度裁剪、混合精度溢出检查、warmup 和数据清洗五个维度同时排查。"),
        ("如何设计 checkpoint", "建议保存模型参数、优化器状态、学习率调度器、随机种子、数据游标和训练步数。"),
        ("如何做分布式训练", "优先明确数据并行、张量并行与流水线并行的边界，再补通信拓扑与容错机制。"),
        ("如何评估模型", "建议同时看困惑度、下游任务准确率、长上下文稳定性、延迟和资源占用。"),
        ("如何构建数据管线", "建议分为采集、清洗、去重、分片、shuffle、采样、校验和审计几层。"),
    ]
    for i in range(240):
        q, a = rng.choice(instruction_topics)
        add(records, f"问题：{q}？回答：{a} 另外，实际工业系统里还需要监控异常样本、错误日志和回滚流程。")

    # Dialog style
    dialogs = [
        ("用户", "我们要把一个语言模型从 demo 升级成生产系统，第一步应该做什么？"),
        ("助手", "先把数据、评估和 checkpoint 三条链路打通，再考虑更复杂的并行与优化。"),
        ("用户", "如果训练中断了怎么办？"),
        ("助手", "要能从断点恢复优化器状态和数据位置，同时验证恢复后的 loss 曲线是否连续。"),
    ]
    for i in range(140):
        topic = rng.choice(domains)
        add(
            records,
            f"对话：用户问“{topic}系统如何走向生产？”助手答“需要把监控、审计、告警、容错和回滚纳入设计。”"
            f"用户追问“为什么？”助手答“因为工业系统追求的是可持续运行，而不是一次性跑通。”",
        )

    # Code / pseudo-code
    code_snippets = [
        "for step in range(max_steps): loss = forward(batch); grads = backward(loss); clip(grads); optimizer.step()",
        "if shard_offset >= shard_size: shard_offset = 0; epoch += 1; shuffle_index = next_shuffle(epoch)",
        "state = { 'model': model_state, 'optim': optim_state, 'step': step, 'rng': rng_state }",
        "def all_reduce(grads): return sum(grads) / world_size",
        "log.info('checkpoint saved', extra={'step': step, 'path': ckpt_path})",
    ]
    for i in range(220):
        snippet = rng.choice(code_snippets)
        add(
            records,
            f"代码片段示例：{snippet}。说明：这类伪代码用于表达训练循环、分布式同步和恢复逻辑，"
            f"不依赖特定框架，但应保留明确变量名、状态流转和错误处理。",
        )

    # Math / reasoning
    for i in range(160):
        a = rng.randint(2, 97)
        b = rng.randint(2, 97)
        c = rng.randint(2, 20)
        add(
            records,
            f"数学样例：若 batch_size={a}，gradient_accumulation_steps={b}，则有效批大小约为 {a*b}。"
            f"若再将学习率缩放到原来的 1/{c}，需要观察损失曲线是否仍保持单调下降趋势。"
            f"结论应结合 warmup、权重衰减和数据噪声共同分析。",
        )

    # Multilingual / translation
    translations = [
        ("请将以下句子翻译成英文：工业训练系统必须具备断点续训能力。", "Industrial training systems must support resumable checkpoint recovery."),
        ("Please summarize the following requirement in Chinese: support sharded streaming with epoch-level sampling.", "支持分片流式读取与按 epoch 级采样。"),
        ("将‘模型稳定性优先于短期速度优化’改写为更正式的产品需求语言。", "在实现阶段应优先保障训练稳定性，再逐步引入性能优化。"),
        ("Translate to English: 需要监控数据漂移、梯度爆炸和 checkpoint 损坏。", "We need to monitor data drift, gradient explosion, and checkpoint corruption."),
    ]
    for i in range(120):
        zh, en = rng.choice(translations)
        add(records, f"{zh} {en} 同时保留原句语义和技术术语。")

    # Logs / ops
    for i in range(180):
        step = rng.randint(1, 900000)
        loss = round(rng.uniform(0.1, 9.9), 4)
        lr = round(rng.uniform(1e-6, 3e-4), 8)
        add(
            records,
            f"[INFO] step={step} loss={loss} lr={lr} tokens_per_sec={rng.randint(1200, 9200)} "
            f"gpu_mem={rng.randint(8, 80)}GB status=healthy message=training_iteration_completed",
        )

    # Structured data / JSON-like text
    for i in range(120):
        add(
            records,
            json.dumps(
                {
                    "task": rng.choice(["pretrain", "finetune", "eval", "deploy"]),
                    "stage": rng.choice(["data", "model", "optimizer", "distributed", "monitoring"]),
                    "status": rng.choice(["ok", "warning", "retry", "recover"]),
                    "notes": "dataset shard is streaming and checkpoint state is persisted",
                },
                ensure_ascii=False,
            ),
        )

    # Longer passage samples
    passage_starts = [
        "在真实的大模型训练项目中，数据并不是一次性全部读入内存，而是通过分片、索引和预取策略持续供给训练进程。",
        "一个可恢复的工业训练系统通常不仅保存模型权重，还要保存优化器动量、随机数状态、样本游标以及调度器进度。",
        "当模型规模增大到数十亿参数时，单卡训练会迅速碰到显存、带宽和收敛速度的三重约束。",
        "为了让训练任务能够长期稳定运行，系统需要从一开始就把监控、告警、审计和回滚设计进去。",
    ]
    passage_mids = [
        "这意味着每一层都要能被单独观测，并且在出现异常时可以定位到具体 shard、batch 或 rank。",
        "如果通信开销过高，可以优先检查 all-reduce 的频率、梯度累积步数和流水线气泡。",
        "如果数据质量不稳定，模型往往会先表现为 loss 抖动、验证集退化和生成质量下降。",
        "如果 checkpoint 不能恢复，训练一旦中断就会造成大量算力浪费，并且难以做实验复现。",
    ]
    passage_ends = [
        "因此，工业级训练系统需要在正确性、鲁棒性、吞吐量和可运维性之间做持续平衡。",
        "这也是为什么真正的预训练平台通常比单纯的模型代码复杂一个数量级。",
        "最终目标不是让 demo 跑通，而是让任务在数周训练周期内保持稳定前进。",
        "只有把这些基础设施补齐，模型能力提升才会真正可持续。",
    ]
    for i in range(180):
        add(records, f"{rng.choice(passage_starts)} {rng.choice(passage_mids)} {rng.choice(passage_ends)}")

    # Safety / policy / responsible AI
    safety = [
        "当系统检测到敏感信息时，应优先执行脱敏、拒答或人工复核流程。",
        "训练数据中不应包含私钥、口令、身份证号、银行卡号或未授权个人信息。",
        "模型输出需要经过内容安全、事实性和版权风险三类检查。",
        "对于高风险场景，建议把权限控制、审计日志和速率限制作为默认配置。",
    ]
    for i in range(100):
        add(records, f"安全说明：{rng.choice(safety)} 这是面向生产系统的基础要求，而不是可选项。")

    # Misc diverse samples
    topics = [
        "向量数据库",
        "RAG 检索增强生成",
        "函数调用",
        "提示词模板",
        "长上下文窗口",
        "批处理推理",
        "多租户隔离",
        "灰度发布",
        "A/B 测试",
        "模型蒸馏",
    ]
    for i in range(220):
        topic = rng.choice(topics)
        add(
            records,
            f"{topic}样例：在生产环境中，{topic}不仅关注性能，还要关注可观测性、可回滚性和权限边界。"
            f"如果需要进一步提升效果，应通过离线评估、在线实验和误差分析迭代优化。",
        )

    # Extra mixed examples to improve token variety
    for i in range(320):
        n1 = rng.randint(1, 9999)
        n2 = rng.randint(1, 9999)
        add(
            records,
            f"混合样本 {i + 1}：系统编号={n1}，批次={n2}，包含中文、English、12345 和 punctuation!?"
            f" 这类样本用于提升 tokenizer 对数字、符号和跨语言文本的鲁棒性。",
        )

    return records


def main() -> None:
    if not DATA_FILE.exists():
        raise FileNotFoundError(DATA_FILE)

    original = DATA_FILE.read_text(encoding="utf-8").splitlines()
    backup_needed = not BACKUP_FILE.exists()
    if backup_needed:
        BACKUP_FILE.write_text("\n".join(original) + "\n", encoding="utf-8")

    augmented = original + generate()
    DATA_FILE.write_text("\n".join(augmented) + "\n", encoding="utf-8")
    print(f"Updated {DATA_FILE}")
    print(f"Original records: {len(original)}")
    print(f"New records added: {len(augmented) - len(original)}")
    print(f"Total records: {len(augmented)}")
    if backup_needed:
        print(f"Backup written to {BACKUP_FILE}")


if __name__ == "__main__":
    main()
