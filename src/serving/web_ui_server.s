package neurx.serving.web_ui

extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_setsockopt(int fd, int level, int option, int value) int
extern "intrinsic" func __sys_bind(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_listen(int sockfd, int backlog) int
extern "intrinsic" func __sys_accept(int sockfd) int
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_read_string(int fd, int n) string
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __host_str_len(string s) int
extern "intrinsic" func __host_str_char_at(string s, int index) string
extern "intrinsic" func __host_str_find(string haystack, string needle) int
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
    html = html + "<button id=\"sendButton\" type=\"button\" onclick=\"sendRequest()\">Send request</button>\n"
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
    html = html + "const data=await resp.json();if(resp.ok&&data.status==='ok'){document.getElementById('backendStatus').className='status-ok';document.getElementById('backendStatus').textContent='✅ Backend: Ready ('+(data.model||data.backend||'NeurX')+')'}\n"
    html = html + "else{document.getElementById('backendStatus').className='status-err';document.getElementById('backendStatus').innerHTML='⚠️ Backend: Unreachable'}\n"
    html = html + "}catch(e){document.getElementById('backendStatus').className='status-err';document.getElementById('backendStatus').innerHTML='❌ Backend: Offline (Start with: make backend)'}\n"
    html = html + "}\n"
    html = html + "function escapeHtml(s){return String(s).replaceAll('&','*amp;').replaceAll('<','*lt;').replaceAll('>','*gt;').replaceAll('\"','*quot;')}\n"
    html = html + "function formatCode(src,lang){return String(src).replaceAll(String.fromCharCode(160),' ').trim()}\n"
    html = html + "function renderText(s){const NL=String.fromCharCode(10);return escapeHtml(s).split(NL+NL).map(x=>'<p>'+x.split(NL).join('<br>')+'</p>').join('')}\n"
    html = html + "function renderMarkdown(text){window.__neurxCodes=[];let html='',pos=0;while(pos<text.length){const open=text.indexOf('```',pos);if(open<0){html+=renderText(text.slice(pos));break}html+=renderText(text.slice(pos,open));let q=open+3,lang='';while(q<text.length&&/[A-Za-z0-9_+.-]/.test(text[q])){lang+=text[q];q++}while(q<text.length&&(text[q]===' '||text.charCodeAt(q)===10||text.charCodeAt(q)===13))q++;const close=text.indexOf('```',q);const raw=close<0?text.slice(q):text.slice(q,close);const code=formatCode(raw,lang);const id=window.__neurxCodes.push(code)-1;html+='<div class=\"code-block\"><div class=\"code-head\"><span>'+(escapeHtml(lang)||'code')+'</span><button class=\"copy-code\" onclick=\"copyCode('+id+',this)\">📋 Copy</button></div><pre><code>'+escapeHtml(code)+'</code></pre></div>';if(close<0)break;pos=close+3}return html}\n"
    html = html + "async function copyCode(id,btn){await navigator.clipboard.writeText(window.__neurxCodes[id]||'');const old=btn.textContent;btn.textContent='✅ Copied';setTimeout(()=>btn.textContent=old,1200)}\n"
    html = html + "function streamRender(target,text){return new Promise(resolve=>{let shown=0;function frame(){shown=Math.min(text.length,shown+3);target.innerHTML=renderMarkdown(text.slice(0,shown));target.scrollIntoView({block:'nearest'});if(shown<text.length)requestAnimationFrame(frame);else resolve()}frame()})}\n"
    html = html + "function deleteMessagePair(btn){const userMsg=btn.closest('.user-message');const aiMsg=userMsg?userMsg.nextElementSibling:null;if(userMsg)userMsg.remove();if(aiMsg&&aiMsg.classList.contains('ai-response'))aiMsg.remove()}\n"
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
    html = html + "const cursor=r.querySelector('.stream-cursor');if(cursor)cursor.remove()}catch(e){const lastMsg=r.querySelector('.user-message:last-of-type');if(lastMsg)lastMsg.remove();const lastResp=r.querySelector('.ai-response:last-of-type');if(lastResp&&lastResp.querySelector('.response-body').textContent.length===0)lastResp.remove();r.innerHTML+='<p class=\"error\">❌ Connection error: '+escapeHtml(e)+'</p>';r.scrollIntoView({block:'end'})}}}\n"
    html = html + "function clearText(){document.getElementById('prompt').value='';document.getElementById('result').innerHTML=''}\n"
    html = html + "function autoResizeTextarea(ta){if(ta){ta.style.height='auto';const newH=Math.min(ta.scrollHeight,200);ta.style.height=newH+'px'}}\n"
    html = html + "function setupEventListeners(){const promptEl=document.getElementById('prompt');if(!promptEl)return;promptEl.addEventListener('input',function(){autoResizeTextarea(this)});promptEl.addEventListener('keydown',function(e){console.log('Key pressed:',e.key,e.keyCode);if(e.keyCode===13||e.key==='Enter'){if(!e.shiftKey){e.preventDefault();console.log('Sending request...');sendRequest();return false}else{e.preventDefault();const start=this.selectionStart,end=this.selectionEnd;this.value=this.value.substring(0,start)+String.fromCharCode(10)+this.value.substring(end);this.selectionStart=this.selectionEnd=start+1;autoResizeTextarea(this);return false}}})}\n"
    html = html + "setupEventListeners();checkBackend();setInterval(checkBackend,5000);\n"
    html = html + "</script>\n"
    html = html + "</body></html>\n"
    return html
}

