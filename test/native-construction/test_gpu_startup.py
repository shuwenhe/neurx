"""Startup must gate the client on HTTP readiness and fail on exit/timeout."""
import importlib.util,pathlib,socket,threading,time,unittest,http.server,tempfile,os,subprocess,sys,signal
from types import SimpleNamespace
root=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('startup',root/'scripts/run_gpu_chat.py')
startup=importlib.util.module_from_spec(spec);spec.loader.exec_module(startup)
class StartupTests(unittest.TestCase):
 def test_delayed_http_readiness(self):
  class Handler(http.server.BaseHTTPRequestHandler):
   def do_GET(self):
    body=b'{"status":"ok"}';self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
   def log_message(self,*a):pass
  with http.server.HTTPServer(('127.0.0.1',0),Handler) as server:
   thread=threading.Thread(target=lambda:(time.sleep(.2),server.serve_forever()),daemon=True);thread.start()
   begin=time.monotonic();startup.wait_backend_ready(SimpleNamespace(poll=lambda:None),'127.0.0.1',server.server_port,2)
   self.assertGreaterEqual(time.monotonic()-begin,.18);server.shutdown();thread.join()
 def test_backend_exit_fails(self):
  with self.assertRaisesRegex(RuntimeError,'exited.*7'):startup.wait_backend_ready(SimpleNamespace(poll=lambda:7),'127.0.0.1',1,1)
 def test_timeout_fails(self):
  with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
  with self.assertRaisesRegex(RuntimeError,'timed out'):startup.wait_backend_ready(SimpleNamespace(poll=lambda:None),'127.0.0.1',port,.15)
 def test_failed_backend_never_starts_client_and_cleans_pid(self):
  with tempfile.TemporaryDirectory() as directory:
   p=pathlib.Path(directory);runner=p/'runner';marker=p/'client-started'
   runner.write_text('#!/usr/bin/env python3\nimport sys,pathlib\nif sys.argv[1]=="backend":\n print("MODEL_LOAD_FAILED",flush=True)\n sys.exit(5)\npathlib.Path('+repr(str(marker))+').touch()\n')
   runner.chmod(0o755)
   with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
   env=dict(os.environ,NEURX_S_PORT=str(port),NEURX_S_HOST='127.0.0.1',NEURX_CUDA_RUNTIME_LIB='',NEURX_BACKEND_STARTUP_TIMEOUT='2')
   result=subprocess.run([sys.executable,str(root/'scripts/run_gpu_chat.py'),'--runner',str(runner),'--backend-ir','backend','--client-ir','client','--log',str(p/'log'),'--pid-file',str(p/'pid')],env=env,capture_output=True,text=True,timeout=5)
   self.assertNotEqual(result.returncode,0);self.assertFalse(marker.exists());self.assertIn('MODEL_LOAD_FAILED',result.stderr);self.assertEqual((p/'pid').read_text(),'')
 def test_sigterm_cleans_backend_and_client(self):
  with tempfile.TemporaryDirectory() as directory:
   p=pathlib.Path(directory);runner=p/'runner';marker=p/'client-pid'
   runner.write_text('#!/usr/bin/env python3\nimport sys,pathlib,time,os,http.server\nif sys.argv[1]=="client":\n pathlib.Path('+repr(str(marker))+').write_text(str(os.getpid()))\n time.sleep(30)\nelse:\n class Handler(http.server.BaseHTTPRequestHandler):\n  def do_GET(self):\n   self.send_response(200);self.end_headers();self.wfile.write(b\'{"status":"ok"}\')\n  def log_message(self,*a):pass\n http.server.HTTPServer(("127.0.0.1",int(os.environ["NEURX_S_PORT"])),Handler).serve_forever()\n')
   runner.chmod(0o755)
   with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
   env=dict(os.environ,NEURX_S_PORT=str(port),NEURX_S_HOST='127.0.0.1',NEURX_CUDA_RUNTIME_LIB='',NEURX_BACKEND_STARTUP_TIMEOUT='5')
   launcher=subprocess.Popen([sys.executable,str(root/'scripts/run_gpu_chat.py'),'--runner',str(runner),'--backend-ir','backend','--client-ir','client','--log',str(p/'log'),'--pid-file',str(p/'pid')],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
   children=[]
   try:
    deadline=time.monotonic()+5
    while not marker.exists() and time.monotonic()<deadline:time.sleep(.03)
    self.assertTrue(marker.exists())
    children=[int((p/'pid').read_text()),int(marker.read_text())]
    launcher.send_signal(signal.SIGTERM);launcher.communicate(timeout=7)
    for pid in children:
     with self.assertRaises(ProcessLookupError):os.kill(pid,0)
    self.assertEqual((p/'pid').read_text(),'')
   finally:
    if launcher.poll() is None:launcher.kill();launcher.wait()
    for pid in children:
     try:os.kill(pid,signal.SIGKILL)
     except ProcessLookupError:pass
if __name__=='__main__':unittest.main()
