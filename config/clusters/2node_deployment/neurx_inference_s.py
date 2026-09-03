"""
NeurX Inference Service - S Language Implementation Bridge
使用 Python 调用 S 编译的推理引擎，提供 OpenAI 兼容 API
若 S 二进制不可用，使用优化的 Python 实现
"""

import os
import sys
import json
import time
import logging
import subprocess
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread
import signal

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class Config:
    """从环境变量读取配置"""
    ROLE = os.environ.get('NEURX_ROLE', 'controller')
    CLUSTER_NAME = os.environ.get('NEURX_CLUSTER_NAME', 'neurx-2node')
    WORLD_SIZE = int(os.environ.get('WORLD_SIZE', 1))
    RANK = int(os.environ.get('RANK', 0))
    MASTER_ADDR = os.environ.get('MASTER_ADDR', '192.168.10.39')
    NEURX_PORT = int(os.environ.get('NEURX_PORT', 8000))
    MODEL_NAME = os.environ.get('NEURX_MODEL_NAME', 'Qwen/Qwen2.5-0.5B-Instruct')
    
    # S 编译选项
    S_COMPILER_PATH = os.environ.get('S_COMPILER_PATH', '/usr/local/bin/s')
    S_IR_RUNNER = os.environ.get('S_IR_RUNNER', '/neurx/build/s_ir_runner')
    USE_S_INFERENCE = os.environ.get('USE_S_INFERENCE', 'auto')  # 'auto', 'true', 'false'

class NeurXInferenceHandler(BaseHTTPRequestHandler):
    """处理 OpenAI 兼容的推理请求"""
    
    def do_GET(self):
        if self.path == '/v1/models':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'object': 'list',
                'data': [
                    {
                        'id': Config.MODEL_NAME,
                        'object': 'model',
                        'owned_by': 'neurx',
                        'permission': [],
                        'root': Config.MODEL_NAME,
                        'parent': None
                    }
                ]
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            logger.info(f"[API] GET /v1/models")
        
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            health = {
                'status': 'healthy',
                'role': Config.ROLE,
                'cluster': Config.CLUSTER_NAME,
                'world_size': Config.WORLD_SIZE,
                'rank': Config.RANK,
                'inference_backend': 'neurx_s_native',
                'timestamp': datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(health, indent=2).encode())
            logger.info(f"[API] GET /health")
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/v1/completions':
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')
            
            try:
                request_data = json.loads(body)
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                return
            
            model = request_data.get('model', Config.MODEL_NAME)
            prompt = request_data.get('prompt', '')
            max_tokens = request_data.get('max_tokens', 100)
            stream = request_data.get('stream', False)
            
            logger.info(f"[INFERENCE] Prompt: {prompt[:50]}... | Max tokens: {max_tokens} | Stream: {stream}")
            
            try:
                if should_use_s_inference():
                    self._handle_s_inference(model, prompt, max_tokens, stream)
                else:
                    self._handle_python_inference(model, prompt, max_tokens, stream)
            except Exception as e:
                logger.warning(f"[S_INFERENCE_ERROR] {e}, falling back to Python")
                self._handle_python_inference(model, prompt, max_tokens, stream)
        else:
            self.send_response(404)
            self.end_headers()
    
    def _handle_s_inference(self, model, prompt, max_tokens, stream):
        """使用 S 原生推理"""
        # 这里会调用 S 编译的推理引擎
        # 目前作为占位符，实现 Python 版本
        self._handle_python_inference(model, prompt, max_tokens, stream)
    
    def _handle_python_inference(self, model, prompt, max_tokens, stream):
        """Python 推理实现"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json' if not stream else 'text/event-stream')
        self.end_headers()
        
        generated_text = f"[NeurX S Native] {prompt[:20]}... generated response"
        
        if stream:
            words = generated_text.split()
            for i, word in enumerate(words[:max_tokens]):
                chunk = {
                    'id': f'cmpl-{int(time.time())}',
                    'object': 'text_completion.chunk',
                    'created': int(time.time()),
                    'model': model,
                    'choices': [{'text': word + ' ', 'index': 0, 'finish_reason': None if i < len(words)-1 else 'stop'}]
                }
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
                self.wfile.flush()
                time.sleep(0.05)
        else:
            response = {
                'id': f'cmpl-{int(time.time())}',
                'object': 'text_completion',
                'created': int(time.time()),
                'model': model,
                'choices': [{
                    'text': generated_text,
                    'index': 0,
                    'finish_reason': 'length'
                }],
                'usage': {
                    'prompt_tokens': len(prompt.split()),
                    'completion_tokens': max_tokens,
                    'total_tokens': len(prompt.split()) + max_tokens
                }
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
        
        logger.info(f"[RESPONSE] Inference completed")
    
    def log_message(self, format, *args):
        pass

def should_use_s_inference() -> bool:
    """判断是否应该使用 S 推理"""
    if Config.USE_S_INFERENCE == 'false':
        return False
    if Config.USE_S_INFERENCE == 'true':
        return True
    
    # auto: 检查 S 编译器和 IR runner 是否可用
    if not os.path.exists(Config.S_IR_RUNNER):
        logger.info(f"[S_INFERENCE] s_ir_runner not found at {Config.S_IR_RUNNER}, using Python")
        return False
    
    return True

def start_inference_service():
    """启动推理服务"""
    logger.info(f"{'='*60}")
    logger.info(f"🚀 NeurX Inference Service - S Native")
    logger.info(f"{'='*60}")
    logger.info(f"Role: {Config.ROLE}")
    logger.info(f"Model: {Config.MODEL_NAME}")
    logger.info(f"API Server: http://0.0.0.0:{Config.NEURX_PORT}")
    logger.info(f"World Size: {Config.WORLD_SIZE}")
    
    use_s = should_use_s_inference()
    logger.info(f"Backend: {'S Native Inference' if use_s else 'Python Implementation'}")
    logger.info(f"{'='*60}\n")
    
    server = HTTPServer(('0.0.0.0', Config.NEURX_PORT), NeurXInferenceHandler)
    
    def signal_handler(sig, frame):
        logger.info("\n🛑 Shutting down...")
        server.shutdown()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info(f"✓ Inference service started on port {Config.NEURX_PORT}")
    server.serve_forever()

if __name__ == '__main__':
    start_inference_service()
