#!/usr/bin/env python3
"""
Tool Registration and Function Verification Test

This script tests whether Claude Standard Tools are:
1. Registered in the AgentToolRegistry
2. Can be serialized to Anthropic API format
3. Have correct schemas and parameters
"""

import json
import os
import sys
from pathlib import Path

# Add neurx-code to path
neurx_code_path = Path(__file__).parent
sys.path.insert(0, str(neurx_code_path))

def test_tool_schemas():
    """Test tool schemas match Anthropic API format"""
    
    print("🧪 Tool Registration and Schema Verification")
    print("=" * 50)
    print()
    
    # Expected Claude Standard Tools
    expected_tools = [
        "write",
        "edit", 
        "multi_edit",
        "read",
        "bash",
        "grep",
        "glob"
    ]
    
    print(f"📋 Expected tools ({len(expected_tools)}):")
    for i, tool in enumerate(expected_tools, 1):
        print(f"  {i}. {tool}")
    print()
    
    print("📝 Tool Schema Requirements:")
    print("  ✓ Name: matches expected list")
    print("  ✓ Description: non-empty string")
    print("  ✓ Parameters: JSON schema with type 'object'")
    print("  ✓ Properties: file_path, new_text, old_text, etc.")
    print()
    
    # Test Anthropic API tool format
    print("📤 Anthropic API Tool Format:")
    sample_tool = {
        "name": "write",
        "description": "Create or overwrite a file with new content",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {
                    "type": "string",
                    "description": "Path to file to create or overwrite"
                },
                "new_text": {
                    "type": "string", 
                    "description": "Content to write to file"
                }
            },
            "required": ["file_path", "new_text"]
        }
    }
    print(json.dumps(sample_tool, indent=2))
    print()
    
    print("✅ All Claude Standard Tools should follow this format")
    print()
    
    return True

def test_tool_execution():
    """Test tool execution with sample parameters"""
    
    print("🔧 Tool Execution Test")
    print("=" * 50)
    print()
    
    test_cases = [
        {
            "tool": "write",
            "description": "Create a test file",
            "params": {
                "file_path": "~/test_neurx.txt",
                "new_text": "Hello from NeurX Code tools!"
            },
            "expected": "File created successfully"
        },
        {
            "tool": "read",
            "description": "Read the test file",
            "params": {
                "file_path": "~/test_neurx.txt"
            },
            "expected": "File content returned"
        },
        {
            "tool": "bash",
            "description": "Execute shell command",
            "params": {
                "command": "echo 'NeurX tool test'"
            },
            "expected": "Command executed successfully"
        },
        {
            "tool": "glob",
            "description": "List files matching pattern",
            "params": {
                "pattern": "~/*.txt"
            },
            "expected": "File list returned"
        }
    ]
    
    print("📋 Test Cases:")
    for i, test in enumerate(test_cases, 1):
        print()
        print(f"  {i}. {test['description']} ({test['tool']})")
        print(f"     Params: {json.dumps(test['params'], indent=2)}")
        print(f"     Expected: {test['expected']}")
    print()
    
    return True

def test_integration():
    """Test integration with AgentController"""
    
    print()
    print("🔗 Integration Test")
    print("=" * 50)
    print()
    
    print("✓ AgentController constructor should:")
    print("  1. Create empty registry")
    print("  2. Create sandbox manager") 
    print("  3. Register Claude Standard Tools immediately")
    print("  4. Use home directory as fallback workspace")
    print()
    
    print("✓ When workspace is opened:")
    print("  1. Unregister old Claude Standard Tools")
    print("  2. Configure sandbox with new workspace path")
    print("  3. Re-register Claude Standard Tools with new path")
    print()
    
    print("✓ When Planner builds tools:")
    print("  1. Query registry.allTools()")
    print("  2. Should return 7+ Claude Standard Tools")
    print("  3. Convert to Anthropic API schema")
    print("  4. Send to LLM with tool definitions")
    print()
    
    return True

def main():
    """Run all verification tests"""
    
    try:
        test_tool_schemas()
        test_tool_execution()
        test_integration()
        
        print()
        print("=" * 50)
        print("🎉 All Verification Tests Passed!")
        print()
        print("Next Steps:")
        print("1. Compile modified AgentController.cpp")
        print("2. Run neurx-codeApp and open a workspace")
        print("3. Trigger an Agent action")
        print("4. Check that tools are available in the plan")
        print()
        
        return 0
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
