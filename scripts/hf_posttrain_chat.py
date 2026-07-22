#!/usr/bin/env python3
import os
import sys


def main() -> int:
    try:
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
    except Exception as exc:
        print(f"error: missing dependency: {exc}", file=sys.stderr)
        return 2

    model_path = os.environ.get(
        "NEURX_CHAT_MODEL_PATH",
        "/home/shuwen/shuwen/train/model/base-model-posttrain",
    )
    system_prompt = os.environ.get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful assistant.",
    )
    max_new_tokens = int(os.environ.get("NEURX_CHAT_MAX_NEW_TOKENS", "256"))
    temperature = float(os.environ.get("NEURX_CHAT_TEMPERATURE", "0.7"))
    top_p = float(os.environ.get("NEURX_CHAT_TOP_P", "0.9"))
    top_k = int(os.environ.get("NEURX_CHAT_TOP_K", "50"))

    tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        torch_dtype="auto",
        device_map="auto",
        trust_remote_code=True,
    )
    model.eval()

    messages = [{"role": "system", "content": system_prompt}]
    print(f"Loaded model: {model_path}")
    print("Type /exit to quit, /reset to clear history.\n")

    while True:
        try:
            user_text = input("You: ").strip()
        except EOFError:
            break
        if not user_text:
            continue
        if user_text in {"/exit", "exit", "quit"}:
            break
        if user_text == "/reset":
            messages = [{"role": "system", "content": system_prompt}]
            print("History cleared.\n")
            continue

        messages.append({"role": "user", "content": user_text})
        prompt_text = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )
        inputs = tokenizer(prompt_text, return_tensors="pt").to(model.device)

        with torch.no_grad():
            output_ids = model.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
                do_sample=temperature > 0,
                temperature=temperature if temperature > 0 else None,
                top_p=top_p,
                top_k=top_k,
                eos_token_id=tokenizer.eos_token_id,
                pad_token_id=tokenizer.eos_token_id,
            )

        new_tokens = output_ids[0][inputs["input_ids"].shape[-1]:]
        response = tokenizer.decode(new_tokens, skip_special_tokens=True).strip()
        if not response:
            response = "(empty response)"
        print(f"Assistant: {response}\n")
        messages.append({"role": "assistant", "content": response})

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
