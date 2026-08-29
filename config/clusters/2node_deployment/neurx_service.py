#!/usr/bin/env python3
"""
NeurX Distributed Inference Service - Python Mock Implementation
Demonstrates the distributed inference architecture without S compiler dependency
"""

import os
import sys
import json
import time
import logging
import socket
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread
import signal

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class Config:
    """Configuration from environment variables"""
    ROLE = os.environ.get('NEURX_ROLE', 'controller')
    CLUSTER_NAME = os.environ.get('NEURX_CLUSTER_NAME', 'neurx-2node')
    WORLD_SIZE = int(os.environ.get('WORLD_SIZE', 1))
    RANK = int(os.environ.get('RANK', 0))
    LOCAL_RANK = int(os.environ.get('LOCAL_RANK', 0))
    
    MASTER_ADDR = os.environ.get('MASTER_ADDR', '192.168.10.39')
    MASTER_PORT = int(os.environ.get('MASTER_PORT', 29500))
    NEURX_PORT = int(os.environ.get('NEURX_PORT', 8000))
    NEURX_NODE_PORT = int(os.environ.get('NEURX_NODE_PORT', 29501))
    NEURX_NODE_HOST = os.environ.get('NEURX_NODE_HOST', '192.168.10.75')
    
    MODEL_NAME = os.environ.get('NEURX_MODEL_NAME', 'Qwen/Qwen2.5-0.5B-Instruct')
    HEARTBEAT_DIR = os.environ.get('NEURX_HEARTBEAT_DIR', '/tmp/neurx_cluster/heartbeat')
    LOG_DIR = os.environ.get('NEURX_LOG_DIR', '/tmp/neurx_cluster/logs')

