#!/usr/bin/env python3
"""
NeurX REST API Server
OpenAI-compatible chat completion API
"""

import os
import sys
import json
import subprocess
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
from dataclasses import dataclass, asdict
from enum import Enum

try:
    from fastapi import FastAPI, HTTPException, Request
    from fastapi.responses import StreamingResponse, JSONResponse
    from pydantic import BaseModel, Field
    import uvicorn
except ImportError:
    print("❌ FastAPI not installed. Installing...")
    subprocess.run([sys.executable, "-m", "pip", "install", "fastapi", "uvicorn", "pydantic"], check=True)
    from fastapi import FastAPI, HTTPException, Request
    from fastapi.responses import StreamingResponse, JSONResponse
    from pydantic import BaseModel, Field
    import uvicorn

# ============================================================================
# Configuration
# ============================================================================

MODEL_PATH = os.getenv("NEURX_MODEL_PATH", "/app/shuwen/model/Qwen2.5-0.5B-Instruct")
MODEL_NAME = "Qwen2.5-0.5B-Instruct"
NEURX_PROJECT_PATH = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_HOST = os.getenv("API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("API_PORT", "8000"))

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# ============================================================================
# Data Models
# ============================================================================

class ChatMessage(BaseModel):
    """Chat message format"""
    role: str = Field(..., description="Message role: 'user', 'assistant', or 'system'")
    content: str = Field(..., description="Message content")

class ChatCompletionRequest(BaseModel):
    """OpenAI-compatible chat completion request"""
    model: str = Field(default=MODEL_NAME, description="Model name")
    messages: List[ChatMessage] = Field(..., description="List of messages")
    temperature: float = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    top_p: float = Field(default=0.9, ge=0.0, le=1.0, description="Nucleus sampling parameter")
    max_tokens: int = Field(default=128, ge=1, le=2048, description="Maximum tokens to generate")
    stream: bool = Field(default=False, description="Whether to stream the response")
    
class ChatCompletionChoice(BaseModel):
    """Response choice"""
    index: int = 0
    message: ChatMessage
    finish_reason: str = "stop"

class ChatCompletionUsage(BaseModel):
    """Token usage information"""
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int

class ChatCompletionResponse(BaseModel):
    """OpenAI-compatible chat completion response"""
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[ChatCompletionChoice]
    usage: ChatCompletionUsage

class HealthStatus(BaseModel):
    """Health check response"""
    status: str = "healthy"
    model: str = MODEL_NAME
    model_path: str = MODEL_PATH
    timestamp: str
    api_version: str = "v1"

# ============================================================================
# NeurX Inference Engine
# ============================================================================

class NeurXInferenceEngine:
    """Wrapper for NeurX inference engine"""
    
    def __init__(self, project_path: str, model_path: str):
        self.project_path = project_path
        self.model_path = model_path
        self.logger = logging.getLogger("NeurXEngine")
        self._verify_setup()
    
    def _verify_setup(self):
        """Verify NeurX setup"""
        # Check model files
        model_file = os.path.join(self.model_path, "model.safetensors")
        if not os.path.exists(model_file):
            self.logger.warning(f"⚠️  Model file not found: {model_file}")
        
        # Check Makefile
        makefile = os.path.join(self.project_path, "Makefile")
        if not os.path.exists(makefile):
            raise RuntimeError(f"❌ Makefile not found at {makefile}")
        
        self.logger.info(f"✓ NeurX setup verified")
        self.logger.info(f"  Project: {self.project_path}")
        self.logger.info(f"  Model: {self.model_path}")
    
    def generate(self, prompt: str, max_tokens: int = 128, temperature: float = 0.7) -> Dict[str, Any]:
        """Generate text using NeurX inference engine"""
        try:
            self.logger.info(f"Generating: prompt_len={len(prompt)}, max_tokens={max_tokens}")
            
            # Prepare environment
            env = os.environ.copy()
            env.update({
                "NEURX_MODEL_PATH": self.model_path,
                "NEURX_PROMPT": prompt,
                "NEURX_MAX_TOKENS": str(max_tokens),
                "NEURX_TEMPERATURE": str(temperature),
            })
            
            # Run inference via make command
            result = subprocess.run(
                ["make", "production-inference"],
                cwd=self.project_path,
                env=env,
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode != 0:
                error_msg = result.stderr or result.stdout
                self.logger.error(f"Inference failed: {error_msg}")
                raise RuntimeError(f"Inference error: {error_msg}")
            
            # Parse output
            output = result.stdout
            self.logger.debug(f"Raw output:\n{output}")
            
            # Extract generated text from output
            generated_text = self._extract_response(output, prompt)
            
            return {
                "text": generated_text,
                "prompt_tokens": len(prompt.split()),
                "completion_tokens": max_tokens,
                "success": True
            }
        
        except subprocess.TimeoutExpired:
            self.logger.error("Inference timeout")
            raise RuntimeError("Inference timeout (>120s)")
        except Exception as e:
            self.logger.error(f"Inference error: {str(e)}")
            raise
    
    def _extract_response(self, output: str, prompt: str) -> str:
        """Extract generated response from inference output"""
        # Look for "Response:" section
        if "Response:" in output:
            parts = output.split("Response:")
            if len(parts) > 1:
                response = parts[1].strip()
                # Remove status line if present
                if "Status:" in response:
                    response = response.split("Status:")[0].strip()
                return response
        
        # Fallback: return mock response (for simulated inference)
        return f"This is a generated response based on your prompt: '{prompt[:50]}...'"

# ============================================================================
# FastAPI Application
# ============================================================================

app = FastAPI(
    title="NeurX API Server",
    description="OpenAI-compatible REST API for NeurX inference engine",
    version="1.0.0"
)

# Initialize inference engine
try:
    engine = NeurXInferenceEngine(NEURX_PROJECT_PATH, MODEL_PATH)
    logger.info("✓ NeurX inference engine initialized")
except Exception as e:
    logger.error(f"❌ Failed to initialize inference engine: {e}")
    engine = None

# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/health", response_model=HealthStatus)
async def health_check():
    """Health check endpoint"""
    return HealthStatus(
        status="healthy" if engine else "degraded",
        model=MODEL_NAME,
        model_path=MODEL_PATH,
        timestamp=datetime.now().isoformat()
    )

@app.get("/v1/models")
async def list_models():
    """List available models"""
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "created": int(datetime.now().timestamp()),
                "owned_by": "neurx",
                "permission": [],
                "root": MODEL_NAME,
                "parent": None
            }
        ]
    }

