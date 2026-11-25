"""Measure existing native NeurX HTTP streaming endpoint; no model substitution."""
import json,pathlib,socket,time,statistics
out=pathlib.Path(__file__).resolve().parent
prompt='Artificial intelligence is'
rows=[]
metadata=dict(model='DeepSeek-V2-Lite',gpu='NVIDIA GeForce RTX 4060 Ti 16GB',backend='NeurX S + native CUDA MLA/YaRN/MoE',precision='BF16 checkpoint, FP32 arithmetic/activations',weight_cache_mb=8192,context_limit=2048,host_offload=True,concurrency=1,max_new_tokens=32,prompt=prompt,warmups=1,measured_runs=3,endpoint='127.0.0.1:18084',note='Reuses existing user instance; host OS file cache is not flushed. End-to-end excludes model initialization. Decode TPS = (generated_tokens-1)/(done_time-first_delta_time), including serving overhead.')
for i in range(4):
 payload=json.dumps(dict(action='generate',prompt=prompt,stream=True,max_new_tokens=32),separators=(',',':')).encode()
 raw=b'POST /generate HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: '+str(len(payload)).encode()+b'\r\nConnection: close\r\n\r\n'+payload
 print(json.dumps(dict(event='start',run=i,warmup=i==0)),flush=True)
 start=time.perf_counter();first=None;events=[];done=None
 with socket.create_connection(('127.0.0.1',18084),timeout=600) as sock:
  sock.sendall(raw)
  with sock.makefile('rb') as f:
   status=f.readline().decode().strip()
   if '200' not in status:raise RuntimeError(status)
   while f.readline().strip():pass
   for line in f:
    event=json.loads(line);now=time.perf_counter()
    if event.get('error'):raise RuntimeError(event)
    if event.get('delta'):
     if first is None:first=now
     events.append(dict(time_s=now-start,delta=event['delta']))
     if len(events)%8==0:print(json.dumps(dict(event='progress',run=i,delta_count=len(events),elapsed_s=now-start)),flush=True)
    if event.get('done'):
     end=now;done=event;break
 if done is None or not done.get('generated_tokens') or first is None:raise RuntimeError('Missing generated tokens/deltas')
 n=done['generated_tokens']
 row=dict(run=i,warmup=i==0,generated_tokens=n,elapsed_s=end-start,ttft_s=first-start,tps=n/(end-start),decode_tps=(n-1)/(end-first),output=''.join(e['delta'] for e in events),events=events)
 rows.append(row)
 (out/'results.json').write_text(json.dumps(dict(metadata=metadata,rows=rows),ensure_ascii=False,indent=2))
 print(json.dumps({k:v for k,v in row.items() if k not in ['events','output']}),flush=True)
r=rows[1:]
summary=dict(aggregate_tps=sum(x['generated_tokens'] for x in r)/sum(x['elapsed_s'] for x in r),mean_tps=statistics.mean(x['tps'] for x in r),aggregate_decode_tps=sum(x['generated_tokens']-1 for x in r)/sum(x['elapsed_s']-x['ttft_s'] for x in r),mean_ttft_s=statistics.mean(x['ttft_s'] for x in r),tps_range=[min(x['tps'] for x in r),max(x['tps'] for x in r)],measured_output_tokens=sum(x['generated_tokens'] for x in r))
(out/'summary.json').write_text(json.dumps(dict(metadata=metadata,summary=summary),ensure_ascii=False,indent=2));print('SUMMARY',json.dumps(summary),flush=True)