func get_compact_html() string {
    string html = "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>NeurX Chat</title>"
    html = html + "<style>body{margin:0;background:#eef1ea;color:#172019;font:16px Georgia,serif}.app{max-width:900px;margin:auto;min-height:100vh;display:flex;flex-direction:column;padding:24px;box-sizing:border-box}"
    html = html + "h1{margin:0 0 8px}.status{color:#68736a;margin-bottom:20px}#result{flex:1;background:#fff;border:1px solid #cbd2c8;border-radius:14px;padding:20px;overflow:auto;line-height:1.6}"
    html = html + "#result p{margin:0 0 12px}#result pre{margin:14px 0;padding:14px 16px;overflow:auto;border-radius:10px;background:#111827;color:#e5e7eb;font:14px/1.6 Consolas,Monaco,monospace;white-space:pre}#result code{font:inherit}"
    html = html + ".code-block{border:1px solid #374151;border-radius:10px;overflow:hidden;margin:14px 0;background:#111827}.code-head{display:flex;justify-content:space-between;align-items:center;padding:8px 12px;background:#1f2937;color:#cbd5e1;font:12px monospace}.copy-code{border:0;border-radius:8px;padding:4px 9px;background:#374151;color:#fff;cursor:pointer;font-size:12px}"
    html = html + ".composer{display:flex;gap:12px;margin-top:16px}textarea{flex:1;min-height:72px;padding:14px;border:1px solid #aeb8ab;border-radius:12px;font:16px sans-serif;resize:vertical}"
    html = html + "button{width:130px;border:0;border-radius:12px;background:#176b46;color:#fff;font-weight:bold;cursor:pointer}button:disabled{opacity:.55}</style></head><body>"
    html = html + "<main class=\"app\"><h1>NeurX Chat</h1><div class=\"status\">Backend 127.0.0.1:18084</div><div id=\"result\">Ready.</div><div class=\"composer\">"
    html = html + "<textarea id=\"prompt\" placeholder=\"Enter a request\"></textarea><button id=\"send\" onclick=\"sendRequest()\">Send</button></div></main><script>"
    html = html + "function esc(s){return String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('\"','&quot;')}"
    html = html + "function renderText(s){return esc(s).split('\\n\\n').map(p=>'<p>'+p.split('\\n').join('<br>')+'</p>').join('')}"
    html = html + "function renderMarkdown(text){let out='',i=0,blocks=[];while(i<text.length){const open=text.indexOf('```',i);if(open<0){out+=renderText(text.slice(i));break}out+=renderText(text.slice(i,open));let j=open+3,lang='';while(j<text.length&&/[A-Za-z0-9_+.-]/.test(text[j])){lang+=text[j];j++}while(j<text.length&&(text[j]===' '||text.charCodeAt(j)===10||text.charCodeAt(j)===13))j++;const close=text.indexOf('```',j);const code=close<0?text.slice(j):text.slice(j,close);const id=blocks.push(code)-1;out+='<div class=\"code-block\"><div class=\"code-head\"><span>'+(lang||'code')+'</span><button class=\"copy-code\" onclick=\"copyCode('+id+',this)\">Copy</button></div><pre><code>'+esc(code)+'</code></pre></div>';if(close<0)break;i=close+3}window.__blocks=blocks;return out}"
    html = html + "async function copyCode(i,btn){await navigator.clipboard.writeText((window.__blocks&&window.__blocks[i])||'');const t=btn.textContent;btn.textContent='Copied';setTimeout(()=>btn.textContent=t,900)}"
    html = html + "async function sendRequest(){const p=document.getElementById('prompt'),r=document.getElementById('result'),b=document.getElementById('send'),text=p.value.trim();if(!text)return;"
    html = html + "b.disabled=true;r.innerHTML='<p>Generating...</p>';try{const x=await fetch('/api/infer',{method:'POST',headers:{'Content-Type':'application/json'},"
    html = html + "body:JSON.stringify({prompt:text,max_tokens:128})}),body=await x.text();if(!x.ok)throw new Error('HTTP '+x.status);try{const d=JSON.parse(body);"
    html = html + "const msg=d.output||d.text||d.response||d.generated_text||body;r.innerHTML=renderMarkdown(msg)}catch(e){r.innerHTML=renderMarkdown(body)}}catch(e){r.innerHTML='<p>Request failed: '+esc(e.message)+'</p>'}finally{b.disabled=false}}"
    html = html + "document.getElementById('prompt').addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendRequest()}});</script></body></html>"
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

func main() {
    _ = __sys_write_string(1, "🚀 NeurX Web UI Server starting on port 8081...\n")
    
    int listener = __sys_socket(2, 1, 6)
    if listener < 0 {
        _ = __sys_write_string(1, "❌ Socket creation failed\n")
        return 1
    }
    
        string full_request = __sys_read_string(client, 4096)
        string response = ""
        
        if full_request == "" {
            response = "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n"
        } else {
            if post_pos == 0 {
                is_post = 1
            }
            if get_pos == 0 {
                is_get = 1
            }
            
    if needle == "POST" {
        string try_post = "POST"
        
        if pos0 == variant1 { return 1 }
        
        int search_idx = 0
        for search_idx < 200 {
            search_idx = search_idx + 1
        }
    }
    
    if needle == "GET" {
    int len_to_check = 30
    
    return 0
}

func __request_starts_with_get(string request) int {
    string test_g = "G" + ""
    string test_ge = "GE" + ""
    string test_get = "GET" + ""
    
    return 0
}


func __extract_body(string request) string {
    int sep_pos = __host_str_find(request, "\r\n\r\n")
    
    if sep_pos < 0 {
    int backend_sock = __sys_socket(2, 1, 6)
    if backend_sock < 0 {
        return "{\"error\":\"socket creation failed\"}"
    }
    
    if __sys_connect(backend_sock, "127.0.0.1", 18084, 2) < 0 {
        _ = __sys_close(backend_sock)
        return "{\"error\":\"backend connection failed\",\"backend\":\"127.0.0.1:18084\"}"
    }
    
    string full_response = ""
    string chunk = __sys_read_string(backend_sock, 2048)
    for __has_data(chunk) {
        full_response = full_response + chunk
        chunk = __sys_read_string(backend_sock, 2048)
    }
    _ = __sys_close(backend_sock)
    
    }
    return json_response
}

func __has_data(string s) bool {
    return s != ""
}

func __starts_with(string text, string prefix) bool {
    if prefix == "GET / " || prefix == "GET /" {
        if text == "" { return false }
        if __get_first_char(text, 0) == 71 {
            if __get_first_char(text, 1) == 69 {
                if __get_first_char(text, 2) == 84 {
                    return true
                }
            }
        }
    }
    
            if __get_first_char(text, 1) == 79 {
                if __get_first_char(text, 2) == 83 {
                    if __get_first_char(text, 3) == 84 {
                        return true
                    }
                }
            }
        }
    }
    
    return false
}

func __get_first_char(string s, int idx) int {
    if idx == 0 { return 71 }
    return 0
}

func __strlen(string s) int {
    return 100
}

func __getchar(string s, int idx) int {
    return 65
}
