import os
import time
import uuid
from threading import Lock

import torch
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer


MODEL_PATH = os.getenv("MODEL_PATH", "/model/Qwen2.5-0.5B-Instruct")
MODEL_ID = os.getenv("MODEL_ID", "Qwen2.5-0.5B-Instruct")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8002"))
DEFAULT_MAX_TOKENS = int(os.getenv("DEFAULT_MAX_TOKENS", "128"))
DEVICE = os.getenv("DEVICE", "cpu").lower()
ATTN_IMPLEMENTATION = os.getenv("ATTN_IMPLEMENTATION", "eager")

if DEVICE == "npu":
    MODEL_DTYPE = torch.float16
else:
    MODEL_DTYPE = torch.float32

app = FastAPI(title="Qwen2.5 CPU API", version="1.0.0")

tokenizer = None
model = None
generation_lock = Lock()


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatCompletionRequest(BaseModel):
    model: str
    messages: list[ChatMessage]
    max_tokens: int | None = None
    temperature: float | None = 0.0
    top_p: float | None = 1.0


class CompletionRequest(BaseModel):
    model: str
    prompt: str
    max_tokens: int | None = None
    temperature: float | None = 0.0
    top_p: float | None = 1.0


def _load_model() -> None:
    global tokenizer, model

    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH,
        trust_remote_code=True,
        dtype=MODEL_DTYPE,
        attn_implementation=ATTN_IMPLEMENTATION,
    )
    if hasattr(model, "config"):
        model.config._attn_implementation = ATTN_IMPLEMENTATION
    if DEVICE != "cpu":
        model = model.to(f"{DEVICE}:0")
    model.eval()


@app.on_event("startup")
def startup_event() -> None:
    _load_model()


def _build_generate_kwargs(max_tokens: int | None, temperature: float | None, top_p: float | None) -> dict:
    effective_max_tokens = max_tokens or DEFAULT_MAX_TOKENS
    effective_temperature = 0.0 if temperature is None else temperature
    effective_top_p = 1.0 if top_p is None else top_p
    do_sample = effective_temperature > 0

    kwargs = {
        "max_new_tokens": effective_max_tokens,
        "do_sample": do_sample,
        "pad_token_id": tokenizer.eos_token_id,
    }
    if do_sample:
        kwargs["temperature"] = effective_temperature
        kwargs["top_p"] = effective_top_p
    return kwargs


def _generate_from_prompt(prompt: str, max_tokens: int | None, temperature: float | None, top_p: float | None) -> tuple[str, dict]:
    inputs = tokenizer(prompt, return_tensors="pt")
    if DEVICE != "cpu":
        inputs = inputs.to(f"{DEVICE}:0")
    prompt_tokens = int(inputs["input_ids"].shape[-1])
    generate_kwargs = _build_generate_kwargs(max_tokens, temperature, top_p)

    with generation_lock:
        with torch.no_grad():
            outputs = model.generate(**inputs, **generate_kwargs)

    generated_ids = outputs[0][prompt_tokens:]
    text = tokenizer.decode(generated_ids, skip_special_tokens=True).strip()
    completion_tokens = int(generated_ids.shape[-1])
    usage = {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": prompt_tokens + completion_tokens,
    }
    return text, usage


def _chat_prompt(messages: list[ChatMessage]) -> str:
    payload = [{"role": message.role, "content": message.content} for message in messages]
    if hasattr(tokenizer, "apply_chat_template"):
        return tokenizer.apply_chat_template(payload, tokenize=False, add_generation_prompt=True)
    return "\n".join(f"{message.role}: {message.content}" for message in messages) + "\nassistant:"


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "model": MODEL_ID, "device": DEVICE}


@app.get("/v1/models")
def list_models() -> dict:
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_ID,
                "object": "model",
                "created": int(time.time()),
                "owned_by": f"self-hosted-{DEVICE}",
            }
        ],
    }


@app.post("/v1/chat/completions")
def chat_completions(request: ChatCompletionRequest) -> dict:
    if request.model != MODEL_ID:
        raise HTTPException(status_code=404, detail=f"unknown model: {request.model}")

    prompt = _chat_prompt(request.messages)
    answer, usage = _generate_from_prompt(prompt, request.max_tokens, request.temperature, request.top_p)
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:24]}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": MODEL_ID,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": answer},
                "finish_reason": "stop",
            }
        ],
        "usage": usage,
    }


@app.post("/v1/completions")
def completions(request: CompletionRequest) -> dict:
    if request.model != MODEL_ID:
        raise HTTPException(status_code=404, detail=f"unknown model: {request.model}")

    answer, usage = _generate_from_prompt(request.prompt, request.max_tokens, request.temperature, request.top_p)
    return {
        "id": f"cmpl-{uuid.uuid4().hex[:24]}",
        "object": "text_completion",
        "created": int(time.time()),
        "model": MODEL_ID,
        "choices": [
            {
                "index": 0,
                "text": answer,
                "finish_reason": "stop",
            }
        ],
        "usage": usage,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=HOST, port=PORT)