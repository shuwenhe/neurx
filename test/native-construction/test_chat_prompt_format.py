"""Exercise compiled S client against health metadata; no model inference substitute."""
import http.server,json,os,pathlib,subprocess,threading
root=pathlib.Path(__file__).resolve().parents[2]
for mode in ['plain','chatml']:
 prompts=[]
 class Handler(http.server.BaseHTTPRequestHandler):
  def do_GET(self):self.reply(dict(status='ok',prompt_format=mode))
  def do_POST(self):
   data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
   prompts.append(data['prompt']);self.reply(dict(status='ok',output=' Paris.'))
  def reply(self,obj):
   data=json.dumps(obj,separators=(',',':')).encode();self.send_response(200);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
  def log_message(self,*args):pass
 with http.server.HTTPServer(('127.0.0.1',0),Handler) as server:
  thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  env=dict(os.environ,NEURX_S_HOST='127.0.0.1',NEURX_S_PORT=str(server.server_port),NEURX_MODEL_DIR='/test/model',NEURX_CHAT_MAX_NEW_TOKENS='8')
  r=subprocess.run([str(root/'artifact/build/s_runner/NeurX'),str(root/'artifact/build/production_s_inference/chat_client.ir')],input='The capital of France is\n',text=True,capture_output=True,env=env,timeout=15)
  server.shutdown();thread.join()
 assert r.returncode==0,(r.stdout,r.stderr)
 assert len(prompts)==1,prompts
 if mode=='plain':assert prompts[0]=='The capital of France is',prompts
 else:assert '<|im_start|>user' in prompts[0],prompts
print('PASS: compiled S client uses plain base prompt and preserves ChatML')
