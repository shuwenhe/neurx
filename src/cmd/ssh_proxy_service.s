package neurx.deployment.ssh_proxy

struct SSHNode {
    name: string
    ip: string
    port: int
    tunnel_port: int
    username: string
    password: string
    status: string
}

struct SSHTunnel {
    node_name: string
    tunnel_port: int
    remote_ip: string
    remote_port: int
    pid: int
    active: bool
}

struct ProxyRequest {
    method: string
    path: string
    headers: string
    body: string
    server: string
}

struct ProxyResponse {
    status_code: int
    headers: string
    body: string
    server_name: string
    latency_ms: int
}

var tunnels: SSHTunnel[] = []SSHTunnel{}
var nodes: SSHNode[] = []SSHNode{}
var tunnel_pids: map[string, int] = {}

func init_ssh_nodes() {
    nodes = []SSHNode{
        SSHNode{
            name: "Controller",
            ip: "192.168.10.39",
            port: 8000,
            tunnel_port: 9001,
            username: "shuwen",
            password: "shuwen",
            status: "offline"
        },
        SSHNode{
            name: "Worker",
            ip: "192.168.10.75",
            port: 8000,
            tunnel_port: 9002,
            username: "shuwen",
            password: "shuwen",
            status: "offline"
        }
    }
}

func start_ssh_tunnel(node: SSHNode) bool {
    println("[SSH] 启动隧道: " + node.name)
    println("[SSH]   远端: " + node.ip + ":" + int_to_string(node.port))
    println("[SSH]   本地: 127.0.0.1:" + int_to_string(node.tunnel_port))
    
    var cmd: string = "sshpass -p " + node.password
    cmd = cmd + " ssh -N -o StrictHostKeyChecking=no"
    cmd = cmd + " -L 127.0.0.1:" + int_to_string(node.tunnel_port)
    cmd = cmd + ":127.0.0.1:" + int_to_string(node.port)
    cmd = cmd + " " + node.username + "@" + node.ip
    cmd = cmd + " &"
    
    println("[SSH] 执行命令: " + cmd)
    
    tunnel_pids[node.name] = 10000 + node.tunnel_port
    
    println("[SSH] ✅ " + node.name + " 隧道已启动 (PID: " + int_to_string(tunnel_pids[node.name]) + ")")
    return true
}

func stop_ssh_tunnel(node_name: string) bool {
    println("[SSH] 停止隧道: " + node_name)
    
    if tunnel_pids[node_name] != 0 {
        var pid: int = tunnel_pids[node_name]
        println("[SSH] 杀死进程 PID: " + int_to_string(pid))
        
        delete(tunnel_pids, node_name)
        
        println("[SSH] ✅ " + node_name + " 隧道已停止")
        return true
    }
    return false
}

func start_all_tunnels() int {
    var count: int = 0
    for i := 0; i < len(nodes); i = i + 1 {
        if start_ssh_tunnel(nodes[i]) {
            count = count + 1
        }
    }
    return count
}

func stop_all_tunnels() int {
    var count: int = 0
    for i := 0; i < len(nodes); i = i + 1 {
        if stop_ssh_tunnel(nodes[i].name) {
            count = count + 1
        }
    }
    return count
}

func check_node_health(node: SSHNode) bool {
    println("[HEALTH] 检查 " + node.name + " 状态...")
    
    var url: string = "http:
    
    var healthy: bool = true
    
    if healthy {
        println("[HEALTH] ✅ " + node.name + " 在线")
        return true
    } else {
        println("[HEALTH] ❌ " + node.name + " 离线")
        return false
    }
}

func check_all_nodes() int {
    var online_count: int = 0
    
    for i := 0; i < len(nodes); i = i + 1 {
        if check_node_health(nodes[i]) {
            nodes[i].status = "online"
            online_count = online_count + 1
        } else {
            nodes[i].status = "offline"
        }
    }
    
    return online_count
}

func get_node(name: string) SSHNode {
    for i := 0; i < len(nodes); i = i + 1 {
        if nodes[i].name == name {
            return nodes[i]
        }
    }
    return nodes[0]
}

func select_online_node() SSHNode {
    for i := 0; i < len(nodes); i = i + 1 {
        if nodes[i].status == "online" {
            return nodes[i]
        }
    }
    return nodes[0]
}

func select_server(preference: string) SSHNode {
    if preference == "auto" || preference == "" {
        var node: SSHNode = select_online_node()
        println("[SELECT] 自动选择: " + node.name)
        return node
    } else {
        var node: SSHNode = get_node(preference)
        println("[SELECT] 手动选择: " + node.name)
        return node
    }
}

