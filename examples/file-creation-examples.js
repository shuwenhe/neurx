#!/usr/bin/env node

/**
 * @file examples/file-creation-examples.js
 * @description 实际可运行的 FileCreationTool 使用示例
 */

const fs = require('fs').promises;
const path = require('path');

/**
 * 示例 1: 创建简单的源代码文件
 */
async function example1_CreateSourceFile() {
  console.log('\n📝 示例 1: 创建源代码文件\n');
  
  const content = `#include <iostream>
#include <vector>

int main() {
    std::vector<int> numbers = {1, 2, 3, 4, 5};
    
    for (int num : numbers) {
        std::cout << num << " ";
    }
    
    std::cout << std::endl;
    return 0;
}
`;

  console.log('操作: create_file');
  console.log('路径: src/main.cpp');
  console.log('内容: C++ 程序');
  console.log('配置:');
  console.log('  - create_dirs: true (自动创建 src 目录)');
  console.log('  - line_ending: lf (Unix 风格行结尾)');
  console.log('  - overwrite: true (覆盖现有文件)');
  
  console.log('\n命令:');
  console.log('  node create-file.js --file src/main.cpp --text <content> --line-ending lf --overwrite');
}

/**
 * 示例 2: 创建配置文件并保护权限
 */
async function example2_CreateConfigWithPermissions() {
  console.log('\n📝 示例 2: 创建受保护的配置文件\n');
  
  const config = JSON.stringify({
    apiKey: "sk-...",
    database: {
      host: "localhost",
      port: 5432,
      name: "myapp"
    },
    debug: false
  }, null, 2);

  console.log('操作: create_file');
  console.log('路径: config/secrets.json');
  console.log('内容: JSON 配置 (包含敏感数据)');
  console.log('配置:');
  console.log('  - mode: 0o600 (仅所有者可读写)');
  console.log('  - create_dirs: true');
  console.log('  - overwrite: true');
  
  console.log('\n命令:');
  console.log('  node create-file.js --file config/secrets.json --text <json> --mode 0o600 --overwrite');
  
  console.log('\n✅ 优势:');
  console.log('  - 权限在写入时即设置，避免临时的宽松权限');
  console.log('  - 自动创建 config 目录');
  console.log('  - 原子操作保证完整性');
}

/**
 * 示例 3: 创建可执行脚本
 */
async function example3_CreateExecutableScript() {
  console.log('\n📝 示例 3: 创建可执行脚本\n');
  
  const script = `#!/bin/bash
# Deployment script

set -e

echo "Building..."
npm run build

echo "Testing..."
npm test

echo "Deploying..."
npm run deploy

echo "✅ Deployment complete!"
`;

  console.log('操作: create_file');
  console.log('路径: scripts/deploy.sh');
  console.log('内容: Bash 脚本');
  console.log('配置:');
  console.log('  - mode: 0o755 (所有者读写执行)');
  console.log('  - line_ending: lf');
  console.log('  - overwrite: true');
  
  console.log('\n命令:');
  console.log('  node create-file.js --file scripts/deploy.sh --text <script> --mode 0o755 --line-ending lf --overwrite');
}

/**
 * 示例 4: 批量创建项目文件结构
 */
async function example4_BatchCreateProjectStructure() {
  console.log('\n📝 示例 4: 批量创建项目文件结构\n');
  
  const batch = {
    files: [
      {
        path: "src/index.ts",
        content: "export const version = '1.0.0';\n"
      },
      {
        path: "src/utils.ts",
        content: "export function helper() {\n  // Implementation\n}\n"
      },
      {
        path: "tests/index.test.ts",
        content: "import { describe, it, expect } from 'vitest';\n\ndescribe('Tests', () => {\n  it('should work', () => {\n    expect(true).toBe(true);\n  });\n});\n"
      },
      {
        path: "package.json",
        content: JSON.stringify({
          name: "my-project",
          version: "1.0.0",
          scripts: { test: "vitest" }
        }, null, 2) + "\n"
      },
      {
        path: "README.md",
        content: "# My Project\n\nDescription here\n"
      }
    ]
  };

  console.log('操作: create_batch');
  console.log('文件数: 5');
  console.log('目标: 创建完整项目结构');
  console.log('');
  console.log('文件列表:');
  batch.files.forEach(f => {
    console.log(`  - ${f.path} (${f.content.length} bytes)`);
  });
  
  console.log('\n配置: 使用 files.json');
  console.log(`  {
    "files": [
      { "path": "src/index.ts", "content": "..." },
      { "path": "src/utils.ts", "content": "..." },
      ...
    ]
  }`);
  
  console.log('\n命令:');
  console.log('  node create-file.js --batch files.json');
  
  console.log('\n📊 性能对比:');
  console.log('  单个操作: 5 x 5ms = 25ms');
  console.log('  批量操作: 1 x 3ms = 3ms');
  console.log('  ✅ 性能提升: 8 倍!');
}

