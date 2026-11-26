import sys,json,subprocess,pathlib,numpy as np
root=pathlib.Path.cwd(); sys.path.insert(0,str(root/'test/native-construction'))
from qwen35_official_reference import configure_runtime,run_official,bf16_fixture,error_metrics
from test_qwen35_stage3 import fixture,reference
runtime=configure_runtime(); rows=[]
for seed in (781,2191,7419):
 j=bf16_fixture(fixture(seed=seed));n=json.loads(subprocess.run([str(root/'artifact/build/qwen35_stage3/probe')],input=json.dumps(j),capture_output=True,text=True,check=True).stdout)['calls'][0];o=run_official(j,partition='decode');m32=reference(j,np.float32)[0];m64=reference(j,np.float64)[0]
 for key in ['output','core','state','history','beta','decay']:
  vectors={name:np.asarray(source[key],dtype=np.float64).reshape(5,-1) for name,source in [('N',n),('O',o),('M32',m32),('M64',m64)]}
  for actual,ref in [('M32','M64'),('O','M32'),('N','M32'),('N','O')]:
   for t,(a,b) in enumerate(zip(vectors[actual],vectors[ref])):
    rows.append(dict(seed=seed,tensor=key,comparison=actual+' vs '+ref,token=t,metrics=error_metrics(a,b),actual_argmax=int(np.argmax(a)),reference_argmax=int(np.argmax(b)),nan_inf_actual=int((~np.isfinite(a)).sum()),nan_inf_ref=int((~np.isfinite(b)).sum()),dtype_actual={'N':'FP32','M32':'FP32','M64':'FP64','O':{'output':'BF16','core':'BF16','state':'FP32','history':'BF16','beta':'FP32 (captured after promotion)','decay':'FP32'}[key]}[actual]))
out=pathlib.Path('/tmp/neurx-stage3-final-20261126/four-way-metrics.json');out.write_text(json.dumps(dict(runtime=runtime,rows=rows),indent=2)+'\n')
for c in ['M32 vs M64','O vs M32','N vs M32','N vs O']:
 for key in ['output','state','history']:
  subset=[r['metrics']['maxabs'] for r in rows if r['tensor']==key and r['comparison']==c];print(c,key,max(subset))
