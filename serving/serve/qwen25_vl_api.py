import base64
import io
import inspect
import logging
import os
import time
import urllib.request
import uuid
from threading import Lock
from typing import Any

import torch
from fastapi import FastAPI, HTTPException, Request
from PIL import Image
from pydantic import BaseModel
from transformers import AutoProcessor, Qwen2_5_VLForConditionalGeneration


MODEL_PATH = os.getenv("MODEL_PATH", "/model/Qwen2.5-VL-7B")
MODEL_ID = os.getenv("MODEL_ID", "Qwen2.5-VL-7B")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8004"))
DEFAULT_MAX_TOKENS = int(os.getenv("DEFAULT_MAX_TOKENS", "128"))
DEVICE = os.getenv("DEVICE", "cpu").lower()
ATTN_IMPLEMENTATION = os.getenv("ATTN_IMPLEMENTATION", "eager")
VISIBLE_DEVICES = os.getenv("ASCEND_RT_VISIBLE_DEVICES", "")

MODEL_DTYPE = torch.float16 if DEVICE != "cpu" else "auto"

LOG_LEVEL = os.getenv("LLM_LOG_LEVEL", "INFO").upper()
if not logging.getLogger().handlers:
    logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(name)s %(message)s")

app = FastAPI(title="Qwen2.5-VL API", version="1.0.0")

processor = None
model = None
generation_lock = Lock()
logger = logging.getLogger(__name__)
logger.setLevel(LOG_LEVEL)


def _caller_code_ref(depth: int = 1) -> str:
    frame = inspect.currentframe()
    try:
        for _ in range(depth):
            if frame is None:
                break
            frame = frame.f_back
        if frame is None:
            return "unknown"
        return f"{os.path.basename(frame.f_code.co_filename)}:{frame.f_lineno}"
    finally:
        del frame


def _format_log_value(value: Any, limit: int = 180) -> str:
    if isinstance(value, str):
        text = value.replace("\n", "\\n")
    elif isinstance(value, (int, float, bool)) or value is None:
        text = str(value)
    else:
        text = str(value)
    if len(text) > limit:
        return f"{text[:limit]}..."
    return text


def _trace_log(event: str, **fields: Any) -> None:
    parts = [f"{key}={_format_log_value(value)}" for key, value in fields.items() if value is not None]
    message = f"trace event={event} code={_caller_code_ref(depth=2)}"
    if parts:
        message = f"{message} {' '.join(parts)}"
    logger.info(message)


def _visible_device_ids() -> list[int]:
    if DEVICE == "cpu":
        return []

    raw = VISIBLE_DEVICES.strip()
    if not raw:
        return [0]

    device_ids: list[int] = []
    for item in raw.split(","):
        value = item.strip()
        if not value:
            continue
        try:
            device_ids.append(int(value))
        except ValueError:
            continue
    return device_ids or [0]


def _use_multi_npu() -> bool:
    return DEVICE == "npu" and len(_visible_device_ids()) > 1


class ChatMessage(BaseModel):
    role: str
    content: Any


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


def _device_name() -> str:
    return "cpu" if DEVICE == "cpu" else f"{DEVICE}:0"


def _input_device_name() -> str:
    if DEVICE == "cpu" or model is None:
        return "cpu"

    hf_device_map = getattr(model, "hf_device_map", None)
    if isinstance(hf_device_map, dict):
        for mapped_device in hf_device_map.values():
            if isinstance(mapped_device, int):
                return f"{DEVICE}:{mapped_device}"
            if isinstance(mapped_device, str) and mapped_device not in {"cpu", "disk"}:
                return mapped_device

    return _device_name()


def _load_model() -> None:
    global processor, model

    processor = AutoProcessor.from_pretrained(MODEL_PATH, trust_remote_code=True, use_fast=False)
    model_kwargs = {
        "trust_remote_code": True,
        "dtype": MODEL_DTYPE,
        "attn_implementation": ATTN_IMPLEMENTATION,
    }
    if _use_multi_npu():
        model_kwargs["device_map"] = "auto"
        model_kwargs["low_cpu_mem_usage"] = True

    model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
        MODEL_PATH,
        **model_kwargs,
    )
    if DEVICE != "cpu" and not _use_multi_npu():
        model = model.to(_device_name())
    model.eval()


@app.on_event("startup")
def startup_event() -> None:
    _load_model()


def _build_generate_kwargs(max_tokens: int | None, temperature: float | None, top_p: float | None) -> dict[str, Any]:
    effective_max_tokens = max_tokens or DEFAULT_MAX_TOKENS
    effective_temperature = 0.0 if temperature is None else temperature
    effective_top_p = 1.0 if top_p is None else top_p
    do_sample = effective_temperature > 0
    if _use_multi_npu() and do_sample:
        do_sample = False

    kwargs: dict[str, Any] = {
        "max_new_tokens": effective_max_tokens,
        "do_sample": do_sample,
        "pad_token_id": processor.tokenizer.eos_token_id,
    }
    if do_sample:
        kwargs["temperature"] = effective_temperature
        kwargs["top_p"] = effective_top_p
    return kwargs


def _read_image(source: str) -> Image.Image:
    if source.startswith("data:"):
        _, encoded = source.split(",", 1)
        raw = base64.b64decode(encoded)
        return Image.open(io.BytesIO(raw)).convert("RGB")

    if source.startswith("http://") or source.startswith("https://"):
        with urllib.request.urlopen(source, timeout=30) as response:
            return Image.open(io.BytesIO(response.read())).convert("RGB")

    return Image.open(source).convert("RGB")