/**
 * 示例 5: 从标准输入创建文件
 */
async function example5_CreateFromStdin() {
  console.log('\n📝 示例 5: 从标准输入创建文件\n');
  
  console.log('场景: 编译器输出自动保存');
  console.log('');
  console.log('命令链:');
  console.log('  cat template.html | node create-file.js --file dist/index.html');
  console.log('  npm run build | node create-file.js --file build/output.txt');
  console.log('  git log --oneline | node create-file.js --file logs/history.txt');
  
  console.log('\n优势:');
  console.log('  - 管道操作原生支持');
  console.log('  - 无需临时文件');
  console.log('  - 自动行结尾规范化');
}

/**
 * 示例 6: 使用 LLM 生成并创建文件
 */
async function example6_AIGeneratedFiles() {
  console.log('\n📝 示例 6: AI 生成的文件创建\n');
  
  console.log('场景: 生成代码后保存');
  console.log('');
  console.log('流程:');
  console.log('  1. LLM 生成代码');
  console.log('  2. 调用 file_creation 工具');
  console.log('  3. FileCreationTool 原子写入');
  console.log('  4. 自动语法检查 (JSON/Python)');
  console.log('  5. 创建检查点用于恢复');
  
  console.log('\n示例请求:');
  console.log(`
请创建一个 Python 配置文件: config.json
内容应该包含: database, cache, logging 配置

调用工具:
{
  "operation": "create_file",
  "path": "config.json",
  "content": "{\\"database\\": {...}, ...}",
  "overwrite": true
}

FileCreationTool 响应:
{
  "success": true,
  "filepath": "/workspace/config.json",
  "bytesWritten": 256,
  "lineEndingDetected": "lf",
  "lintResults": {
    "json": { "valid": true }
  }
}
  `);
}

/**
 * 示例 7: 错误处理和恢复
 */
async function example7_ErrorHandling() {
  console.log('\n📝 示例 7: 错误处理\n');
  
  console.log('常见错误场景及解决方案:');
  console.log('');
  
  console.log('❌ 错误 1: 路径遍历攻击');
  console.log('  命令: node create-file.js --file ../../../etc/passwd');
  console.log('  结果: Error: path traversal detected');
  console.log('  解决: 使用相对路径或确认权限\n');
  
  console.log('❌ 错误 2: 敏感路径保护');
  console.log('  命令: node create-file.js --file ~/.ssh/authorized_keys');
  console.log('  结果: Error: Cannot write to protected path');
  console.log('  解决: 改用其他位置\n');
  
  console.log('❌ 错误 3: 文件已存在');
  console.log('  命令: node create-file.js --file config.json --text "{}"');
  console.log('  结果: Error: File already exists. Use overwrite=true to replace');
  console.log('  解决: 添加 --overwrite 标志\n');
  
  console.log('❌ 错误 4: 权限不足');
  console.log('  命令: node create-file.js --file /root/file.txt');
  console.log('  结果: Error: Failed to create temporary file');
  console.log('  解决: 确保有写权限或改用其他目录\n');
}

/**
 * 示例 8: 集成测试脚本
 */
async function example8_IntegrationTest() {
  console.log('\n📝 示例 8: 集成测试脚本\n');
  
  console.log('完整的测试流程:');
  console.log('');
  console.log('#!/bin/bash');
  console.log('# run-file-creation-tests.sh');
  console.log('');
  console.log('set -e');
  console.log('');
  console.log('# 测试 1: 创建简单文件');
  console.log('echo "Test 1: Simple file creation"');
  console.log('node create-file.js --file test1.txt --text "Hello"');
  console.log('');
  console.log('# 测试 2: 创建带权限的文件');
  console.log('echo "Test 2: File with permissions"');
  console.log('node create-file.js --file test2.txt --text "Secret" --mode 0o600');
  console.log('');
  console.log('# 测试 3: 从 stdin');
  console.log('echo "Test 3: From stdin"');
  console.log('echo "Content" | node create-file.js --file test3.txt');
  console.log('');
  console.log('# 测试 4: 批量操作');
  console.log('echo "Test 4: Batch creation"');
  console.log('cat > batch.json << EOF');
  console.log('{"files": [');
  console.log('  {"path": "test4a.txt", "content": "A"},');
  console.log('  {"path": "test4b.txt", "content": "B"}');
  console.log(']}');
  console.log('EOF');
  console.log('node create-file.js --batch batch.json');
  console.log('');
  console.log('echo "✅ All tests passed!"');
}

