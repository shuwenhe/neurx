package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string api_key = runtime_env_get("NEURX_API_KEY", "")
    println("🚀 NeurX + LLM quickEnglish text")
    println("==============================")
    println("")
    println("✓ English text1step: English text")
    if !runtime_run_command("command -v cmake >/dev/null 2>&1").ok {
        println("❌ RequiredEnglish text cmake")
        return 1
    }
    println("✓ cmake English text")
    println("")
    if api_key == "" {
        println("✓ English text2step: English textAPIEnglish text")
        println("English text NEURX_API_KEY English textrunEnglish text.")
        return 1
    }
    println("✓ English text2step: English textAPIEnglish text")
    println("✓ APIEnglish text")
    println("")
    println("✓ English text3step: compileneurx")
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string build_cmd = "cd " + runtime_shell_escape(project_root + "/..") + " && mkdir -p build && cd build && cmake .. && make -j8"
    if !runtime_run_command(build_cmd).ok {
        return 1
    }
    println("✓ compileEnglish text")
    println("")
    println("✓ English text4step: English text")
    println("")
    println("NeurX + LLM English textuse!")
    println("")
    println("quicktestEnglish textexample: ")
    println("")
    println("#include \"LLMCodeAnalyzer.h\"")
    println("#include \"../llm/RemoteProvider.h\"")
    println("")
    println("int main() {")
    println("
    println("    auto analyzer = std::make_unique<LLMCodeAnalyzer>();")
    println("")
    println("
    println("    auto provider = new RemoteProvider();")
    println("    provider->setApiKey(getenv(\"NEURX_API_KEY\"));")
    println("    analyzer->setLLMProvider(provider);")
    println("")
    println("
    println("    auto result = analyzer->analyzeCode(\"def hello(): print('world')\",")
    println("                                        ProgrammingLanguage::Python);")
    println("")
    println("    qDebug() << \"Quality:\" << result.quality;")
    println("    qDebug() << \"Issues:\" << result.issues.size();")
    println("")
    println("    return 0;")
    println("}")
    println("")
    println("📚 English textinformation: ")
    println("- completeEnglish text: ./LLM_INTEGRATION.md")
    println("- English textexplanation: ./ARCHITECTURE.md")
    println("- English text: ./README.md")
    println("")
    println("✅ English text!")
    0
}