def _normalize_message_content(content: Any) -> tuple[list[dict[str, str]], list[Image.Image]]:
    if isinstance(content, str):
        return ([{"type": "text", "text": content}], [])

    if not isinstance(content, list):
        raise HTTPException(status_code=400, detail="message content must be a string or an array")

    parts: list[dict[str, str]] = []
    images: list[Image.Image] = []
    for item in content:
        if not isinstance(item, dict):
            raise HTTPException(status_code=400, detail="message content items must be objects")

        item_type = str(item.get("type", "")).strip().lower()
        if item_type == "text":
            text = str(item.get("text", ""))
            parts.append({"type": "text", "text": text})
            continue

        if item_type == "image_url":
            image_payload = item.get("image_url")
            if isinstance(image_payload, dict):
                image_source = str(image_payload.get("url", "")).strip()
            else:
                image_source = str(image_payload or "").strip()
            if not image_source:
                raise HTTPException(status_code=400, detail="image_url content is missing url")
            parts.append({"type": "image", "image": image_source})
            images.append(_read_image(image_source))
            continue

        raise HTTPException(status_code=400, detail=f"unsupported content type: {item_type}")

    return parts, images


def _normalize_messages(messages: list[ChatMessage]) -> tuple[list[dict[str, Any]], list[Image.Image]]:
    normalized_messages: list[dict[str, Any]] = []
    images: list[Image.Image] = []

    for message in messages:
        normalized_content, message_images = _normalize_message_content(message.content)
        normalized_messages.append({"role": message.role, "content": normalized_content})
        images.extend(message_images)

    return normalized_messages, images


def _generate_from_messages(
    messages: list[ChatMessage],
    max_tokens: int | None,
    temperature: float | None,
    top_p: float | None,
    trace_id: str | None = None,
) -> tuple[str, dict[str, int]]:
    normalized_messages, images = _normalize_messages(messages)
    prompt = processor.apply_chat_template(normalized_messages, tokenize=False, add_generation_prompt=True)
    model_inputs = processor(
        text=[prompt],
        images=images or None,
        padding=True,
        return_tensors="pt",
    )
    prompt_tokens = int(model_inputs["input_ids"].shape[-1])
    if DEVICE != "cpu" and not _use_multi_npu():
        model_inputs = model_inputs.to(_input_device_name())

    generate_kwargs = _build_generate_kwargs(max_tokens, temperature, top_p)
    _trace_log(
        "model_generate_start",
        trace_id=trace_id,
        model=MODEL_ID,
        device=DEVICE,
        deployment="multi_npu" if _use_multi_npu() else "single_device",
        message_count=len(messages),
        image_count=len(images),
        prompt_tokens=prompt_tokens,
        do_sample=generate_kwargs.get("do_sample"),
        max_new_tokens=generate_kwargs.get("max_new_tokens"),
    )
    with generation_lock:
        with torch.no_grad():
            generated = model.generate(**model_inputs, **generate_kwargs)

    generated_ids = generated[:, prompt_tokens:]
    text = processor.batch_decode(generated_ids, skip_special_tokens=True, clean_up_tokenization_spaces=False)[0].strip()
    completion_tokens = int(generated_ids.shape[-1])
    usage = {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": prompt_tokens + completion_tokens,
    }
    _trace_log(
        "model_generate_done",
        trace_id=trace_id,
        model=MODEL_ID,
        prompt_tokens=usage["prompt_tokens"],
        completion_tokens=usage["completion_tokens"],
        total_tokens=usage["total_tokens"],
    )
    return text, usage


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "model": MODEL_ID,
        "device": DEVICE,
        "visible_devices": VISIBLE_DEVICES or "0",
        "deployment": "multi_npu" if _use_multi_npu() else "single_device",
    }


@app.get("/v1/models")
def list_models() -> dict[str, Any]:
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
def chat_completions(request: ChatCompletionRequest, http_request: Request) -> dict[str, Any]:
    trace_id = http_request.headers.get("X-Neurx-Trace-Id", "") or uuid.uuid4().hex[:12]
    _trace_log(
        "model_request",
        trace_id=trace_id,
        endpoint="/v1/chat/completions",
        remote=(http_request.client.host if http_request.client else None),
        model=request.model,
        message_count=len(request.messages),
        temperature=request.temperature,
        top_p=request.top_p,
    )
    if request.model != MODEL_ID:
        raise HTTPException(status_code=404, detail=f"unknown model: {request.model}")

    answer, usage = _generate_from_messages(request.messages, request.max_tokens, request.temperature, request.top_p, trace_id=trace_id)
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
def completions(request: CompletionRequest, http_request: Request) -> dict[str, Any]:
    trace_id = http_request.headers.get("X-Neurx-Trace-Id", "") or uuid.uuid4().hex[:12]
    _trace_log(
        "model_request",
        trace_id=trace_id,
        endpoint="/v1/completions",
        remote=(http_request.client.host if http_request.client else None),
        model=request.model,
        prompt_len=len(request.prompt),
        temperature=request.temperature,
        top_p=request.top_p,
    )
    if request.model != MODEL_ID:
        raise HTTPException(status_code=404, detail=f"unknown model: {request.model}")

    answer, usage = _generate_from_messages(
        [ChatMessage(role="user", content=request.prompt)],
        request.max_tokens,
        request.temperature,
        request.top_p,
        trace_id=trace_id,
    )
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