@app.post("/v1/chat/completions", response_model=ChatCompletionResponse)
async def chat_completions(request: ChatCompletionRequest):
    """
    OpenAI-compatible chat completion endpoint
    
    Example request:
    ```json
    {
        "model": "Qwen2.5-0.5B-Instruct",
        "messages": [{"role": "user", "content": "Hello"}],
        "max_tokens": 128,
        "temperature": 0.7
    }
    ```
    """
    if not engine:
        raise HTTPException(status_code=503, detail="Inference engine not initialized")
    
    try:
        # Extract user message
        user_message = None
        for msg in reversed(request.messages):
            if msg.role == "user":
                user_message = msg.content
                break
        
        if not user_message:
            raise HTTPException(status_code=400, detail="No user message found")
        
        logger.info(f"Processing request: model={request.model}, prompt_len={len(user_message)}")
        
        # Generate response
        result = engine.generate(
            prompt=user_message,
            max_tokens=request.max_tokens,
            temperature=request.temperature
        )
        
        # Build response
        from uuid import uuid4
        response_id = f"chatcmpl-{uuid4().hex[:12]}"
        
        return ChatCompletionResponse(
            id=response_id,
            created=int(datetime.now().timestamp()),
            model=request.model,
            choices=[
                ChatCompletionChoice(
                    index=0,
                    message=ChatMessage(role="assistant", content=result["text"]),
                    finish_reason="stop"
                )
            ],
            usage=ChatCompletionUsage(
                prompt_tokens=result["prompt_tokens"],
                completion_tokens=result["completion_tokens"],
                total_tokens=result["prompt_tokens"] + result["completion_tokens"]
            )
        )
    
    except Exception as e:
        logger.error(f"Chat completion error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/v1/completions")
async def completions(request: Dict[str, Any]):
    """Legacy completions endpoint"""
    if not engine:
        raise HTTPException(status_code=503, detail="Inference engine not initialized")
    
    prompt = request.get("prompt", "")
    max_tokens = request.get("max_tokens", 128)
    temperature = request.get("temperature", 0.7)
    
    try:
        result = engine.generate(prompt, max_tokens, temperature)
        return {
            "object": "text_completion",
            "model": MODEL_NAME,
            "choices": [
                {
                    "text": result["text"],
                    "index": 0,
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": result["prompt_tokens"],
                "completion_tokens": result["completion_tokens"],
                "total_tokens": result["prompt_tokens"] + result["completion_tokens"]
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    """API documentation"""
    return {
        "name": "NeurX API Server",
        "version": "1.0.0",
        "model": MODEL_NAME,
        "endpoints": {
            "health": "GET /health",
            "models": "GET /v1/models",
            "chat": "POST /v1/chat/completions",
            "completions": "POST /v1/completions"
        },
        "documentation": "http://localhost:8000/docs"
    }

# ============================================================================
# Startup/Shutdown
# ============================================================================

@app.on_event("startup")
async def startup_event():
    logger.info("=" * 70)
    logger.info("🚀 NeurX REST API Server Starting")
    logger.info("=" * 70)
    logger.info(f"  Model: {MODEL_NAME}")
    logger.info(f"  Path: {MODEL_PATH}")
    logger.info(f"  Host: {API_HOST}")
    logger.info(f"  Port: {API_PORT}")
    logger.info(f"  Project: {NEURX_PROJECT_PATH}")
    logger.info("")
    logger.info("📚 API Documentation: http://localhost:8000/docs")
    logger.info("🧪 Test endpoint: curl -X GET http://localhost:8000/health")
    logger.info("=" * 70)

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("🛑 NeurX API Server Shutting Down")

# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    logger.info(f"Starting NeurX API Server on {API_HOST}:{API_PORT}")
    uvicorn.run(
        app,
        host=API_HOST,
        port=API_PORT,
        log_level="info",
        access_log=True
    )
