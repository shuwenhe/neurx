#!/bin/bash

echo "=== LMCache Phase 1 Integration Test ==="
echo ""

BACKEND_URL="http://127.0.0.1:8888/v1/chat/completions"
PROXY_URL="http://8.140.241.141:8080/neurx/v1/chat/completions"

test_cache_system() {
    local test_name=$1
    local prompt=$2
    local url=$3
    
    echo "Test: $test_name"
    echo "  Prompt: $prompt"
    echo "  URL: $url"
    echo ""
    
    response=$(curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"Qwen2.5-0.5B-Instruct\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"max_tokens\": 50,
            \"stream\": false
        }" \
        2>&1 | tee /tmp/test_response.json)
    
    echo "Response (first 200 chars):"
    echo "$response" | head -c 200
    echo ""
    echo ""
    
    if echo "$response" | grep -q "error"; then
        echo "❌ Test failed: Error in response"
        return 1
    fi
    
    if echo "$response" | grep -q "content"; then
        echo "✅ Test passed: Response contains content"
        
        if echo "$response" | grep -q "LMCache\|cache"; then
            echo "✅ Cache metrics detected in response"
        fi
        return 0
    fi
    
    echo "⚠️  Test inconclusive: Response format unclear"
    return 2
}

echo "Testing with backend direct URL (127.0.0.1:8888):"
echo "=================================================="
test_cache_system "First Request (Cache Miss)" \
    "Write a simple C++ program" \
    "$BACKEND_URL"

sleep 2

echo "Testing second request (should hit cache if prefix matches):"
test_cache_system "Second Request (Cache Potential Hit)" \
    "Write a simple C++ program" \
    "$BACKEND_URL"

sleep 2

echo ""
echo "Testing with proxy (8.140.241.141:8080):"
echo "=========================================="
test_cache_system "Proxy Request via Nginx" \
    "Implement a Python function" \
    "$PROXY_URL"

echo ""
echo "=== Integration Test Complete ==="
echo "Expected behavior:"
echo "  1. First request: Cache miss, full inference"
echo "  2. Second identical request: Cache hit if implemented"
echo "  3. Proxy request: Should route correctly through Nginx"
echo ""
echo "Check backend logs for cache statistics:"
echo "  - [CacheIndex] Hit/Miss messages"
echo "  - [KVCacheEngine] Allocation and eviction logs"
echo "  - Cache hit rate statistics"
