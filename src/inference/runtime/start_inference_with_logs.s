package neurx.inference.runtime.start_inference_with_logs
use std.io.{output, input}
use std.conv.{int_to_string}
extern "c" func system(string cmd) int
func main() {
    print("\n🚀 start NeurX inference系统（带日志记录）\n")
    print("════════════════════════════════════════════\n")
    print("\n")
    string neurx_dir = "/home/shuwen/shuwen/neurx"
    string log_dir = neurx_dir + "/artifact/logs"
    string gpu_backend_ir = neurx_dir + "/artifact/build/production_s_inference/gpu_backend_enhanced.ir"
    string web_ui_ir = neurx_dir + "/artifact/build/production_s_inference/web_ui_server.ir"
    string s_runner = neurx_dir + "/artifact/build/s_runner/s_ir_runner"
    string gpu_log = log_dir + "/gpu_backend.log"
    string web_log = log_dir + "/web_ui.log"
    print("⏹️  停止old进程...\n")
    system("pkill -f 's_ir_runner.*gpu_backend' 2>/dev/null || true")
    system("pkill -f 's_ir_runner.*web_ui' 2>/dev/null || true")
    system("sleep 1")
    print("📁 创建日志目录...\n")
    system("mkdir -p " + log_dir)
    print("\n")
    print("🎯 start GPU inferencebackend...\n")
    print("   start进程: " + s_runner + "\n")
    print("   IR 文piece: " + gpu_backend_ir + "\n")
    print("   输出日志: " + gpu_log + "\n")
    string gpu_cmd = "nohup '" + s_runner + "' '" + gpu_backend_ir + "' >> '" + gpu_log + "' 2>&1 &"
    system(gpu_cmd)
    system("sleep 2")
    print("   ✓ GPU backendstart\n")
    print("   📍 地址: http:
    print("\n")
    print("🎯 start Web UI server...\n")
    print("   start进程: " + s_runner + "\n")
    print("   IR 文piece: " + web_ui_ir + "\n")
    print("   输出日志: " + web_log + "\n")
    string web_cmd = "nohup '" + s_runner + "' '" + web_ui_ir + "' >> '" + web_log + "' 2>&1 &"
    system(web_cmd)
    system("sleep 2")
    print("   ✓ Web UI start\n")
    print("   📍 地址: http:
    print("\n")
    print("════════════════════════════════════════════\n")
    print("✅ 服务startcomplete！\n")
    print("\n")
    print("📋 查看日志:\n")
    print("   make log          # 查看 GPU backend日志（最back 50 do）\n")
    print("   make log-gpu      # 实时查看 GPU backend\n")
    print("   make log-web      # 实时查看 Web UI\n")
    print("   make log-tail     # 并排显示all日志\n")
    print("   make logs         # 列出all日志文piece\n")
    print("\n")
    print("🔗 访问服务:\n")
    print("   - GPU inference: http:
    print("   - Web UI:   http:
    print("\n")
}
