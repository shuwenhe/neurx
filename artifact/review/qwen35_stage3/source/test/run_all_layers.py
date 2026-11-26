import json,pathlib,subprocess,sys,os
root=pathlib.Path.cwd(); d=root/'artifact/build/qwen35_stage3/gate_closure_20261126';cfg=json.loads((root.parent/'model/Qwen3.6-35B-A3B/config.json').read_text())['text_config'];layers=[i for i,t in enumerate(cfg['layer_types']) if t=='linear_attention'];print('selected',layers,flush=True)
for i in layers:
 for scenario in ['zero','nonzero']:
  target=d/f'layer-{i:02d}-{scenario}.json'
  if target.exists():print('existing',i,scenario,flush=True);continue
  p=subprocess.run([str(root/'artifact/reference-env/bin/python'),str(d/'real_layers.py'),str(i),scenario],capture_output=True,text=True,timeout=120,env=os.environ)
  print(i,scenario,'exit',p.returncode,flush=True)
  if p.returncode:
   print(p.stdout[-3000:],p.stderr[-3000:],flush=True);sys.exit(1)
print('DONE',flush=True)