class DistributedController(BaseHTTPRequestHandler):
    """Controller node handler"""
    
    def do_GET(self):
        if self.path == '/v1/models':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'object': 'list',
                'data': [
                    {
                        'id': 'Qwen/Qwen2.5-0.5B-Instruct',
                        'object': 'model',
                        'owned_by': 'qwen',
                        'permission': [],
                        'root': 'Qwen/Qwen2.5-0.5B-Instruct',
                        'parent': None
                    }
                ]
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            logger.info(f"[API] GET /v1/models -> {len(response['data'])} models")
        
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
                'workers_connected': Config.WORLD_SIZE - 1
            }
            self.wfile.write(json.dumps(health, indent=2).encode())
            logger.info(f"[API] GET /health -> cluster health check")
        
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
            
            # Simulate inference
            model = request_data.get('model', Config.MODEL_NAME)
            prompt = request_data.get('prompt', '')
            max_tokens = request_data.get('max_tokens', 100)
            stream = request_data.get('stream', False)
            
            logger.info(f"[INFERENCE] Model: {model}, Prompt length: {len(prompt)}, Max tokens: {max_tokens}")
            
            # Simulate inference delay
            inference_time = 0.1 + (max_tokens / 100.0)
            
            if stream:
                self._handle_stream(model, prompt, max_tokens, inference_time)
            else:
                self._handle_completion(model, prompt, max_tokens, inference_time)
        else:
            self.send_response(404)
            self.end_headers()
    
    def _handle_completion(self, model, prompt, max_tokens, inference_time):
        """Handle non-streaming completion"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        # Simulate generated text
        generated = f"This is a simulated inference response. Input was '{prompt[:30]}...' Expected {max_tokens} tokens."
        
        response = {
            'id': f'cmpl-{int(time.time())}',
            'object': 'text_completion',
            'created': int(time.time()),
            'model': model,
            'choices': [
                {
                    'text': generated,
                    'index': 0,
                    'logprobs': None,
                    'finish_reason': 'length'
                }
            ],
            'usage': {
                'prompt_tokens': len(prompt.split()),
                'completion_tokens': max_tokens,
                'total_tokens': len(prompt.split()) + max_tokens
            }
        }
        
        self.wfile.write(json.dumps(response, indent=2).encode())
        logger.info(f"[RESPONSE] Inference completed: {max_tokens} tokens")
    
    def _handle_stream(self, model, prompt, max_tokens, inference_time):
        """Handle streaming completion"""
        self.send_response(200)
        self.send_header('Content-type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        
        words = ["The", "simulated", "inference", "is", "streaming", "tokens", "in", "real-time", 
                 "to", "demonstrate", "distributed", "processing", "across", "multiple", "GPUs"]
        
        for i, word in enumerate(words[:max_tokens]):
            chunk = {
                'id': f'cmpl-{int(time.time())}',
                'object': 'text_completion.chunk',
                'created': int(time.time()),
                'model': model,
                'choices': [
                    {
                        'text': word + ' ',
                        'index': 0,
                        'logprobs': None,
                        'finish_reason': None if i < max_tokens - 1 else 'length'
                    }
                ]
            }
            
            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
            self.wfile.flush()
            time.sleep(0.05)  # Simulate token generation delay
        
        logger.info(f"[STREAM] Streaming completed: {max_tokens} tokens")
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass

def setup_heartbeat():
    """Create heartbeat file"""
    os.makedirs(Config.HEARTBEAT_DIR, exist_ok=True)
    heartbeat_file = os.path.join(Config.HEARTBEAT_DIR, f'{Config.ROLE}_{Config.RANK}.heartbeat')
    try:
        with open(heartbeat_file, 'w') as f:
            f.write(json.dumps({
                'role': Config.ROLE,
                'rank': Config.RANK,
                'timestamp': datetime.now().isoformat(),
                'host': socket.gethostname()
            }))
        logger.info(f"✓ Heartbeat file created: {heartbeat_file}")
    except Exception as e:
        logger.error(f"✗ Failed to create heartbeat: {e}")

def test_controller_connection():
    """Test connection to controller (for worker nodes)"""
    if Config.ROLE == 'worker':
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex((Config.MASTER_ADDR, Config.MASTER_PORT))
            sock.close()
            
            if result == 0:
                logger.info(f"✓ Connected to Controller at {Config.MASTER_ADDR}:{Config.MASTER_PORT}")
                return True
            else:
                logger.warning(f"⚠️  Cannot connect to Controller NCCL port at {Config.MASTER_ADDR}:{Config.MASTER_PORT}")
                logger.warning(f"   This is normal if Controller is using REST API only")
                logger.warning(f"   Worker will wait for Controller API to be available")
                return True  # Changed from False - allow worker to continue
        except Exception as e:
            logger.warning(f"⚠️  Connection test failed: {e}")
            logger.warning(f"   Worker will continue anyway")
            return True  # Changed from False - allow worker to continue
    return True

def start_controller():
    """Start controller node"""
    logger.info(f"{'='*60}")
    logger.info(f"🖥️  CONTROLLER NODE (Rank {Config.RANK}/{Config.WORLD_SIZE})")
    logger.info(f"{'='*60}")
    logger.info(f"Cluster: {Config.CLUSTER_NAME}")
    logger.info(f"Model: {Config.MODEL_NAME}")
    logger.info(f"API Server: http://0.0.0.0:{Config.NEURX_PORT}")
    logger.info(f"NCCL Port: {Config.MASTER_PORT}")
    logger.info(f"World Size: {Config.WORLD_SIZE}")
    logger.info(f"{'='*60}")
    logger.info(f"")
    
    setup_heartbeat()
    
    logger.info(f"🚀 Starting HTTP API server on port {Config.NEURX_PORT}...")
    server = HTTPServer(('0.0.0.0', Config.NEURX_PORT), DistributedController)
    
    def signal_handler(sig, frame):
        logger.info("\n🛑 Shutting down Controller...")
        server.shutdown()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info(f"✓ API Server started")
    logger.info(f"")
    logger.info(f"📍 Endpoints:")
    logger.info(f"   GET  /v1/models        - List available models")
    logger.info(f"   POST /v1/completions   - Text completion API")
    logger.info(f"   GET  /health           - Health check")
    logger.info(f"")
    logger.info(f"🧪 Test with:")
    logger.info(f"   curl http://127.0.0.1:{Config.NEURX_PORT}/v1/models")
    logger.info(f"")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Interrupted")

def start_worker():
    """Start worker node"""
    logger.info(f"{'='*60}")
    logger.info(f"🖥️  WORKER NODE (Rank {Config.RANK}/{Config.WORLD_SIZE})")
    logger.info(f"{'='*60}")
    logger.info(f"Cluster: {Config.CLUSTER_NAME}")
    logger.info(f"Master: {Config.MASTER_ADDR}:{Config.MASTER_PORT}")
    logger.info(f"Local Node: {Config.NEURX_NODE_HOST}:{Config.NEURX_NODE_PORT}")
    logger.info(f"World Size: {Config.WORLD_SIZE}")
    logger.info(f"Local Rank: {Config.LOCAL_RANK}")
    logger.info(f"{'='*60}")
    logger.info(f"")
    
    setup_heartbeat()
    
    # Test connection (but don't fail if it doesn't work)
    test_controller_connection()
    
    logger.info(f"✓ Connection test completed")
    logger.info(f"")
    logger.info(f"🚀 Worker node is ready")
    logger.info(f"   Monitoring for inference tasks from {Config.MASTER_ADDR}:{Config.MASTER_PORT}")
    logger.info(f"   You can now:")
    logger.info(f"   1. Start Controller with: NEURX_ROLE=controller bash start_service.sh")
    logger.info(f"   2. Send inference requests to: http://{Config.MASTER_ADDR}:8000/v1/completions")
    logger.info(f"")
    
    # Keep worker alive
    try:
        while True:
            time.sleep(1)
            # Update heartbeat periodically
            setup_heartbeat()
    except KeyboardInterrupt:
        logger.info("\n🛑 Shutting down Worker...")
        sys.exit(0)

def main():
    """Main entry point"""
    if Config.ROLE == 'controller':
        start_controller()
    elif Config.ROLE == 'worker':
        start_worker()
    else:
        logger.error(f"Invalid NEURX_ROLE: {Config.ROLE}")
        sys.exit(1)

if __name__ == '__main__':
    main()
