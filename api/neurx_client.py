#!/usr/bin/env python3
"""
NeurX API Client - Test and interact with NeurX API Server
"""

import sys
import json
import requests
import argparse
from datetime import datetime
from typing import Optional, List

class NeurXAPIClient:
    """Client for NeurX API Server"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "User-Agent": "NeurX-CLI/1.0"
        })
    
    def health_check(self) -> dict:
        """Check server health"""
        try:
            response = self.session.get(f"{self.base_url}/health")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"error": str(e)}
    
    def list_models(self) -> dict:
        """List available models"""
        try:
            response = self.session.get(f"{self.base_url}/v1/models")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"error": str(e)}
    
    def chat_completion(
        self,
        messages: List[dict],
        model: str = "Qwen2.5-0.5B-Instruct",
        max_tokens: int = 128,
        temperature: float = 0.7,
        stream: bool = False
    ) -> dict:
        """Chat completion"""
        payload = {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": stream
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"error": str(e)}
    
    def simple_chat(self, user_message: str, **kwargs) -> Optional[str]:
        """Simple chat interface"""
        response = self.chat_completion(
            messages=[{"role": "user", "content": user_message}],
            **kwargs
        )
        
        if "error" in response:
            print(f"❌ Error: {response['error']}")
            return None
        
        try:
            return response["choices"][0]["message"]["content"]
        except (KeyError, IndexError):
            return None

def print_response(response: dict, title: str = "Response"):
    """Pretty print response"""
    print(f"\n{'=' * 70}")
    print(f"{title}")
    print(f"{'=' * 70}")
    print(json.dumps(response, indent=2, ensure_ascii=False))
    print()

def main():
    parser = argparse.ArgumentParser(
        description="NeurX API Client",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Health check
  %(prog)s --health
  
  # List models
  %(prog)s --models
  
  # Simple chat
  %(prog)s --chat "What is AI?"
  
  # Chat with custom parameters
  %(prog)s --chat "Explain quantum computing" --max-tokens 256 --temperature 0.5
  
  # Interactive mode
  %(prog)s --interactive
        """
    )
    
    parser.add_argument("--url", default="http://localhost:8000",
                        help="API server URL (default: http://localhost:8000)")
    parser.add_argument("--health", action="store_true",
                        help="Check server health")
    parser.add_argument("--models", action="store_true",
                        help="List available models")
    parser.add_argument("--chat", type=str,
                        help="Send chat message")
    parser.add_argument("--interactive", "-i", action="store_true",
                        help="Interactive chat mode")
    parser.add_argument("--max-tokens", type=int, default=128,
                        help="Maximum tokens in response (default: 128)")
    parser.add_argument("--temperature", type=float, default=0.7,
                        help="Temperature for sampling (default: 0.7)")
    parser.add_argument("--model", default="Qwen2.5-0.5B-Instruct",
                        help="Model to use")
    
    args = parser.parse_args()
    
    # Initialize client
    client = NeurXAPIClient(args.url)
    
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║          NeurX API Client                                      ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print(f"\n📡 Server: {args.url}\n")
    
    # Health check
    if args.health:
        print("🏥 Checking server health...")
        response = client.health_check()
        print_response(response, "Health Check")
        return
    
    # List models
    if args.models:
        print("📚 Listing available models...")
        response = client.list_models()
        print_response(response, "Available Models")
        return
    
    # Single chat
    if args.chat:
        print(f"💬 Sending message: {args.chat}")
        response = client.chat_completion(
            messages=[{"role": "user", "content": args.chat}],
            model=args.model,
            max_tokens=args.max_tokens,
            temperature=args.temperature
        )
        
        if "error" in response:
            print(f"❌ Error: {response['error']}")
        else:
            print_response(response, "Chat Completion Response")
            content = response["choices"][0]["message"]["content"]
            print("\n📝 Assistant Response:")
            print("-" * 70)
            print(content)
            print("-" * 70)
        return
    
    # Interactive mode
    if args.interactive:
        print("💬 Entering interactive mode (type 'exit' to quit)\n")
        while True:
            try:
                user_input = input("You: ").strip()
                if not user_input:
                    continue
                if user_input.lower() in ["exit", "quit", "q"]:
                    print("👋 Goodbye!")
                    break
                
                print("\n🤔 Thinking...", end="", flush=True)
                response = client.simple_chat(
                    user_input,
                    model=args.model,
                    max_tokens=args.max_tokens,
                    temperature=args.temperature
                )
                
                if response:
                    print("\r" + " " * 50 + "\r", end="")  # Clear "Thinking..." line
                    print(f"Assistant: {response}\n")
                else:
                    print("\n❌ Failed to get response\n")
            
            except KeyboardInterrupt:
                print("\n\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"\n❌ Error: {e}\n")
        
        return
    
    # Default: show help
    parser.print_help()

if __name__ == "__main__":
    main()
