#!/usr/bin/env python3
"""Run the native S server/client; only start chat after HTTP health is ready."""
import argparse,json,os,pathlib,socket,subprocess,sys,time,signal,urllib.request

def wait_backend_ready(process,host,port,timeout):
 deadline=time.monotonic()+timeout
 # Local health checks must not use system HTTP proxies.
 opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
 while True:
  code=process.poll()
  if code is not None:raise RuntimeError(f'GPU backend exited during startup (exit {code})')
  remaining=deadline-time.monotonic()
  if remaining<=0:raise RuntimeError(f'GPU backend startup timed out after {timeout:g}s; increase NEURX_BACKEND_STARTUP_TIMEOUT if loading is still progressing')
  try:
   with opener.open(f'http://{host}:{port}/health',timeout=min(1,remaining)) as response:
    if json.load(response).get('status')=='ok':return
  except (OSError,ValueError):pass
  time.sleep(min(.25,max(0,deadline-time.monotonic())))

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 for name in ['runner','backend-ir','client-ir','log','pid-file']:parser.add_argument('--'+name,required=True)
 args=parser.parse_args();host=os.environ.get('NEURX_S_HOST','127.0.0.1');port=int(os.environ.get('NEURX_S_PORT','18084'))
 timeout=float(os.environ.get('NEURX_BACKEND_STARTUP_TIMEOUT','600'))
 if not 0<timeout<=86400:raise ValueError('NEURX_BACKEND_STARTUP_TIMEOUT must be positive and <=86400 seconds')
 # Never terminate a service already bound to this port.
 with socket.socket() as probe:
  probe.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
  try:probe.bind((host,port))
  except OSError as error:raise RuntimeError(f'Port {host}:{port} is unavailable; existing service was left running') from error
 env=dict(os.environ);env['LD_PRELOAD']=os.environ['NEURX_CUDA_RUNTIME_LIB']
 process=None;client=None;pidfile=pathlib.Path(args.pid_file);log=pathlib.Path(args.log)
 previous_handler=signal.getsignal(signal.SIGTERM)
 def terminate(signum,frame):raise SystemExit(128+signum)
 signal.signal(signal.SIGTERM,terminate)
 try:
  with log.open('w') as output:
   process=subprocess.Popen([args.runner,args.backend_ir],stdout=output,stderr=subprocess.STDOUT,env=env)
   pidfile.write_text(str(process.pid)+'\n')
   print(f'[HealthCheck] Waiting up to {timeout:g}s for {host}:{port}; loading log: {log}',flush=True)
   wait_backend_ready(process,host,port,timeout)
   print('[HealthCheck] Backend HTTP health is ready',flush=True)
   client=subprocess.Popen([args.runner,args.client_ir])
   return client.wait()
 except (RuntimeError,OSError) as error:
  print(f'ERROR: {error}',file=sys.stderr,flush=True)
  if log.exists():print('\n'.join(log.read_text(errors='replace').splitlines()[-50:]),file=sys.stderr)
  return 1
 finally:
  # Reap only children started by this launcher, including on SIGTERM.
  for child in [client,process]:
   if child is not None and child.poll() is None:
    child.terminate()
    try:child.wait(timeout=5)
    except subprocess.TimeoutExpired:child.kill();child.wait()
  if process is not None:pidfile.write_text('')
  signal.signal(signal.SIGTERM,previous_handler)
if __name__=='__main__':
 try:sys.exit(main())
 except (RuntimeError,ValueError,OSError) as error:print(f'ERROR: {error}',file=sys.stderr);sys.exit(1)
