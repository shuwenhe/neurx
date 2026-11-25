#!/usr/bin/env python3
"""Check local inference assets and known unsupported architectures before build."""
import argparse,json,pathlib,re,struct,sys

def check_weight_file(path):
 try:
  size=path.stat().st_size
  with path.open('rb') as source:
   raw=source.read(8)
   if len(raw)!=8:return f'truncated checkpoint header: {path.name}'
   length=struct.unpack('<Q',raw)[0]
   if length>64*1024*1024 or length>size-8:return f'truncated/invalid checkpoint header: {path.name}'
   header=json.loads(source.read(length))
  end=max((int(value['data_offsets'][1]) for key,value in header.items() if key!='__metadata__'),default=0)
  if end<0 or 8+length+end>size:return f'truncated checkpoint: {path.name} ({size} bytes; expected at least {8+length+end})'
 except (OSError,ValueError,KeyError,TypeError) as error:return f'invalid checkpoint {path.name}: {error}'
 return None

def check_model(directory):
 path=pathlib.Path(directory).expanduser().resolve();errors=[];config={}
 try:
  config=json.loads((path/'config.json').read_text())
  if not isinstance(config,dict):raise ValueError('config root must be a JSON object')
 except (OSError,ValueError) as error:
  errors.append(f'cannot read config.json: {error}');config={}
 if not (path/'tokenizer.json').is_file():errors.append('missing tokenizer.json')
 index=path/'model.safetensors.index.json';single=path/'model.safetensors';files=[]
 if index.is_file():
  try:
   manifest=json.loads(index.read_text())
   if not isinstance(manifest,dict) or not isinstance(manifest.get('weight_map'),dict):raise ValueError('weight_map must be a JSON object')
   names=sorted(set(manifest['weight_map'].values()))
   if not names:errors.append('empty checkpoint weight_map')
   for name in names:
    if pathlib.Path(name).name!=name:errors.append(f'invalid shard filename in index: {name}');continue
    shard=path/name
    if not shard.is_file():errors.append(f'missing shard: {name}')
    else:files.append(shard)
  except (OSError,ValueError,KeyError,TypeError) as error:errors.append(f'invalid model.safetensors.index.json: {error}')
 elif single.is_file():files=[single]
 else:
  shards=sorted(path.glob('model-*-of-*.safetensors'));files=shards
  if shards:
   errors.append('missing model.safetensors.index.json for sharded checkpoint')
   totals=[int(m.group(1)) for f in shards if (m:=re.fullmatch(r'model-\d+-of-(\d+)\.safetensors',f.name))]
   if totals and len(shards)!=max(totals):errors.append(f'incomplete checkpoint: only {len(shards)}/{max(totals)} weight shards present')
  else:errors.append('missing model.safetensors or model.safetensors.index.json')
 for file in files:
  problem=check_weight_file(file)
  if problem:errors.append(problem)
 model_type=config.get('model_type','')
 if model_type=='qwen3_5_moe':
  errors.append('NeurX native qwen3_5_moe decoder is not implemented: requires Gated DeltaNet, gated full attention, partial RoPE, and Qwen MoE; changing the model path cannot enable it')
 return dict(directory=str(path),model_type=model_type,architectures=config.get('architectures',[]),weight_files_present=len(files),errors=errors)

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory');parser.add_argument('--json',action='store_true');args=parser.parse_args();report=check_model(args.directory)
 if args.json:print(json.dumps(report,ensure_ascii=False,indent=2))
 elif report['errors']:
  print(f'Model preflight failed: {report["directory"]}',file=sys.stderr)
  for error in report['errors']:print('  - '+error,file=sys.stderr)
 else:print(f'Model asset preflight passed: {report["directory"]}')
 return 1 if report['errors'] else 0
if __name__=='__main__':sys.exit(main())
