#!/usr/bin/env python3
"""Generate an industrial-style JSONL corpus for GPT-style training.

The output keeps a backward-compatible `text` field while enriching each
sample with metadata needed for filtering, sampling, and auditing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import shutil
import unicodedata
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "data" / "training_data.jsonl"
DEFAULT_BACKUP = ROOT / "data" / "training_data.jsonl.gpt_backup"


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def lang_of(text: str) -> str:
    has_cn = bool(re.search(r"[\u4e00-\u9fff]", text))
    has_en = bool(re.search(r"[A-Za-z]", text))
    if has_cn and has_en:
        return "multi"
    if has_cn:
        return "zh"
    if has_en:
        return "en"
    return "unknown"


def domain_of(text: str) -> str:
    lower = text.lower()
    rules = [
        ("code", [r"```", r"\bdef\b", r"\bclass\b", r"\bfunc\b", r"\bSELECT\b", r"\bimport\b"]),
        ("math", [r"O\(", r"P\(", r"\bgradient\b", r"\bHessian\b", r"∑", r"∫", r"√", r"log\("]),
        ("dialog", [r"用户[:：]", r"助手[:：]", r"User[:：]", r"Assistant[:：]"]),
        ("qa", [r"^问题[:：]", r"^Q[:：]", r"^问[:：]"]),
        ("log", [r"\[INFO\]", r"\bstep=\d+", r"\bloss=", r"\bcheckpoint\b"]),
        ("safety", [r"安全", r"隐私", r"审计", r"权限", r"漏洞", r"攻击", r"脱敏", r"合规"]),
        ("api", [r"REST", r"HTTP", r"OpenAPI", r"endpoint", r"JSON Schema"]),
        ("database", [r"\bSQL\b", r"索引", r"事务", r"分片", r"查询计划", r"JOIN"]),
        ("distributed", [r"all-reduce", r"allreduce", r"tensor parallel", r"pipeline parallel", r"分布式", r"通信"]),
        ("ml", [r"Transformer", r"attention", r"embedding", r"tokenizer", r"loss", r"optimizer", r"训练"]),
    ]
    for domain, pats in rules:
        if any(re.search(p, text, re.I) for p in pats):
            return domain
    if len(text) > 180:
        return "longform"
    return "general"


def quality(text: str, domain: str) -> float:
    length = len(text)
    tokens = re.findall(r"[A-Za-z0-9_]+|[\u4e00-\u9fff]+", text)
    diversity = len(set(tokens)) / max(1, len(tokens))
    score = 0.25 + min(length / 220.0, 0.45) + min(diversity, 1.0) * 0.2
    if domain in {"longform", "code", "qa", "dialog", "api", "database", "distributed", "ml", "math"}:
        score += 0.08
    if len(text) < 25:
        score -= 0.25
    if re.match(r"^(Sample|样本)\s*\d+", text):
        score -= 0.15
    return round(max(0.05, min(score, 1.0)), 4)


def tokens_est(text: str) -> int:
    return max(8, int(len(text) * 0.72))


def make_record(idx: int, text: str, source: str, split: str = "train") -> dict:
    text = normalize(text)
    dom = domain_of(text)
    return {
        "id": f"gpt_{idx:07d}",
        "text": text,
        "source": source,
        "lang": lang_of(text),
        "domain": dom,
        "quality": quality(text, dom),
        "license": "unknown",
        "tokens_est": tokens_est(text),
        "hash": f"sha256:{sha256(text)}",
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "split": split,
        "type": dom,
        "category": dom,
        "length": len(text),
        "complexity": "basic" if len(text) < 80 else "intermediate" if len(text) < 160 else "advanced" if len(text) < 280 else "expert",
        "meta": {"generator": "generate_gpt_training_data.py", "version": 1},
    }


def paragraph(title: str, bullets: list[str], tail: str) -> str:
    parts = [title, ""]
    for i, bullet in enumerate(bullets, 1):
        parts.append(f"{i}. {bullet}")
    parts.append("")
    parts.append(tail)
    return "\n".join(parts)


def build_corpus() -> list[str]:
    rng = random.Random(20260701)
    records: list[str] = []

    longform_topics = [
        (
            "工业级预训练数据治理",
            [
                "统一采集网页、书籍、论文、代码和业务文档时，必须先定义来源、许可证和敏感字段策略。",
                "清洗阶段要做语言识别、去重、近重复合并、乱码修复和模板噪声压制。",
                "采样阶段要按领域和长度分桶，避免某一类内容过度主导梯度更新。",
            ],
            "真正稳定的训练集不是“越多越好”，而是“可追踪、可过滤、可恢复、可复现”。",
        ),
        (
            "分布式训练系统",
            [
                "数据并行负责扩展吞吐，张量并行负责拆分参数，流水线并行负责拆分层级。",
                "通信与计算的重叠决定了大多数大模型训练的实际效率上限。",
                "断点恢复时不仅要恢复权重，还要恢复优化器状态、数据游标和随机种子。",
            ],
            "一套合格的训练系统必须能在节点故障、网络抖动和 checkpoint 损坏时继续推进。",
        ),
        (
            "Transformer 架构",
            [
                "自注意力让每个 token 都能查看序列中其他位置的信息。",
                "多头机制把不同表示子空间并行建模，提升表达力。",
                "残差连接和层归一化共同稳定深层网络训练。",
            ],
            "Transformer 之所以成为通用基础架构，核心在于可并行、可扩展、可迁移。",
        ),
        (
            "训练稳定性",
            [
                "学习率预热可以缓解早期梯度震荡。",
                "梯度裁剪能抑制偶发的梯度爆炸。",
                "混合精度训练需要动态 loss scale 来避免数值下溢。",
            ],
            "当损失曲线出现尖峰或长时间停滞时，优先排查数据、优化器和通信链路。",
        ),
        (
            "推理服务",
            [
                "高吞吐服务通常要做 KV cache、批处理聚合和并发调度。",
                "低延迟场景更依赖编译优化、量化和内存布局。",
                "生产推理需要监控 p50/p95 延迟、错误率和显存占用。",
            ],
            "一个好的推理系统不仅要回答得对，还要在峰值流量下保持稳定。",
        ),
    ]

    for i in range(600):
        title, bullets, tail = rng.choice(longform_topics)
        varied = [b.replace("训练", rng.choice(["训练", "预训练", "微调"])) for b in bullets]
        text = paragraph(
            f"## {title}\n\n{rng.choice(['摘要', '背景', '说明'])}：版本 {i + 1}",
            varied,
            f"{tail}（案例编号 {i + 1}）",
        )
        records.append(text)

    code_samples = [
        """Python 示例：实现一个最小训练循环。
