import sys,json,subprocess,pathlib,struct,hashlib,numpy as np,time
root=pathlib.Path.cwd();sys.path.insert(0,str(root/'test/native-construction'))
from qwen35_official_reference import configure_runtime,run_official,_bf16,error_metrics
from test_qwen35_stage3 import reference
configure_runtime();layer=int(sys.argv[1]);scenario=sys.argv[2];model=root.parent/'model/Qwen3.6-35B-A3B';cfg=json.loads((model/'config.json').read_text())['text_config'];index=json.loads((model/'model.safetensors.index.json').read_text())['weight_map']
j=dict(hidden=cfg['hidden_size'],kh=cfg['linear_num_key_heads'],vh=cfg['linear_num_value_heads'],kd=cfg['linear_key_head_dim'],vd=cfg['linear_value_head_dim'],conv=cfg['linear_conv_kernel_dim'],eps=cfg['rms_norm_eps'],context=8,chunk=2,budget=256<<20)
x=_bf16((np.random.default_rng(1401).standard_normal((3,j['hidden']))*.2).astype('f4'));j['calls']=[dict(x=x[:2].ravel().tolist(),position=0),dict(x=x[2:].ravel().tolist(),position=2)]
j['initial_state']=[0.01]*(j['vh']*j['kd']*j['vd']);j['initial_history']=_bf16(np.full((2*j['kh']*j['kd']+j['vh']*j['vd'])*j['conv'],0.001,dtype=np.float32)).tolist()
if scenario=='zero': j['initial_state']=[0.0]*len(j['initial_state']);j['initial_history']=[0.0]*len(j['initial_history'])
j['calls'].extend([{'reset':True},{'x':x[0].tolist(),'position':0}])
fields={'qkv':'in_proj_qkv.weight','z':'in_proj_z.weight','a':'in_proj_a.weight','b':'in_proj_b.weight','conv_weight':'conv1d.weight','alog':'A_log','dt':'dt_bias','norm':'norm.weight','out':'out_proj.weight'};hashes={}
for key,suffix in fields.items():
 name=f'model.language_model.layers.{layer}.linear_attn.{suffix}'
 with (model/index[name]).open('rb') as f:
  size=struct.unpack('<Q',f.read(8))[0];meta=json.loads(f.read(size))[name];assert meta['dtype']=='BF16';start,end=meta['data_offsets'];f.seek(8+size+start);raw=f.read(end-start);assert len(raw)==end-start
 hashes[name]=hashlib.sha256(raw).hexdigest();j[key]=(np.frombuffer(raw,dtype='<u2').astype('<u4')<<16).view('<f4')
print('weights read',flush=True)
base={k:v for k,v in j.items() if k not in fields};p=subprocess.run(['/tmp/neurx-stage3-gate/probe','--model',str(model),'--layer',str(layer)],input=json.dumps(base),capture_output=True,text=True,check=True,timeout=120);native=json.loads(p.stdout)['calls'];assert native[2].get('reset');native=[c for c in native if 'reset' not in c];print('native done',flush=True)
o=run_official(j,partition='decode');print('official done',flush=True)
m=[c for c in reference(j,np.float32) if 'reset' not in c];print('m32 done',flush=True)
rows=[]
for k in ['output','core','state','history','beta','decay']:
 arrays={'N':np.concatenate([np.asarray(a[k]) for a in native]).reshape(4,-1),'M32':np.concatenate([np.asarray(a[k]) for a in m]).reshape(4,-1),'O':np.asarray(o[k]).reshape(4,-1)}
 for a,b in [('N','M32'),('O','M32'),('N','O')]:
  for t,(v,w) in enumerate(zip(arrays[a],arrays[b])):rows.append(dict(tensor=k,comparison=a+' vs '+b,token=t,metrics=error_metrics(v,w)))
out={'layer':layer,'scenario':scenario,'reset_test':True,'weight_sha256':hashes,'rows':rows,'gpu_peak_allocated':o['gpu_peak_allocated'],'gpu_peak_reserved':o['gpu_peak_reserved'],'input':f'BF16-rounded synthetic input; native 2-token prefill + decode; official incremental; {scenario} initial state/history then zero reset'}
pathlib.Path(f'artifact/build/qwen35_stage3/gate_closure_20261126/layer-{layer:02d}-{scenario}.json').write_text(json.dumps(out,indent=2)+'\n')
for c in ['N vs M32','O vs M32','N vs O']:
 for k in ['output','state','history']:print(c,k,max(x['metrics']['maxabs'] for x in rows if x['tensor']==k and x['comparison']==c),flush=True)
