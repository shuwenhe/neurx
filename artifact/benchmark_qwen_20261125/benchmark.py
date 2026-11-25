import urllib.request,json,time,statistics,pathlib,socket
out=pathlib.Path('/home/shuwen/shuwen/neurx/artifact/benchmark_qwen_20261125')
prompt='Write a detailed explanation of how computers work, covering processors, memory, storage, and operating systems.'
rows=[]
for i in range(6):
 data=json.dumps(dict(action='generate',prompt=prompt,max_new_tokens=128,stream=True),separators=(',',':')).encode()
 req=urllib.request.Request('http://127.0.0.1:18983/generate',data=data,headers={'Content-Type':'application/json'})
 start=time.perf_counter(); first=None; chunks=[]; done=None
 sock=socket.create_connection(('127.0.0.1',18983),timeout=180)
 raw=b'POST /generate HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: '+str(len(data)).encode()+b'\r\nConnection: close\r\n\r\n'+data
 sock.sendall(raw)
 with sock.makefile('rb') as r:
  while r.readline().strip(): pass
  for line in r:
   item=json.loads(line)
   if 'error' in item: raise RuntimeError(item)
   if item.get('delta'):
    if first is None: first=time.perf_counter()
    chunks.append(item['delta'])
   if item.get('done'): done=item; end=time.perf_counter(); break
 if not done or not done.get('generated_tokens'): raise RuntimeError('No generated tokens')
 sock.close()
 n=done['generated_tokens']; elapsed=end-start
 row=dict(run=i,warmup=i==0,generated_tokens=n,elapsed_s=elapsed,ttft_s=first-start,tps=n/elapsed,decode_tps=(n-1)/(end-first),output=''.join(chunks))
 rows.append(row); print(json.dumps({k:v for k,v in row.items() if k!='output'}),flush=True)
 (out/'results.json').write_text(json.dumps(dict(prompt=prompt,max_new_tokens=128,concurrency=1,rows=rows),ensure_ascii=False,indent=2))
print('SUMMARY',json.dumps(dict(mean_tps=statistics.mean(r['tps'] for r in rows[1:]),aggregate_tps=sum(r['generated_tokens'] for r in rows[1:])/sum(r['elapsed_s'] for r in rows[1:]),mean_decode_tps=statistics.mean(r['decode_tps'] for r in rows[1:]))),flush=True)
