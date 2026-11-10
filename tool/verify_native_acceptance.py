#!/usr/bin/env python3
"""Compare preserved native evidence with independent verification data; no inference."""
import argparse,json,math,re,hashlib
from pathlib import Path
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--run',type=Path,required=True);ap.add_argument('--reference-log',type=Path,required=True);ap.add_argument('--reference-logits',type=Path,required=True);ap.add_argument('--build-manifest',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    lines=(args.run/'native.log').read_text().splitlines();execution=json.loads((args.run/'execution.json').read_text());reference=args.reference_log.read_text().splitlines();ref_logits=json.loads(args.reference_logits.read_text());build=json.loads(args.build_manifest.read_text());assert execution['exit']==0
    prompt=[int(x) for x in next(x for x in reference if x.startswith('prompt ')).split()[1:]]
    native_prompt=[int(x) for x in next(x for x in lines if 'prompt tokens=' in x).split('tokens=')[1].split(',')];assert native_prompt==prompt
    generated=[int(x) for x in next(x for x in lines if 'generated tokens=' in x).split('tokens=')[1].split(',')]
    ref_tokens=[int(x.split()[2]) for x in reference if x.startswith('generated ')];assert len(generated)>=32 and generated==ref_tokens
    logits={int(m[1]):int(m[2])/1e6 for x in lines if (m:=re.match(r'\[neurx-logit\] index=(\d+) micro=(-?\d+)$',x))};assert len(logits)==len(ref_logits)==151936
    errors=[abs(logits[i]-value) for i,value in enumerate(ref_logits)];assert all(math.isfinite(v) for v in logits.values()) and max(errors)<1.1e-6
    argmax=max(logits,key=logits.get);assert argmax==max(range(len(ref_logits)),key=ref_logits.__getitem__)==generated[0]
    activations={int(m[1]):[int(v)/1e6 for v in m.groups()[1:]] for x in lines if (m:=re.match(r'\[neurx-activation\] layer=(\d+) first_micro=(-?\d+) middle_micro=(-?\d+) last_micro=(-?\d+) sum_micro=(-?\d+) square_micro=(-?\d+)$',x))}
    activation_errors=[]
    for x in reference:
        if x.startswith('layer '):
            fields=x.split();layer=int(fields[1]);expected=[float(fields[i]) for i in (3,5,7,9,11)];activation_errors.extend(abs(a-b) for a,b in zip(activations[layer],expected))
    assert len(activations)==24 and max(activation_errors)<2e-5
    forwards=[tuple(map(int,m.groups())) for x in lines if (m:=re.search(r'layer forward position=(\d+) layer=(\d+)',x))]
    positions=len(prompt)+len(generated)-1;assert set(forwards)=={(p,l) for p in range(positions) for l in range(24)} and len(forwards)==positions*24
    loaded=re.search(r'all model weights loaded source_bytes=(\d+) elements=(\d+) elapsed_ns=(\d+)', '\n'.join(lines));assert loaded and int(loaded[1])==988065536 and int(loaded[2])==494032768
    timings=[(int(m[1]),int(m[2])) for x in lines if (m:=re.search(r'token step=(\d+) id=\d+ ready_ns=(\d+)',x))];assert [step for step,_ in timings]==list(range(32))
    ready=[ns/1e9 for _,ns in timings];intervals=[b-a for a,b in zip(ready,ready[1:])];mean=sum(logits.values())/len(logits)
    compiler=Path(build['compiler']);assert compiler.is_file() and hashlib.sha256(compiler.read_bytes()).hexdigest()==build['compiler_sha256'];assert hashlib.sha256(Path(execution['binary']).read_bytes()).hexdigest()==execution['binary_sha256']
    report=dict(status='native inference acceptance passed',compiler=build['compiler'],compiler_sha256=build['compiler_sha256'],binary=execution['binary'],binary_sha256=execution['binary_sha256'],prompt_tokens=prompt,generated_tokens=generated,generated_count=len(generated),layers=24,forward_passes=positions,layer_executions=len(forwards),loaded_tensors=290,source_weight_bytes=int(loaded[1]),decoded_elements=int(loaded[2]),model_loading_s=int(loaded[3])/1e9,logits_count=len(logits),logits_max_abs_error=max(errors),logits_rms_error=math.sqrt(sum(x*x for x in errors)/len(errors)),logits_quantization=1e-6,activation_max_abs_error=max(activation_errors),argmax=argmax,argmax_agreement=True,all_32_tokens_agree=True,logits_min=min(logits.values()),logits_max=max(logits.values()),logits_mean=mean,logits_std=math.sqrt(sum((v-mean)**2 for v in logits.values())/len(logits)),generation_ttft_s=ready[0],mean_inter_token_s=sum(intervals)/len(intervals),generation_tokens_per_s=31/(ready[-1]-ready[0]),wall_s=execution['wall_s'],cpu_user_s=execution['cpu_user_s'],cpu_system_s=execution['cpu_system_s'],cpu_utilization_one_core_percent=100*(execution['cpu_user_s']+execution['cpu_system_s'])/execution['wall_s'],peak_rss_kib=execution['peak_rss_kib'],tracing_overhead_included=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
