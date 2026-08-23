#!/usr/bin/env python3
"""
临时 Mock API - 用于演示前端功能
实际的 S 语言推理引擎推理失败，这个 mock 提供测试响应
"""

import socket
import json
import time
from threading import Thread

class MockChatAPI:
    def __init__(self, port=8001):
        self.port = port
        self.responses = {
            "你好": "你好！我是 NeurX AI 助手。我是一个基于 Qwen2.5-0.5B-Instruct 模型的对话系统。有什么我可以帮助你的吗？",
            "介绍一下自己": "我是 NeurX，一个由纯 S 语言实现的开源 AI 推理引擎。我专门针对边缘设备和生产环境优化，提供高效的推理能力。",
            "你是谁": "我是 NeurX AI 助手，由 S 语言编写的推理引擎驱动。我可以进行对话、回答问题和提供帮助。",
            "hello": "Hello! I'm NeurX AI Assistant. I'm a conversational system based on the Qwen2.5-0.5B-Instruct model. How can I help you?",
        }
        self.default_response = "这是 Mock 模式的响应。实际的推理引擎目前在 Prefill 阶段遇到问题，需要调试 S 语言运行时。"
    
    def get_response(self, user_message: str) -> str:
        """获取模拟响应"""
        for key, response in self.responses.items():
            if key.lower() in user_message.lower():
                return response
        return self.default_response
    
    def handle_request(self, request_data):
        """处理聊天请求"""
        try:
            body = json.loads(request_data)
            messages = body.get("messages", [])
            if messages:
                user_msg = messages[-1].get("content", "")
                response_text = self.get_response(user_msg)
            else:
                response_text = self.default_response
            
            response = {
                "id": "chatcmpl-mock-" + str(int(time.time())),
                "object": "chat.completion",
                "created": int(time.time()),
                "model": "mock-qwen-0.5b",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": response_text
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": len(user_msg.split()),
                    "completion_tokens": len(response_text.split()),
                    "total_tokens": len(user_msg.split()) + len(response_text.split())
                }
            }
            return json.dumps(response)
        except Exception as e:
            error_response = {
                "error": str(e),
                "message": "处理请求出错"
            }
            return json.dumps(error_response)
    
    def start(self):
        """启动 Mock API 服务器"""
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind(('127.0.0.1', self.port))
        server_socket.listen(1)
        print(f"Mock API 服务器运行在 http://127.0.0.1:{self.port}")
        
        while True:
            client_socket, addr = server_socket.accept()
            Thread(target=self.handle_client, args=(client_socket,), daemon=True).start()
    
    def handle_client(self, client_socket):
        """处理单个客户端连接"""
        try:
            request = client_socket.recv(4096).decode()
            
            if "POST /v1/chat/completions" in request:
                # 提取请求体
                parts = request.split('\r\n\r\n', 1)
                if len(parts) > 1:
                    body = parts[1]
                    response_text = self.handle_request(body)
                    
                    http_response = (
                        "HTTP/1.1 200 OK\r\n"
                        "Content-Type: application/json; charset=utf-8\r\n"
                        f"Content-Length: {len(response_text)}\r\n"
                        "Connection: close\r\n"
                        "\r\n"
                        f"{response_text}"
                    )
                    client_socket.sendall(http_response.encode())
            elif "/health" in request:
                health_response = json.dumps({
                    "status": "ok",
                    "backend": "mock-cpu",
                    "mode": "demo"
                })
                http_response = (
                    "HTTP/1.1 200 OK\r\n"
                    "Content-Type: application/json\r\n"
                    f"Content-Length: {len(health_response)}\r\n"
                    "Connection: close\r\n"
                    "\r\n"
                    f"{health_response}"
                )
                client_socket.sendall(http_response.encode())
        except Exception as e:
            print(f"错误: {e}")
        finally:
            client_socket.close()

if __name__ == "__main__":
    api = MockChatAPI(port=8001)
    api.start()
