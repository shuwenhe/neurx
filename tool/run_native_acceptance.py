#!/usr/bin/env python3
"""Execute a native NeurX binary and preserve acceptance evidence, never inference in Python."""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path
PROMPT='Explain how a compiler performs semantic analysis.'
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',type=Path,required=True);ap.add_argument('--model',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--tokens',type=int,default=32);ap.add_argument('--dump-logits',action='store_true');args=ap.parse_args()
    root=Path(__file__).resolve().parents[1];out=args.output.resolve();out.relative_to(root);out.mkdir(parents=True,exist_ok=False)
    environment={k:v for k,v in os.environ.items() if not k.startswith('NEURX_')};environment.update(NEURX_MODEL=str(args.model.resolve()),NEURX_PROMPT=PROMPT,NEURX_MAX_TOKENS=str(args.tokens),NEURX_ROUTE='native',NEURX_TRACE='true',NEURX_TRACE_NUMERICS='true',NEURX_DUMP_LOGITS='true' if args.dump_logits else 'false',TMPDIR=str(root/'artifact/local-inference/array-construction-20261110/tmp'))
    record=dict(binary=str(args.binary.resolve()),binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),model=str(args.model.resolve()),prompt=PROMPT,requested_tokens=args.tokens,environment={k:v for k,v in environment.items() if k.startswith('NEURX_')},milestones=[])
    (out/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
    started=time.perf_counter()
    with (out/'native.log').open('wb') as log:
        child=subprocess.Popen([str(args.binary.resolve())],cwd=root,env=environment,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        record['pid']=child.pid
        for line in child.stdout:
            log.write(line)
            if b'[neurx-hf]' in line:
                record['milestones'].append(dict(wall_s=time.perf_counter()-started,line=line.decode('utf-8','replace').strip()))
                if b'token step=' in line or b'loaded layer=' in line or b'prompt tokens=' in line or b'loading model' in line:
                    log.flush();(out/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
        _,status,usage=os.wait4(child.pid,0);child.returncode=os.waitstatus_to_exitcode(status)
    record.update(exit=child.returncode,wall_s=time.perf_counter()-started,cpu_user_s=usage.ru_utime,cpu_system_s=usage.ru_stime,peak_rss_kib=usage.ru_maxrss)
    (out/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({k:v for k,v in record.items() if k!='milestones'},indent=2))
    raise SystemExit(child.returncode)
if __name__=='__main__':main()
