import sys,json,subprocess,pathlib,numpy as np,time
root=pathlib.Path.cwd();sys.path.insert(0,str(root/'test/native-construction'))
from qwen35_official_reference import configure_runtime,run_official,bf16_fixture,error_metrics
from test_qwen35_stage3 import fixture,reference
length=int(sys.argv[1]); configure_runtime();j=fixture(kd=2,vd=2,kh=1,vh=2,context=length,chunk=1,seed=992);j['alog']=[-8.]*j['vh'];rng=np.random.default_rng(109);j['calls']=[dict(x=row.tolist(),position=i) for i,row in enumerate(rng.standard_normal((length,7)).astype('f4'))];j=bf16_fixture(j)
t=time.monotonic();n=json.loads(subprocess.run([str(root/'artifact/build/qwen35_stage3/probe')],input=json.dumps(j),capture_output=True,text=True,check=True,timeout=300).stdout)['calls'];print('native sec',time.monotonic()-t,flush=True)
t=time.monotonic();o=run_official(j,partition='decode');print('official sec',time.monotonic()-t,flush=True)
t=time.monotonic();m32=reference(j,np.float32);m64=reference(j,np.float64);print('math sec',time.monotonic()-t,flush=True)
rows=[]
for key in ['output','core','state','history','beta','decay']:
 arrays={'N':np.asarray([c[key] for c in n],dtype=np.float64).reshape(length,-1),'O':np.asarray(o[key],dtype=np.float64).reshape(length,-1),'M32':np.asarray([c[key] for c in m32],dtype=np.float64).reshape(length,-1),'M64':np.asarray([c[key] for c in m64],dtype=np.float64).reshape(length,-1)}
 for a,b in [('M32','M64'),('O','M32'),('N','M32'),('N','O')]:
  for i,(actual,ref) in enumerate(zip(arrays[a],arrays[b])):rows.append(dict(token=i,tensor=key,comparison=a+' vs '+b,metrics=error_metrics(actual,ref)))
pathlib.Path(f'/tmp/neurx-stage3-final-20261126/long-fourway-{length}.json').write_text(json.dumps({'length':length,'rows':rows},separators=(',',':')))
for c in ['M32 vs M64','O vs M32','N vs M32','N vs O']:
 for k in ['output','state','history']:print(c,k,max(r['metrics']['maxabs'] for r in rows if r['tensor']==k and r['comparison']==c),flush=True)