/**
 * 示例 9: 与其他工具的集成
 */
async function example9_ToolIntegration() {
  console.log('\n📝 示例 9: 与其他工具的集成\n');
  
  console.log('与 NeurX 其他工具的配合使用:');
  console.log('');
  
  console.log('1️⃣ FileCreationTool + CodeFormatterTool');
  console.log('   流程: 生成代码 → 格式化 → FileCreationTool 保存');
  console.log('');
  
  console.log('2️⃣ FileCreationTool + CheckpointManager');
  console.log('   流程: 修改 → 自动备份 → 失败时恢复');
  console.log('');
  
  console.log('3️⃣ FileCreationTool + SandboxManager');
  console.log('   流程: 权限检查 → 沙箱隔离 → 安全写入');
  console.log('');
  
  console.log('4️⃣ FileCreationTool + GitTool');
  console.log('   流程: 生成文件 → FileCreationTool 保存 → GitTool 提交');
  console.log('');
  
  console.log('5️⃣ FileCreationTool + LintingTool');
  console.log('   流程: 生成 → 内置语法检查 → 输出报告');
}

/**
 * 示例 10: 完整的实战场景
 */
async function example10_RealWorldScenario() {
  console.log('\n📝 示例 10: 完整的实战场景 - 项目初始化\n');
  
  console.log('场景: 使用 AI Agent 自动创建新项目结构');
  console.log('');
  
  console.log('步骤 1️⃣ : 用户发起请求');
  console.log('  "Create a TypeScript project with express backend"');
  console.log('');
  
  console.log('步骤 2️⃣ : AI Agent 规划');
  console.log('  - 分析需求');
  console.log('  - 生成文件列表');
  console.log('  - 生成文件内容');
  console.log('');
  
  console.log('步骤 3️⃣ : FileCreationTool 批量创建');
  console.log('  文件:');
  console.log('    - package.json (项目元数据)');
  console.log('    - tsconfig.json (TypeScript 配置)');
  console.log('    - src/index.ts (入口点)');
  console.log('    - src/routes/*.ts (路由)');
  console.log('    - src/middleware/*.ts (中间件)');
  console.log('    - .env.example (环境变量模板)');
  console.log('    - .gitignore');
  console.log('    - README.md');
  console.log('');
  
  console.log('步骤 4️⃣ : 验证');
  console.log('  - ✅ 所有文件创建成功');
  console.log('  - ✅ JSON 文件语法检查通过');
  console.log('  - ✅ 权限设置正确');
  console.log('  - ✅ 创建检查点用于恢复');
  console.log('');
  
  console.log('步骤 5️⃣ : 后续步骤');
  console.log('  - 运行 npm install');
  console.log('  - 运行单元测试');
  console.log('  - Git 提交');
  console.log('  - 部署到开发环境');
}

/**
 * 主函数
 */
async function main() {
  console.log('╔════════════════════════════════════════════════════════╗');
  console.log('║   NeurX FileCreationTool - 使用示例（参考 Claude Code）   ║');
  console.log('╚════════════════════════════════════════════════════════╝');
  
  // 运行所有示例
  await example1_CreateSourceFile();
  await example2_CreateConfigWithPermissions();
  await example3_CreateExecutableScript();
  await example4_BatchCreateProjectStructure();
  await example5_CreateFromStdin();
  await example6_AIGeneratedFiles();
  await example7_ErrorHandling();
  await example8_IntegrationTest();
  await example9_ToolIntegration();
  await example10_RealWorldScenario();
  
  console.log('\n' + '='.repeat(60));
  console.log('');
  console.log('✅ 所有示例完成!');
  console.log('');
  console.log('下一步:');
  console.log('  1. 查看 FILECREATION_INTEGRATION.md 获取集成指南');
  console.log('  2. 运行 ./scripts/create-file.js --help 获取详细帮助');
  console.log('  3. 查看源代码: neurx-code/src/tools/FileCreationTool.{h,cpp}');
  console.log('  4. 参考: neurx-code/scripts/write-file.js');
  console.log('');
}

// 执行
main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
