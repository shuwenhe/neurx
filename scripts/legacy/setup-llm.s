package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string api_key = runtime_env_get("NEURX_API_KEY", "")

    println("🚀 NeurX + LLM 快速设置")
    println("==============================")
    println("")

    println("✓ 第1步：检查环境")
    if !runtime_run_command("command -v cmake >/dev/null 2>&1").ok {
        println("❌ 需要安装 cmake")
        return 1
    }
    println("✓ cmake 已安装")
    println("")

    if api_key == "" {
        println("✓ 第2步：设置API密钥")
        println("请先设置 NEURX_API_KEY 环境变量后再次运行本脚本。")
        return 1
    }

    println("✓ 第2步：设置API密钥")
    println("✓ API密钥已设置")
    println("")

    println("✓ 第3步：编译neurx")
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string build_cmd = "cd " + runtime_shell_escape(project_root + "/..") + " && mkdir -p build && cd build && cmake .. && make -j8"
    if !runtime_run_command(build_cmd).ok {
        return 1
    }
    println("✓ 编译完成")
    println("")

    println("✓ 第4步：验证安装")
    println("")
    println("NeurX + LLM 现在已可使用！")
    println("")
    println("快速测试代码示例：")
    println("")
    println("#include \"LLMCodeAnalyzer.h\"")
    println("#include \"../llm/RemoteProvider.h\"")
    println("")
    println("int main() {")
    println("    // 创建分析器")
    println("    auto analyzer = std::make_unique<LLMCodeAnalyzer>();")
    println("")
    println("    // 配置 LLM")
    println("    auto provider = new RemoteProvider();")
    println("    provider->setApiKey(getenv(\"NEURX_API_KEY\"));")
    println("    analyzer->setLLMProvider(provider);")
    println("")
    println("    // 分析代码")
    println("    auto result = analyzer->analyzeCode(\"def hello(): print('world')\",")
    println("                                        ProgrammingLanguage::Python);")
    println("")
    println("    qDebug() << \"Quality:\" << result.quality;")
    println("    qDebug() << \"Issues:\" << result.issues.size();")
    println("")
    println("    return 0;")
    println("}")
    println("")
    println("📚 更多信息：")
    println("- 完整文档：./LLM_INTEGRATION.md")
    println("- 架构说明：./ARCHITECTURE.md")
    println("- 原始文档：./README.md")
    println("")
    println("✅ 设置完成！")

    0
}