```python
for step, batch in enumerate(loader):
    loss = model(batch)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
    optimizer.step()
    optimizer.zero_grad(set_to_none=True)
```""",
        """SQL 示例：分析最近 7 天的请求延迟。
```sql
SELECT service, percentile_cont(0.95) WITHIN GROUP (ORDER BY latency_ms)
FROM request_log
WHERE ts >= now() - interval '7 day'
GROUP BY service;
```""",
        """Bash 示例：启动训练并记录日志。
```bash
export NEURX_TOTAL_STEPS=1000
bash script/run_gpt_large_pretrain.sh 2>&1 | tee artifacts/logs/train.log
```""",
        """Go 示例：把错误封装成结构化结果。
```go
type Result struct { Ok bool; Message string }
func Wrap(err error) Result {
    if err != nil { return Result{Ok:false, Message: err.Error()} }
    return Result{Ok:true, Message:"ok"}
}
```""",
    ]
    for i in range(500):
        sample = rng.choice(code_samples)
        records.append(sample.replace("示例", f"示例 {i + 1}"))

    qa_topics = [
        ("如何降低训练不稳定性？", "建议从学习率、warmup、梯度裁剪、数据清洗和混合精度溢出五个方向同时排查。"),
        ("如何设计 checkpoint？", "应保存模型参数、优化器状态、调度器状态、数据位置和随机数状态。"),
        ("为什么要做分层采样？", "因为不同领域的样本密度和长度差异很大，分层采样能让模型更均衡地学习。"),
        ("什么时候该做量化？", "当模型已经具备可接受质量，而目标是进一步降低延迟、内存和成本时。"),
        ("如何排查 OOM？", "先看 batch size、序列长度、KV cache、activation checkpointing 和并行策略。"),
    ]
    for i in range(700):
        q, a = rng.choice(qa_topics)
        text = f"问题 {i + 1}：{q}\n回答：{a}\n补充：实际生产系统还要结合日志、指标和回滚策略一起验证。"
        records.append(text)

    dialog_topics = [
        ("用户", "我们要把一个语言模型部署到生产环境，第一步应该做什么？"),
        ("助手", "先确认数据、评估、checkpoint 和回滚链路能闭环，再谈性能优化。"),
        ("用户", "如果模型在长上下文下变慢怎么办？"),
        ("助手", "通常要检查注意力缓存、批处理策略和 token 预算。"),
    ]
    for i in range(500):
        text = "\n".join(
            [
                f"对话 {i + 1}：",
                f"{dialog_topics[0][0]}：{dialog_topics[0][1]}",
                f"{dialog_topics[1][0]}：{dialog_topics[1][1]}",
                f"{dialog_topics[2][0]}：{dialog_topics[2][1]}",
                f"{dialog_topics[3][0]}：{dialog_topics[3][1]}",
            ]
        )
        records.append(text)

    math_topics = [
        "证明：若函数在闭区间上连续且在开区间内可导，则其在区间内存在极值点。",
        "概率论：当样本独立同分布时，样本均值会随样本数增大而收敛到真实均值。",
        "线性代数：矩阵可逆的充分必要条件是行列式不为零。",
        "优化：当目标函数是凸函数时，局部最优解也是全局最优解。",
        "统计：交叉熵损失与最大似然估计之间有直接关系。",
    ]
    for i in range(700):
        topic = rng.choice(math_topics)
        text = f"数学说明 {i + 1}：{topic}\n进一步解释：把问题拆成定义、条件、结论和边界情况，更容易验证推导是否正确。"
        records.append(text)

    api_docs = [
        "API 设计：REST 接口应该使用资源名词、稳定版本号和一致的错误返回格式。",
        "OpenAPI 文档需要列出请求体、响应体、状态码、鉴权方式和示例调用。",
        "高并发接口要关注幂等性、限流、超时和重试策略。",
        "分页接口应显式说明 cursor 或 offset 的语义，避免客户端误用。",
    ]
    for i in range(500):
        body = [
            f"API 设计案例 {i + 1}：{rng.choice(api_docs)}",
            "建议：在生产里把参数校验、审计日志和监控指标都写进文档。",
            "示例：错误返回应包含 code、message、trace_id，方便定位问题。",
        ]
        records.append("\n".join(body))

    safety_docs = [
        "安全说明：训练数据中不应包含私钥、口令、身份证号或银行卡号。",
        "红队测试要覆盖越狱提示、后缀注入、提示词混淆和数据外泄路径。",
        "生产系统需要对高风险输出进行拒答、改写或人工复核。",
        "隐私治理必须包括脱敏、访问控制、保留期限和审计日志。",
    ]
    for i in range(400):
        text = "安全与合规：\n" + "\n".join(f"- {rng.choice(safety_docs)}" for _ in range(3)) + f"\n案例编号：{i + 1}\n结论：安全性是默认要求，不是可选项。"
        records.append(text)

    multilingual = [
        "This dataset mixes English and 中文 so that the tokenizer sees cross-lingual transitions.",
        "模型需要从中英混合文本里学习代码、术语、数字和自然语言的边界。",
        "Translate the following requirement into a concise engineering note: 支持分片流式读取和 epoch 级采样。",
        "请将以下句子改写成更正式的产品需求：the system must support resumable checkpoints.",
    ]
    for i in range(800):
        records.append(
            f"翻译样例 {i + 1}：{rng.choice(multilingual)}\n"
            f"{rng.choice(multilingual)}\n"
            f"{rng.choice(multilingual)}"
        )

    logs = [
        "[INFO] step=10240 loss=2.9341 lr=0.00032 tokens_per_sec=4812 status=healthy",
        "[WARN] gradient_norm=18.4 exceeded threshold; applying clip and continuing",
        "[DEBUG] loading shard 04/12 from training_data_shards/training_data-00004.jsonl.gz",
        "[INFO] checkpoint saved successfully at step=128000",
    ]
    for i in range(400):
        records.append(f"[INFO] sample={i + 1} " + rng.choice(logs).replace("[INFO] ", ""))

    essays = [
        "从系统角度看，工业级 LLM 的核心不是单一模型，而是数据、训练、评估、部署和治理的完整闭环。",
        "一个可持续演进的训练平台需要把实验可复现性、资源调度和失败恢复都当成一等公民。",
        "模型能力往往不是靠某一条技巧决定，而是靠高质量数据和稳定工程共同塑造。",
    ]
    for i in range(400):
        base = rng.choice(essays)
        text = (
            f"{base}（版本 {i + 1}） "
            f"在实践中，还需要把监控、告警、审计和回滚纳入默认流程，"
            f"这样才能在长周期训练中保持稳定推进。"
        )
        records.append(text)

    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--backup", type=Path, default=DEFAULT_BACKUP)
    parser.add_argument("--count", type=int, default=0, help="optional cap on number of generated records")
    args = parser.parse_args()

    corpus = build_corpus()
    if args.count and args.count > 0:
        corpus = corpus[: args.count]

    if args.output.exists() and not args.backup.exists():
        shutil.copy2(args.output, args.backup)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    seen = set()
    written = 0
    with args.output.open("w", encoding="utf-8") as f:
        for idx, text in enumerate(corpus):
            text = normalize(text)
            h = sha256(text)
            if h in seen:
                continue
            seen.add(h)
            record = make_record(idx, text, source="curated_gpt_corpus_v2")
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
            written += 1

    print(f"Written {written} records to {args.output}")
    print(f"Backup: {args.backup if args.backup.exists() else 'none'}")


if __name__ == "__main__":
    main()
