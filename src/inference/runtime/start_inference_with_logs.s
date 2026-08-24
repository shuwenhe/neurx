package neurx.inference.runtime.start_inference_with_logs

use std.io.{output, input}
use std.conv.{int_to_string}

extern "c" func system(string cmd) int

func main() {
    print("\n🚀 启动 NeurX 推理系统（带日志记录）\n")
    print("════════════════════════════════════════════\n")
    print("\n")
    
    string neurx_dir = "/home/shuwen/shuwen/neurx"
    string log_dir = neurx_dir + "/artifact/logs"
    string gpu_backend_ir = neurx_dir + "/artifact/build/production_s_inference/gpu_backend_enhanced.ir"
    string web_ui_ir = neurx_dir + "/artifact/build/production_s_inference/web_ui_server.ir"
    string s_runner = neurx_dir + "/artifact/build/s_runner/s_ir_runner"
    string gpu_log = log_dir + "/gpu_backend.log"
    string web_log = log_dir + "/web_ui.log"
    
    print("⏹️  停止旧进程...\n")
    system("pkill -f 's_ir_runner.*gpu_backend' 2>/dev/null || true")
    system("pkill -f 's_ir_runner.*web_ui' 2>/dev/null || true")
    system("sleep 1")
    
    print("📁 创建日志目录...\n")
    system("mkdir -p " + log_dir)
    
    print("\n")
    print("🎯 启动 GPU 推理后端...\n")
    print("   启动进程: " + s_runner + "\n")
    print("   IR 文件: " + gpu_backend_ir + "\n")
    print("   输出日志: " + gpu_log + "\n")
    
    string gpu_cmd = "nohup '" + s_runner + "' '" + gpu_backend_ir + "' >> '" + gpu_log + "' 2>&1 &"
    system(gpu_cmd)
    system("sleep 2")
    
    print("   ✓ GPU 后端启动\n")
    print("   📍 地址: http://127.0.0.1:18084\n")
    
    print("\n")
    print("🎯 启动 Web UI 服务器...\n")
    print("   启动进程: " + s_runner + "\n")
    print("   IR 文件: " + web_ui_ir + "\n")
    print("   输出日志: " + web_log + "\n")
    
    string web_cmd = "nohup '" + s_runner + "' '" + web_ui_ir + "' >> '" + web_log + "' 2>&1 &"
    system(web_cmd)
    system("sleep 2")
    
    print("   ✓ Web UI 启动\n")
    print("   📍 地址: http://127.0.0.1:8081\n")
    
    print("\n")
    print("════════════════════════════════════════════\n")
    print("✅ 服务启动完成！\n")
    print("\n")
    print("📋 查看日志:\n")
    print("   make log          # 查看 GPU 后端日志（最后 50 行）\n")
    print("   make log-gpu      # 实时查看 GPU 后端\n")
    print("   make log-web      # 实时查看 Web UI\n")
    print("   make log-tail     # 并排显示所有日志\n")
    print("   make logs         # 列出所有日志文件\n")
    print("\n")
    print("🔗 访问服务:\n")
    print("   - GPU 推理: http://127.0.0.1:18084/v1/generate\n")
    print("   - Web UI:   http://127.0.0.1:8081\n")
    print("\n")
}