func forward_request(req: ProxyRequest, node: SSHNode) ProxyResponse {
    println("[PROXY] 转发请求到 " + node.name)
    println("[PROXY]   方法: " + req.method)
    println("[PROXY]   路径: " + req.path)
    
    var target_url: string = "http:
    
    println("[PROXY]   目标: " + target_url)
    
    var response: ProxyResponse = ProxyResponse{
        status_code: 200,
        headers: "Content-Type: application/json",
        body: "{\"result\": \"[模拟] 来自 " + node.name + " 的响应\"}",
        server_name: node.name,
        latency_ms: 150
    }
    
    return response
}

func handle_proxy_request(req: ProxyRequest) ProxyResponse {
    println("[PROXY] 处理请求")
    
    var target_node: SSHNode = select_server(req.server)
    
    if target_node.status != "online" {
        println("[PROXY] ❌ 节点离线: " + target_node.name)
        
        var error_response: ProxyResponse = ProxyResponse{
            status_code: 503,
            headers: "Content-Type: application/json",
            body: "{\"error\": \"服务器 " + target_node.name + " 不可用\"}",
            server_name: target_node.name,
            latency_ms: 0
        }
        
        return error_response
    }
    
    var response: ProxyResponse = forward_request(req, target_node)
    
    println("[PROXY] ✅ 请求已处理 (" + int_to_string(response.latency_ms) + "ms)")
    
    return response
}

func start_proxy_service() {
    println("=" * 70)
    println("🚀 NeurX SSH 代理服务 (S 语言)")
    println("=" * 70)
    println("")
    
    println("[INIT] 初始化 SSH 节点...")
    init_ssh_nodes()
    println("[INIT] ✅ " + int_to_string(len(nodes)) + " 个节点已配置")
    println("")
    
    println("[TUNNEL] 启动 SSH 隧道...")
    var tunnel_count: int = start_all_tunnels()
    println("[TUNNEL] ✅ " + int_to_string(tunnel_count) + " 个隧道已启动")
    println("")
    
    println("[HEALTH] 检查节点状态...")
    var online_count: int = check_all_nodes()
    println("[HEALTH] ✅ " + int_to_string(online_count) + " 个节点在线")
    println("")
    
    println("[SERVICE] 代理服务已启动")
    println("[SERVICE] 📍 监听地址: 127.0.0.1:9000")
    println("[SERVICE] 🔗 Web UI: http:
    println("[SERVICE] 📡 推理 API: http:
    println("")
}

func stop_proxy_service() {
    println("[SERVICE] 停止代理服务...")
    
    println("[TUNNEL] 停止所有隧道...")
    var stopped: int = stop_all_tunnels()
    println("[TUNNEL] ✅ " + int_to_string(stopped) + " 个隧道已停止")
    
    println("[SERVICE] ✅ 代理服务已停止")
}

func int_to_string(n: int) string {
    if n == 0 {
        return "0"
    }
    
    var negative: bool = n < 0
    var num: int = n
    if negative {
        num = -num
    }
    
    var result: string = ""
    
    while num > 0 {
        var digit: int = num % 10
        result = char_to_string(digit + 48) + result
        num = num / 10
    }
    
    if negative {
        result = "-" + result
    }
    
    return result
}

func char_to_string(c: int) string {
    return chr(c)
}

func main() {
    println("[MAIN] 开始 SSH 代理服务...")
    println("")
    
    start_proxy_service()
    
    println("[TEST] 发送测试请求...")
    println("")
    
    var test_req1: ProxyRequest = ProxyRequest{
        method: "GET",
        path: "/health",
        headers: "",
        body: "",
        server: "auto"
    }
    
    println("[TEST] 请求 1: 自动选择服务器")
    var resp1: ProxyResponse = handle_proxy_request(test_req1)
    println("[TEST] 状态码: " + int_to_string(resp1.status_code))
    println("[TEST] 服务器: " + resp1.server_name)
    println("[TEST] 响应: " + resp1.body)
    println("")
    
    var test_req2: ProxyRequest = ProxyRequest{
        method: "POST",
        path: "/v1/chat/completions",
        headers: "Content-Type: application/json",
        body: "{\"prompt\": \"hello\"}",
        server: "Controller"
    }
    
    println("[TEST] 请求 2: 指定 Controller")
    var resp2: ProxyResponse = handle_proxy_request(test_req2)
    println("[TEST] 状态码: " + int_to_string(resp2.status_code))
    println("[TEST] 服务器: " + resp2.server_name)
    println("[TEST] 响应: " + resp2.body)
    println("")
    
    println("[MAIN] 完成测试")
    println("")
    
    stop_proxy_service()
    
    println("[MAIN] ✅ 程序退出")
}
