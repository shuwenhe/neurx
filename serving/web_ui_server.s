package neurx.serving.web_ui

extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_bind(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_listen(int sockfd, int backlog) int
extern "intrinsic" func __sys_accept(int sockfd) int
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_read_string(int fd, int n) string
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int

func get_html() string {
    string html = "<!DOCTYPE html>\n"
    html = html + "<html>\n"
    html = html + "<head><title>NeurX AI Inference</title>\n"
    html = html + "<style>\n"
    html = html + "body{font-family:Arial,sans-serif;max-width:900px;margin:50px auto;background:#f5f5f5}\n"
    html = html + ".container{background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}\n"
    html = html + "h1{color:#333;text-align:center}\n"
    html = html + ".form-group{margin:15px 0}\n"
    html = html + "label{display:block;font-weight:bold;margin-bottom:5px;color:#555}\n"
    html = html + "textarea{width:100%;padding:10px;border:1px solid #ddd;border-radius:4px;font-family:monospace;font-size:14px;resize:vertical}\n"
    html = html + "input[type=\"number\"]{width:100px;padding:8px;border:1px solid #ddd;border-radius:4px}\n"
    html = html + ".button-group{display:flex;gap:10px;margin-top:15px}\n"
    html = html + "button{flex:1;background:#4CAF50;color:white;padding:12px;border:none;border-radius:4px;cursor:pointer;font-size:14px;font-weight:bold}\n"
    html = html + "button:hover{background:#45a049}\n"
    html = html + "button.clear{background:#ff9800}\n"
    html = html + "button.clear:hover{background:#e68900}\n"
    html = html + "#result{background:#f9f9f9;border:1px solid #ddd;padding:15px;border-radius:4px;margin-top:20px;min-height:100px;line-height:1.6;color:#333}\n"
    html = html + ".loading{color:#999;font-style:italic}\n"
    html = html + ".error{color:#d32f2f}\n"
    html = html + ".success{color:#388e3c}\n"
    html = html + "#backendStatus{margin-top:15px;padding:10px;border-radius:4px;font-size:12px}\n"
    html = html + ".status-ok{background:#c8e6c9;color:#2e7d32}\n"
    html = html + ".status-err{background:#ffcdd2;color:#c62828}\n"
    html = html + "</style>\n"
    html = html + "</head>\n"
    html = html + "<body>\n"
    html = html + "<div class=\"container\">\n"
    html = html + "<h1>🧠 NeurX AI Inference Engine</h1>\n"
    html = html + "<div class=\"form-group\">\n"
    html = html + "<label for=\"prompt\">Prompt:</label>\n"
    html = html + "<textarea id=\"prompt\" rows=\"6\" placeholder=\"Enter your prompt here...\">What is artificial intelligence?</textarea>\n"
    html = html + "</div>\n"
    html = html + "<div class=\"form-group\">\n"
    html = html + "<label for=\"maxTokens\">Max Tokens:</label>\n"
    html = html + "<input type=\"number\" id=\"maxTokens\" value=\"256\" min=\"1\" max=\"2048\">\n"
    html = html + "</div>\n"
    html = html + "<div class=\"button-group\">\n"
    html = html + "<button onclick=\"sendRequest()\">🚀 Generate</button>\n"
    html = html + "<button class=\"clear\" onclick=\"clearText()\">🗑️ Clear</button>\n"
    html = html + "</div>\n"
    html = html + "<div id=\"backendStatus\">Checking backend...</div>\n"
    html = html + "<div id=\"result\"></div>\n"
    html = html + "</div>\n"
    html = html + "<script>\n"
    html = html + "async function checkBackend() {\n"
    html = html + "try{\n"
    html = html + "const resp=await fetch('http://127.0.0.1:18084/health');\n"
    html = html + "if(resp.ok){document.getElementById('backendStatus').className='status-ok';document.getElementById('backendStatus').innerHTML='✅ Backend: Ready (Qwen2.5-0.5B)'}\n"
    html = html + "else{document.getElementById('backendStatus').className='status-err';document.getElementById('backendStatus').innerHTML='⚠️ Backend: Unreachable'}\n"
    html = html + "}catch(e){document.getElementById('backendStatus').className='status-err';document.getElementById('backendStatus').innerHTML='❌ Backend: Offline (Start with: make chat-cpu)'}\n"
    html = html + "}\n"
    html = html + "async function sendRequest(){const p=document.getElementById('prompt').value;const m=document.getElementById('maxTokens').value;const r=document.getElementById('result');r.innerHTML='<p class=\"loading\">⏳ Generating...</p>';try{const res=await fetch('/api/infer',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt:p,max_tokens:parseInt(m)})});const d=await res.json();if(d.text){r.innerHTML='<p class=\"success\"><strong>AI Response:</strong></p><p>'+d.text+'</p>'}else{r.innerHTML='<p class=\"error\">❌ Error: '+d.error+'</p>'}}catch(e){r.innerHTML='<p class=\"error\">❌ Connection error: '+e+'</p>'}}\n"
    html = html + "function clearText(){document.getElementById('prompt').value='';document.getElementById('result').innerHTML=''}\n"
    html = html + "checkBackend();setInterval(checkBackend,5000);\n"
    html = html + "</script>\n"
    html = html + "</body></html>\n"
    return html
}

func int_to_string(int value) string {
    if value == 0 { return "0" }
    string result = ""
    int n = value
    if n < 0 { n = 0 - n }
    while n > 0 {
        result = string(48 + (n - (n / 10) * 10)) + result
        n = n / 10
    }
    if value < 0 { result = "-" + result }
    return result
}

func proxy_to_backend(string request_body) string {
    int backend_sock = __sys_socket(2, 1, 6)
    if backend_sock < 0 {
        return "{\"error\": \"Socket creation failed\"}"
    }
    
    if __sys_connect(backend_sock, "127.0.0.1", 18084, 2) < 0 {
        _ = __sys_close(backend_sock)
        return "{\"error\": \"Backend connection failed\"}"
    }
    
    string backend_request = "POST /v1/generate HTTP/1.1\r\n"
    backend_request = backend_request + "Host: 127.0.0.1:18084\r\n"
    backend_request = backend_request + "Content-Type: application/json\r\n"
    backend_request = backend_request + "Content-Length: " + int_to_string(len(request_body)) + "\r\n"
    backend_request = backend_request + "Connection: close\r\n"
    backend_request = backend_request + "\r\n"
    backend_request = backend_request + request_body
    
    _ = __sys_write_string(backend_sock, backend_request)
    
    string response = ""
    string chunk = __sys_read_string(backend_sock, 4096)
    while len(chunk) > 0 {
        response = response + chunk
        chunk = __sys_read_string(backend_sock, 4096)
    }
    
    _ = __sys_close(backend_sock)
    return response
}

func parse_json_response(string http_response) string {
    int idx = 0
    while idx < len(http_response) {
        if idx + 3 < len(http_response) {
            if __host_slice(http_response, idx, idx + 4) == "\r\n\r\n" {
                return __host_slice(http_response, idx + 4, len(http_response))
            }
        }
        idx = idx + 1
    }
    return http_response
}

extern "intrinsic" func __host_slice(string text, int start, int end) string

func main() {
    _ = __sys_write_string(1, "🚀 NeurX Web UI Server starting on port 8081...\n")
    
    int listener = __sys_socket(2, 1, 6)
    if listener < 0 {
        _ = __sys_write_string(1, "❌ Socket creation failed\n")
        return
    }
    
    if __sys_bind(listener, "127.0.0.1", 8081, 2) < 0 {
        _ = __sys_write_string(1, "❌ Bind failed\n")
        return
    }
    
    if __sys_listen(listener, 128) < 0 {
        _ = __sys_write_string(1, "❌ Listen failed\n")
        return
    }
    
    _ = __sys_write_string(1, "✅ Web UI running at http://127.0.0.1:8081\n")
    _ = __sys_write_string(1, "📌 Make sure backend is running: make chat-cpu\n")
    
    while true {
        int client = __sys_accept(listener)
        if client < 0 { continue }
        
        string request = __sys_read_string(client, 4096)
        string response = ""
        
        if __host_slice(request, 0, 4) == "GET " {
            string html = get_html()
            response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Length: " + int_to_string(len(html)) + "\r\n\r\n" + html
        } else if __host_slice(request, 0, 5) == "POST " {
            int body_start = 0
            int idx = 0
            while idx < len(request) - 3 {
                if __host_slice(request, idx, idx + 4) == "\r\n\r\n" {
                    body_start = idx + 4
                    break
                }
                idx = idx + 1
            }
            
            string body = __host_slice(request, body_start, len(request))
            string json_response = proxy_to_backend(body)
            string json_body = parse_json_response(json_response)
            
            response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: " + int_to_string(len(json_body)) + "\r\n\r\n" + json_body
        } else {
            response = "HTTP/1.1 404 Not Found\r\n\r\n"
        }
        
        _ = __sys_write_string(client, response)
        _ = __sys_close(client)
    }
}
