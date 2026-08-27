package neurx.serving.web_ui
extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_bind(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_listen(int sockfd, int backlog) int
extern "intrinsic" func __sys_accept(int sockfd) int
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_read_string(int fd, int n) string
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_setsockopt(int fd, int level, int option, int value) int
func get_html() string {
    string html = "<!DOCTYPE html>\n"
    html = html + "<html>\n"
    html = html + "<head><title>NeurX</title>\n"
    html = html + "<style>\n"
    html = html + "body{font-family:Arial,sans-serif;margin:0;padding:0;background:#f5f5f5;height:100vh;display:flex;justify-content:center;align-items:center}\n"
    html = html + ".container{background:white;display:flex;flex-direction:column;width:80%;height:90vh;box-shadow:0 2px 10px rgba(0,0,0,0.1);border-radius:8px;overflow:hidden}\n"
    html = html + "h1{color:#333;text-align:center;padding:15px;margin:0;border-bottom:1px solid #ddd;flex-shrink:0}\n"
    html = html + "#result{flex:1;background:#f9f9f9;border:none;padding:20px;border-radius:0;margin:0;line-height:1.6;color:#333;overflow-y:auto}\n"
    html = html + ".input-section{background:white;border-top:1px solid #ddd;padding:20px;flex-shrink:0;max-height:50vh;overflow-y:auto}\n"
    html = html + ".form-group{margin:15px 0}\n"
    html = html + "label{display:block;font-weight:bold;margin-bottom:5px;color:#555}\n"
    html = html + "textarea{width:100%;padding:10px;border:1px solid #ddd;border-radius:4px;font-family:monospace;font-size:14px;resize:vertical}\n"
    html = html + "input[type=\"number\"]{width:100px;padding:8px;border:1px solid #ddd;border-radius:4px}\n"
    html = html + ".button-group{display:flex;gap:10px;margin-top:15px}\n"
    html = html + "button{flex:1;background:#4CAF50;color:white;padding:12px;border:none;border-radius:4px;cursor:pointer;font-size:14px;font-weight:bold}\n"
    html = html + "button:hover{background:#45a049}\n"
    html = html + "button.clear{background:#ff9800}\n"
    html = html + "button.clear:hover{background:#e68900}\n"
    html = html + ".loading{color:#999;font-style:italic}\n"
    html = html + ".error{color:#d32f2f}\n"
    html = html + ".success{color:#388e3c}\n"
    html = html + ".response-body{white-space:normal;overflow-wrap:anywhere;margin:0}\n"
    html = html + ".response-body p{margin:0.5em 0}\n"
    html = html + ".code-block{margin:14px 0;border:1px solid #3d4652;border-radius:8px;overflow:hidden;background:#111827}\n"
    html = html + ".code-head{display:flex;justify-content:space-between;align-items:center;padding:7px 12px;background:#1f2937;color:#cbd5e1;font:12px monospace}\n"
    html = html + ".copy-code{flex:0;background:#374151;padding:4px 9px;font-size:12px}\n"
    html = html + ".code-block pre{margin:0;padding:15px;overflow:auto;color:#e5e7eb;font:14px/1.55 Consolas,Monaco,monospace;white-space:pre}\n"
    html = html + ".stream-cursor{display:inline-block;width:8px;height:1.05em;margin-left:3px;background:#4CAF50;vertical-align:-2px;animation:blink .8s steps(1) infinite}\n"
    html = html + "@keyframes blink{50%{opacity:0}}\n"
    html = html + ".user-message{display:flex;justify-content:flex-end;margin:10px 0;padding:0 10px}\n"
    html = html + ".user-message-bubble{background:#1084d7;color:white;padding:10px 15px;border-radius:18px;max-width:70%;word-wrap:break-word;font-size:14px;line-height:1.5}\n"
    html = html + ".ai-response{display:flex;justify-content:flex-start;margin:10px 0;padding:0 10px}\n"
    html = html + ".ai-response-bubble{max-width:100%;font-size:14px;line-height:1.6}\n"
    html = html + "#backendStatus{margin-bottom:15px;padding:10px;border-radius:4px;font-size:12px}\n"
    html = html + ".status-ok{background:#c8e6c9;color:#2e7d32}\n"
    html = html + ".status-err{background:#ffcdd2;color:#c62828}\n"
    html = html + "</style>\n"
    html = html + "</head>\n"
    html = html + "<body>\n"
    html = html + "<div class=\"container\">\n"
    html = html + "<h1></h1>\n"
    html = html + "<div id=\"result\"></div>\n"
    html = html + "<div class=\"input-section\">\n"
    html = html + "<div id=\"backendStatus\" style=\"display:none\">Checking backend...</div>\n"
    html = html + "<div class=\"form-group\">\n"
    html = html + "<textarea id=\"prompt\" placeholder=\"Enter your prompt... (Enter to send, Shift+Enter for new line)\" style=\"min-height:60px;resize:vertical;font-family:inherit;font-size:inherit;padding:8px;border:1px solid #ddd;border-radius:4px;line-height:1.5\" wrap=\"soft\">What is artificial intelligence</textarea>\n"
    html = html + "</div>\n"
    html = html + "<div class=\"form-group\" style=\"display:none\">\n"
    html = html + "<label for=\"maxTokens\">Max Tokens:</label>\n"
    html = html + "<input type=\"number\" id=\"maxTokens\" value=\"1024\" min=\"1\" max=\"4096\">\n"
    html = html + "</div>\n"
    html = html + "</div>\n"
    html = html + "</div>\n"
    html = html + "<script>\n"
    html = html + "async function checkBackend() {\n"
    html = html + "try{\n"
    html = html + "const resp=await fetch('/api/health');\n"
    html = html + "const data=await resp.json();if(resp.ok&*data.status==='ok'){document.getElementById('backendStatus').className='status-ok';document.getElementById('backendStatus').textContent='✅ Backend: Ready ('+(data.model||data.backend||'NeurX')+')'}\n"
    html = html + "else{document.getElementById('backendStatus').className='status-err';document.getElementById('backendStatus').innerHTML='⚠️ Backend: Unreachable'}\n"
    html = html + "}catch(e){document.getElementById('backendStatus').className='status-err';document.getElementById('backendStatus').innerHTML='❌ Backend: Offline (Start with: make backend)'}\n"
    html = html + "}\n"
    html = html + "function escapeHtml(s){return String(s).replaceAll('&','*amp;').replaceAll('<','*lt;').replaceAll('>','*gt;').replaceAll('\"','*quot;')}\n"
    html = html + "function formatCode(src,lang){const NL=String.fromCharCode(10);let s=String(src).replaceAll(String.fromCharCode(160),' ').trim();if(s.includes(NL))return s;let out='',indent=0,paren=0,line=true,quote='',escape=false;const pad=()=> '    '.repeat(Math.max(0,indent));for(let i=0;i<s.length;i++){const c=s[i];if(quote){out+=c;if(escape)escape=false;else if(c==='\\\\')escape=true;else if(c===quote)quote='';continue}if(c==='\"'||c===\"'\"){quote=c;out+=c;continue}if(c==='('){paren++;out+=c;continue}if(c===')'){paren=Math.max(0,paren-1);out+=c;continue}if(c==='{'){out=out.trimEnd()+' {'+NL;indent++;out+=pad();line=true;continue}if(c==='}'){out=out.trimEnd()+NL;indent=Math.max(0,indent-1);out+=pad()+'}';if(i+1<s.length&*s[i+1]!==';'&*s[i+1]!==',')out+=NL+pad();line=true;continue}if(c===';'&*paren===0){out+=';'+NL+pad();line=true;continue}if(c==='#'&*out.trim().length>0){out=out.trimEnd()+NL+'#';line=false;continue}if(c===' '&*line)continue;out+=c;line=false}return out.trim()}\n"
    html = html + "function renderText(s){const NL=String.fromCharCode(10);return escapeHtml(s).split(NL+NL).map(x=>'<p>'+x.split(NL).join('<br>')+'</p>').join('')}\n"
    html = html + "function renderMarkdown(text){window.__neurxCodes=[];let html='',pos=0;while(pos<text.length){const open=text.indexOf('```',pos);if(open<0){html+=renderText(text.slice(pos));break}html+=renderText(text.slice(pos,open));let q=open+3,lang='';while(q<text.length&&/[A-Za-z0-9_+.-]/.test(text[q])){lang+=text[q];q++}while(q<text.length&&(text[q]===' '||text.charCodeAt(q)===10||text.charCodeAt(q)===13))q++;const close=text.indexOf('```',q);const raw=close<0?text.slice(q):text.slice(q,close);const code=formatCode(raw,lang);const id=window.__neurxCodes = append(window.__neurxCodes, code)-1;html+='<div class=\"code-block\"><div class=\"code-head\"><span>'+(escapeHtml(lang)||'code')+'</span><button class=\"copy-code\" onclick=\"copyCode('+id+',this)\">📋 Copy</button></div><pre><code>'+escapeHtml(code)+'</code></pre></div>';if(close<0)break;pos=close+3}return html}\n"
    html = html + "async function copyCode(id,btn){await navigator.clipboard.writeText(window.__neurxCodes[id]||'');const old=btn.textContent;btn.textContent='✅ Copied';setTimeout(()=>btn.textContent=old,1200)}\n"
    html = html + "function streamRender(target,text){return new Promise(resolve=>{let shown=0;function frame(){shown=Math.min(text.length,shown+3);target.innerHTML=renderMarkdown(text.slice(0,shown));target.scrollIntoView({block:'nearest'});if(shown<text.length)requestAnimationFrame(frame);else resolve()}frame()})}\n"
    html = html + "function deleteMessagePair(btn){const userMsg=btn.closest('.user-message');const aiMsg=userMsg?userMsg.nextElementSibling:null;if(userMsg)userMsg.remove();if(aiMsg&*aiMsg.classList.contains('ai-response'))aiMsg.remove()}\n"
    html = html + "async function sendRequest(){\n"
    html = html + "const promptEl=document.getElementById('prompt');const maxEl=document.getElementById('maxTokens');const resultEl=document.getElementById('result');\n"
    html = html + "if(!promptEl||!maxEl||!resultEl){console.error('Required elements not found');return}\n"
    html = html + "const p=promptEl.value,m=parseInt(maxEl.value)||1024,r=resultEl;\n"
    html = html + "promptEl.value='';\n"
    html = html + "let chatHtml=r.innerHTML+'<div class=\"ai-response\"><div class=\"ai-response-bubble\"><div id=\"responseBody\" class=\"response-body\"></div></div></div>';\n"
    html = html + "r.innerHTML=chatHtml;\n"
    html = html + "r.scrollIntoView({block:'end',behavior:'smooth'});\n"
    html = html + "const body=document.getElementById('responseBody');let output='',pending='';try{\n"
    html = html + "const res=await fetch('/api/infer',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt:p,max_tokens:m,max_new_tokens:m,stream:true})});\n"
    html = html + "if(!res.ok||!res.body)throw new Error('Streaming response unavailable');const reader=res.body.getReader(),decoder=new TextDecoder();let finished=false;\n"
    html = html + "while(!finished){const part=await reader.read();finished=part.done;pending+=decoder.decode(part.value||new Uint8Array(),{stream:!finished});\n"
    html = html + "const lines=pending.split(String.fromCharCode(10));pending=lines.pop()||'';for(const line of lines){if(!line.trim())continue;const event=JSON.parse(line);\n"
    html = html + "if(event.error)throw new Error(event.error);if(event.delta){output+=event.delta;body.innerHTML=renderMarkdown(output);body.parentElement.scrollIntoView({block:'end'})}if(event.done)finished=true}}\n"
    html = html + "if(pending.trim()){const event=JSON.parse(pending);if(event.delta){output+=event.delta;body.innerHTML=renderMarkdown(output);body.parentElement.scrollIntoView({block:'end'})}}\n"
    html = html + "const cursor=r.querySelector('.stream-cursor');if(cursor)cursor.remove()}catch(e){const lastMsg=r.querySelector('.user-message:last-of-type');if(lastMsg)lastMsg.remove();const lastResp=r.querySelector('.ai-response:last-of-type');if(lastResp&*lastResp.querySelector('.response-body').textContent.length===0)lastResp.remove();r.innerHTML+='<p class=\"error\">❌ Connection error: '+escapeHtml(e)+'</p>';r.scrollIntoView({block:'end'})}}}\n"
    html = html + "function clearText(){document.getElementById('prompt').value='';document.getElementById('result').innerHTML=''}\n"
    html = html + "function autoResizeTextarea(ta){if(ta){ta.style.height='auto';const newH=Math.min(ta.scrollHeight,200);ta.style.height=newH+'px'}}\n"
    html = html + "function setupEventListeners(){const promptEl=document.getElementById('prompt');if(!promptEl)return;promptEl.addEventListener('input',function(){autoResizeTextarea(this)});promptEl.addEventListener('keydown',function(e){console.log('Key pressed:',e.key,e.keyCode);if(e.keyCode===13||e.key==='Enter'){if(!e.shiftKey){e.preventDefault();console.log('Sending request...');sendRequest();return false}else{e.preventDefault();const start=this.selectionStart,end=this.selectionEnd;this.value=this.value.substring(0,start)+String.fromCharCode(10)+this.value.substring(end);this.selectionStart=this.selectionEnd=start+1;autoResizeTextarea(this);return false}}})}\n"
    html = html + "setupEventListeners();checkBackend();setInterval(checkBackend,5000);\n"
    html = html + "</script>\n"
    html = html + "</body></html>\n"
    return html
}

func int_to_string(int value) string {
    if value == 0 { return "0" }
    string result = ""
    int n = value
    if n < 0 { n = 0 - n }
    for n > 0 {
        result = string(48 + (n - (n / 10) * 10)) + result
        n = n / 10
    }
    if value < 0 { result = "-" + result }
    return result
}

func proxy_to_backend(string method, string path, string request_body) string {
    int backend_sock = __sys_socket(2, 1, 6)
    if backend_sock < 0 {
        return "{\"error\": \"Socket creation failed\"}"
    }
    if __sys_connect(backend_sock, "127.0.0.1", 18084, 2) < 0 {
        _ = __sys_close(backend_sock)
        return "{\"error\": \"Backend connection failed\"}"
    }
    string backend_request = method + " " + path + " HTTP/1.1\r\n"
    backend_request = backend_request + "Host: 127.0.0.1:18084\r\n"
    backend_request = backend_request + "Content-Type: application/json\r\n"
    backend_request = backend_request + "Content-Length: " + int_to_string(len(request_body)) + "\r\n"
    backend_request = backend_request + "Connection: close\r\n"
    backend_request = backend_request + "\r\n"
    backend_request = backend_request + request_body
    _ = __sys_write_string(backend_sock, backend_request)
    string response = ""
    string chunk = __sys_read_string(backend_sock, 4096)
    for len(chunk) > 0 {
        response = response + chunk
        chunk = __sys_read_string(backend_sock, 4096)
    }
    _ = __sys_close(backend_sock)
    return response
}

func proxy_stream_to_backend(int client_fd, string request_body) {
    int backend_sock = __sys_socket(2, 1, 6)
    if backend_sock < 0 {
        _ = __sys_write_string(client_fd, "HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n")
        return
    }
    if __sys_connect(backend_sock, "127.0.0.1", 18084, 2) < 0 {
        _ = __sys_close(backend_sock)
        _ = __sys_write_string(client_fd, "HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n")
        return
    }
    string backend_request = "POST /v1/generate HTTP/1.1\r\n"
    backend_request = backend_request + "Host: 127.0.0.1:18084\r\n"
    backend_request = backend_request + "Content-Type: application/json\r\n"
    backend_request = backend_request + "Content-Length: " + int_to_string(len(request_body)) + "\r\n"
    backend_request = backend_request + "Connection: close\r\n\r\n" + request_body
    _ = __sys_write_string(backend_sock, backend_request)
    string chunk = __sys_read_string(backend_sock, 4096)
    for len(chunk) > 0 {
        _ = __sys_write_string(client_fd, chunk)
        chunk = __sys_read_string(backend_sock, 4096)
    }
    _ = __sys_close(backend_sock)
}

func parse_json_response(string http_response) string {
    int idx = 0
    for idx < len(http_response) {
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
    _ = __sys_setsockopt(listener, 1, 2, 1)
    if __sys_bind(listener, "127.0.0.1", 8081, 2) < 0 {
        _ = __sys_write_string(1, "❌ Bind failed\n")
        return
    }
    if __sys_listen(listener, 128) < 0 {
        _ = __sys_write_string(1, "❌ Listen failed\n")
        return
    }
    _ = __sys_write_string(1, "✅ Web UI running at http:
    _ = __sys_write_string(1, "📌 Make sure backend is running: make chat-cpu\n")
    for true {
        int client = __sys_accept(listener)
        if client < 0 { continue }
        string request = __sys_read_string(client, 4096)
        string response = ""
        if __host_slice(request, 0, 16) == "GET /api/health " {
            string backend_response = proxy_to_backend("GET", "/health", "")
            string json_body = parse_json_response(backend_response)
            response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " + int_to_string(len(json_body)) + "\r\n\r\n" + json_body
        } else if __host_slice(request, 0, 4) == "GET " {
            string html = get_html()
            response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Length: " + int_to_string(len(html)) + "\r\n\r\n" + html
        } else if __host_slice(request, 0, 16) == "POST /api/infer " {
            int body_start = 0
            int idx = 0
            for idx < len(request) - 3 {
                if __host_slice(request, idx, idx + 4) == "\r\n\r\n" {
                    body_start = idx + 4
                    break
                }
                idx = idx + 1
            }
            string body = __host_slice(request, body_start, len(request))
            if len(body) > 0 {
                proxy_stream_to_backend(client, body)
                _ = __sys_close(client)
                continue
            }
            response = "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n"
        } else {
            response = "HTTP/1.1 404 Not Found\r\n\r\n"
        }
        _ = __sys_write_string(client, response)
        _ = __sys_close(client)
    }
}
