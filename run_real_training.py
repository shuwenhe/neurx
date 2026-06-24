#!/usr/bin/env python3
"""
Train a minimal next-token language model on the real corpus bundled with NeurX.

This is intentionally lightweight and dependency-free so we can execute a real
training run inside the current repository without requiring external packages.
The model is a word-level bigram softmax language model:

    P(next_token | current_token)

It is much smaller than a GPT, but it performs actual optimization on the
project's corpus and produces reproducible artifacts.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import re
import time
from collections import Counter
from pathlib import Path


TOKEN_PATTERN = re.compile(r"\w+|[^\w\s]", re.UNICODE)
UNK_TOKEN = "<unk>"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a real corpus LM for NeurX.")
    parser.add_argument(
        "--corpus",
        default="/Users/feifei/train/neurx/data/corpus/train_corpus.txt",
        help="Path to training corpus text file.",
    )
    parser.add_argument(
        "--save-dir",
        default="/Users/feifei/train/neurx/artifacts/real_training",
        help="Directory for summaries and checkpoints.",
    )
    parser.add_argument("--steps", type=int, default=300, help="Training steps.")
    parser.add_argument("--batch-size", type=int, default=64, help="Batch size.")
    parser.add_argument("--lr", type=float, default=0.35, help="Peak learning rate.")
    parser.add_argument("--min-lr", type=float, default=0.05, help="Minimum learning rate.")
    parser.add_argument("--warmup-steps", type=int, default=30, help="Warmup steps.")
    parser.add_argument("--weight-decay", type=float, default=0.0001, help="Weight decay.")
    parser.add_argument("--vocab-size", type=int, default=512, help="Vocabulary cap including <unk>.")
    parser.add_argument("--eval-interval", type=int, default=50, help="Eval cadence.")
    parser.add_argument("--save-every", type=int, default=50, help="Checkpoint cadence.")
    parser.add_argument("--resume", action="store_true", help="Resume from latest checkpoint if available.")
    parser.add_argument("--quick", action="store_true", help="Quick test mode for fast verification.")
    parser.add_argument("--seed", type=int, default=42, help="Random seed.")
    args = parser.parse_args()

    if args.quick:
        args.steps = min(args.steps, 20)
        args.batch_size = min(args.batch_size, 32)
        args.vocab_size = min(args.vocab_size, 256)
        args.eval_interval = min(args.eval_interval, 5)
        args.save_every = min(args.save_every, 10)
        args.warmup_steps = min(args.warmup_steps, 5)

    return args


def tokenize(text: str) -> list[str]:
    return TOKEN_PATTERN.findall(text)


def build_vocab(tokens: list[str], vocab_limit: int) -> tuple[list[str], dict[str, int]]:
    counter = Counter(tokens)
    most_common = [token for token, _ in counter.most_common(max(1, vocab_limit - 1))]
    vocab = [UNK_TOKEN] + most_common
    stoi = {token: idx for idx, token in enumerate(vocab)}
    return vocab, stoi


def encode(tokens: list[str], stoi: dict[str, int]) -> list[int]:
    unk_id = stoi[UNK_TOKEN]
    return [stoi.get(token, unk_id) for token in tokens]


def softmax(logits: list[float]) -> list[float]:
    max_logit = max(logits)
    exp_values = [math.exp(value - max_logit) for value in logits]
    total = sum(exp_values)
    return [value / total for value in exp_values]


class AdamWOptimizer:
    def __init__(
        self,
        vocab_size: int,
        lr: float,
        weight_decay: float,
        beta1: float = 0.9,
        beta2: float = 0.999,
        eps: float = 1e-8,
    ) -> None:
        self.vocab_size = vocab_size
        self.lr = lr
        self.weight_decay = weight_decay
        self.beta1 = beta1
        self.beta2 = beta2
        self.eps = eps
        self.step = 0
        self.weight_m = [[0.0 for _ in range(vocab_size)] for _ in range(vocab_size)]
        self.weight_v = [[0.0 for _ in range(vocab_size)] for _ in range(vocab_size)]
        self.bias_m = [0.0 for _ in range(vocab_size)]
        self.bias_v = [0.0 for _ in range(vocab_size)]

    def state_dict(self) -> dict[str, object]:
        return {
            "vocab_size": self.vocab_size,
            "lr": self.lr,
            "weight_decay": self.weight_decay,
            "beta1": self.beta1,
            "beta2": self.beta2,
            "eps": self.eps,
            "step": self.step,
            "weight_m": self.weight_m,
            "weight_v": self.weight_v,
            "bias_m": self.bias_m,
            "bias_v": self.bias_v,
        }

    @classmethod
    def from_state_dict(cls, state: dict[str, object]) -> "AdamWOptimizer":
        optimizer = cls(
            int(state["vocab_size"]),
            float(state["lr"]),
            float(state["weight_decay"]),
            float(state["beta1"]),
            float(state["beta2"]),
            float(state["eps"]),
        )
        optimizer.step = int(state["step"])
        optimizer.weight_m = state["weight_m"]  # type: ignore[assignment]
        optimizer.weight_v = state["weight_v"]  # type: ignore[assignment]
        optimizer.bias_m = state["bias_m"]  # type: ignore[assignment]
        optimizer.bias_v = state["bias_v"]  # type: ignore[assignment]
        return optimizer

    def set_lr(self, lr: float) -> None:
        self.lr = lr

    def step_sparse(
        self,
        weights: list[list[float]],
        bias: list[float],
        row_grads: dict[int, list[float]],
        bias_grad: list[float],
    ) -> None:
        self.step += 1
        beta1_pow = 1.0 - self.beta1 ** self.step
        beta2_pow = 1.0 - self.beta2 ** self.step
        safe_beta1 = beta1_pow if beta1_pow > 1e-12 else 1e-12
        safe_beta2 = beta2_pow if beta2_pow > 1e-12 else 1e-12

        for row_id, grad_row in row_grads.items():
            weight_row = weights[row_id]
            m_row = self.weight_m[row_id]
            v_row = self.weight_v[row_id]
            for idx, grad in enumerate(grad_row):
                m_row[idx] = self.beta1 * m_row[idx] + (1.0 - self.beta1) * grad
                v_row[idx] = self.beta2 * v_row[idx] + (1.0 - self.beta2) * grad * grad

                m_hat = m_row[idx] / safe_beta1
                v_hat = v_row[idx] / safe_beta2
                update = m_hat / (math.sqrt(v_hat) + self.eps)

                # AdamW decoupled weight decay.
                weight_row[idx] -= self.lr * (update + self.weight_decay * weight_row[idx])

        for idx, grad in enumerate(bias_grad):
            self.bias_m[idx] = self.beta1 * self.bias_m[idx] + (1.0 - self.beta1) * grad
            self.bias_v[idx] = self.beta2 * self.bias_v[idx] + (1.0 - self.beta2) * grad * grad

            m_hat = self.bias_m[idx] / safe_beta1
            v_hat = self.bias_v[idx] / safe_beta2
            update = m_hat / (math.sqrt(v_hat) + self.eps)
            bias[idx] -= self.lr * update


class BigramLanguageModel:
    def __init__(self, vocab_size: int):
        self.vocab_size = vocab_size
        self.weights = [
            [random.gauss(0.0, 0.01) for _ in range(vocab_size)]
            for _ in range(vocab_size)
        ]
        self.bias = [0.0 for _ in range(vocab_size)]

    def predict(self, token_id: int) -> list[float]:
        logits = [self.weights[token_id][idx] + self.bias[idx] for idx in range(self.vocab_size)]
        return softmax(logits)

    def train_batch(
        self,
        input_ids: list[int],
        target_ids: list[int],
        optimizer: AdamWOptimizer,
    ) -> tuple[float, float]:
        total_loss = 0.0
        correct = 0
        row_grads: dict[int, list[float]] = {}
        bias_grad = [0.0 for _ in range(self.vocab_size)]

        for input_id, target_id in zip(input_ids, target_ids):
            logits = [self.weights[input_id][idx] + self.bias[idx] for idx in range(self.vocab_size)]
            probs = softmax(logits)
            total_loss += -math.log(probs[target_id] + 1e-12)

            predicted_id = max(range(self.vocab_size), key=lambda idx: probs[idx])
            if predicted_id == target_id:
                correct += 1

            grad_row = row_grads.get(input_id)
            if grad_row is None:
                grad_row = [0.0 for _ in range(self.vocab_size)]
                row_grads[input_id] = grad_row

            for idx in range(self.vocab_size):
                grad = probs[idx] - (1.0 if idx == target_id else 0.0)
                grad_row[idx] += grad
                bias_grad[idx] += grad

        batch_scale = 1.0 / max(1, len(input_ids))
        for grad_row in row_grads.values():
            for idx in range(self.vocab_size):
                grad_row[idx] *= batch_scale
        for idx in range(self.vocab_size):
            bias_grad[idx] *= batch_scale

        optimizer.step_sparse(self.weights, self.bias, row_grads, bias_grad)

        avg_loss = total_loss / max(1, len(input_ids))
        accuracy = correct / max(1, len(input_ids))
        return avg_loss, accuracy

    def evaluate(self, input_ids: list[int], target_ids: list[int]) -> tuple[float, float]:
        total_loss = 0.0
        correct = 0

        for input_id, target_id in zip(input_ids, target_ids):
            probs = self.predict(input_id)
            total_loss += -math.log(probs[target_id] + 1e-12)
            predicted_id = max(range(self.vocab_size), key=lambda idx: probs[idx])
            if predicted_id == target_id:
                correct += 1

        avg_loss = total_loss / max(1, len(input_ids))
        accuracy = correct / max(1, len(input_ids))
        return avg_loss, accuracy

    def greedy_generate(self, vocab: list[str], prompt: str, max_tokens: int = 20) -> str:
        stoi = {token: idx for idx, token in enumerate(vocab)}
        prompt_tokens = tokenize(prompt)
        if prompt_tokens:
            current_id = stoi.get(prompt_tokens[-1], 0)
            generated = prompt_tokens[:]
        else:
            current_id = 0
            generated = [prompt]
        for _ in range(max_tokens):
            probs = self.predict(current_id)
            next_id = max(range(self.vocab_size), key=lambda idx: probs[idx])
            next_token = vocab[next_id]
            generated.append(next_token)
            current_id = next_id
        return " ".join(generated)


def save_checkpoint(
    save_dir: Path,
    step: int,
    model: BigramLanguageModel,
    optimizer: AdamWOptimizer,
    vocab: list[str],
    stoi: dict[str, int],
    summary: dict[str, object],
) -> Path:
    save_dir.mkdir(parents=True, exist_ok=True)
    checkpoint = {
        "step": step,
        "vocab": vocab,
        "stoi": stoi,
        "model": {
            "weights": model.weights,
            "bias": model.bias,
            "vocab_size": model.vocab_size,
        },
        "optimizer": optimizer.state_dict(),
        "summary": summary,
    }
    path = save_dir / f"checkpoint_step_{step}.json"
    path.write_text(json.dumps(checkpoint, indent=2), encoding="utf-8")
    (save_dir / "latest_checkpoint.json").write_text(
        json.dumps({"path": str(path)}, indent=2),
        encoding="utf-8",
    )
    return path


def load_latest_checkpoint(save_dir: Path) -> dict[str, object] | None:
    latest = save_dir / "latest_checkpoint.json"
    if not latest.exists():
        return None
    payload = json.loads(latest.read_text(encoding="utf-8"))
    path = Path(payload.get("path", ""))
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def cosine_lr(step: int, max_steps: int, lr: float, min_lr: float, warmup_steps: int) -> float:
    if step < warmup_steps:
        return lr * float(step + 1) / float(max(1, warmup_steps))
    progress = (step - warmup_steps) / float(max(1, max_steps - warmup_steps))
    progress = min(1.0, max(0.0, progress))
    cosine = 0.5 * (1.0 + math.cos(math.pi * progress))
    return min_lr + (lr - min_lr) * cosine


def sample_batch(ids: list[int], batch_size: int, rng: random.Random) -> tuple[list[int], list[int]]:
    upper = max(1, len(ids) - 1)
    inputs: list[int] = []
    targets: list[int] = []
    for _ in range(batch_size):
        pos = rng.randrange(0, upper)
        inputs.append(ids[pos])
        targets.append(ids[pos + 1])
    return inputs, targets


def main() -> None:
    args = parse_args()
    rng = random.Random(args.seed)

    corpus_path = Path(args.corpus)
    save_dir = Path(args.save_dir)
    save_dir.mkdir(parents=True, exist_ok=True)

    text = corpus_path.read_text(encoding="utf-8")
    tokens = tokenize(text)
    vocab, stoi = build_vocab(tokens, args.vocab_size)
    ids = encode(tokens, stoi)

    split_at = int(len(ids) * 0.9)
    train_ids = ids[:split_at]
    val_ids = ids[split_at:]
    if len(val_ids) < 2:
        val_ids = train_ids[-max(2, min(128, len(train_ids))):]

    checkpoint_data = load_latest_checkpoint(save_dir) if args.resume else None
    if checkpoint_data is not None:
        vocab = checkpoint_data["vocab"]  # type: ignore[assignment]
        stoi = checkpoint_data["stoi"]  # type: ignore[assignment]
        ids = encode(tokens, stoi)
        split_at = int(len(ids) * 0.9)
        train_ids = ids[:split_at]
        val_ids = ids[split_at:]
        if len(val_ids) < 2:
            val_ids = train_ids[-max(2, min(128, len(train_ids))):]

        model_state = checkpoint_data["model"]  # type: ignore[assignment]
        model = BigramLanguageModel(int(model_state["vocab_size"]))
        model.weights = model_state["weights"]  # type: ignore[assignment]
        model.bias = model_state["bias"]  # type: ignore[assignment]
        optimizer = AdamWOptimizer.from_state_dict(checkpoint_data["optimizer"])  # type: ignore[arg-type]
        start_step = int(checkpoint_data["step"]) + 1
        best_loss = float(checkpoint_data.get("summary", {}).get("best_val_loss", float("inf")))
        print(f"Resumed from checkpoint step {start_step - 1}")
    else:
        model = BigramLanguageModel(len(vocab))
        optimizer = AdamWOptimizer(
            vocab_size=len(vocab),
            lr=args.lr,
            weight_decay=args.weight_decay,
        )
        start_step = 0
        best_loss = float("inf")

    print("=" * 72)
    print("NeurX Real Corpus Training")
    print("=" * 72)
    print(f"Corpus: {corpus_path}")
    print(f"Tokens: {len(tokens)}")
    print(f"Train tokens: {len(train_ids)}")
    print(f"Val tokens: {len(val_ids)}")
    print(f"Vocab size: {len(vocab)}")
    print(f"Steps: {args.steps}")
    print(f"Batch size: {args.batch_size}")
    print(f"Checkpoint dir: {save_dir}")
    print("")

    history: list[dict[str, float | int]] = []
    start_time = time.time()
    last_eval = {"val_loss": 0.0, "val_accuracy": 0.0, "val_perplexity": 0.0}

    for step in range(start_step, args.steps):
        learning_rate = cosine_lr(step, args.steps, args.lr, args.min_lr, args.warmup_steps)
        optimizer.set_lr(learning_rate)
        batch_inputs, batch_targets = sample_batch(train_ids, args.batch_size, rng)
        train_loss, train_accuracy = model.train_batch(
            batch_inputs,
            batch_targets,
            optimizer,
        )

        if step == 0 or (step + 1) % args.eval_interval == 0 or step + 1 == args.steps:
            eval_count = min(len(val_ids) - 1, 512)
            eval_inputs = val_ids[:eval_count]
            eval_targets = val_ids[1 : eval_count + 1]
            val_loss, val_accuracy = model.evaluate(eval_inputs, eval_targets)
            perplexity = math.exp(min(20.0, val_loss))
            elapsed = time.time() - start_time
            steps_per_sec = (step + 1) / max(elapsed, 1e-9)
            last_eval = {
                "val_loss": val_loss,
                "val_accuracy": val_accuracy,
                "val_perplexity": perplexity,
            }
            record = {
                "step": step + 1,
                "learning_rate": learning_rate,
                "train_loss": train_loss,
                "train_accuracy": train_accuracy,
                "val_loss": val_loss,
                "val_accuracy": val_accuracy,
                "val_perplexity": perplexity,
                "steps_per_sec": steps_per_sec,
            }
            history.append(record)
            print(
                f"step {step + 1:4d}/{args.steps} | "
                f"train_loss {train_loss:.4f} | train_acc {train_accuracy:.3f} | "
                f"val_loss {val_loss:.4f} | val_acc {val_accuracy:.3f} | "
                f"ppl {perplexity:.2f} | lr {learning_rate:.4f}"
            )

            if val_loss < best_loss:
                best_loss = val_loss

        if (step + 1) % args.save_every == 0 or step + 1 == args.steps:
            checkpoint_path = save_checkpoint(
                save_dir,
                step + 1,
                model,
                optimizer,
                vocab,
                stoi,
                {
                    "best_val_loss": best_loss,
                    "last_eval": last_eval,
                    "history_tail": history[-10:],
                },
            )
            print(f"saved checkpoint -> {checkpoint_path}")

    elapsed = time.time() - start_time

    sample_prompts = ["The", "model", "attention", "Gradient"]
    generated = {
        prompt: model.greedy_generate(vocab, prompt, max_tokens=12)
        for prompt in sample_prompts
    }

    top_transitions = {}
    for prompt in sample_prompts:
        prompt_id = stoi.get(prompt, 0)
        probs = model.predict(prompt_id)
        top_ids = sorted(range(len(probs)), key=lambda idx: probs[idx], reverse=True)[:5]
        top_transitions[prompt] = [
            {"token": vocab[idx], "prob": probs[idx]} for idx in top_ids
        ]

    summary = {
        "corpus_path": str(corpus_path),
        "save_dir": str(save_dir),
        "tokens": len(tokens),
        "train_tokens": len(train_ids),
        "val_tokens": len(val_ids),
        "vocab_size": len(vocab),
        "steps": args.steps,
        "batch_size": args.batch_size,
        "best_val_loss": best_loss,
        "elapsed_time_sec": elapsed,
        "history": history,
        "generated_samples": generated,
        "top_transitions": top_transitions,
    }

    summary_path = save_dir / "training_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    samples_path = save_dir / "generated_samples.txt"
    sample_lines = []
    for prompt, text_out in generated.items():
        sample_lines.append(f"[{prompt}] {text_out}")
    samples_path.write_text("\n".join(sample_lines) + "\n", encoding="utf-8")

    print("")
    print(f"Training complete in {elapsed:.2f}s")
    print(f"Summary: {summary_path}")
    print(f"Samples: {samples_path}")


if __name__ == "__main__":
    main()
