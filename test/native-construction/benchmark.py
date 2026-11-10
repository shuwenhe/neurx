#!/usr/bin/env python3
"""Native construction benchmark; never performs or substitutes model inference."""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SIZES=(4096,8192,16384,32768,1000000,10000000)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--compiler',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--mode',choices=('bf16','indexed'),default='bf16')
    args=ap.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    data=out/'bf16.bin';data.write_bytes(b'\x80\x3f'*max(SIZES))
    source=out/'bulk.s'
    source.write_text('''package main
import ("neurx.runtime.tensor_builder")
extern "intrinsic" func __int_to_string(int value) string
extern "intrinsic" func __std_clock_ns(int kind) int
func main(int count) int {
    int started = __std_clock_ns(1)
    float_construction_result result = read_float_tensor_range("DATA", 0, count, 1)
    int elapsed = __std_clock_ns(1) - started
    if !result.ok || len(result.values) != count { return 1 }
    if result.values[0] != 1.0 || result.values[count - 1] != 1.0 { return 2 }
    if construction_stat(0) != 2 || construction_stat(3) != 0 || construction_stat(5) != 0 || construction_stat(7) != count { return 3 }
    println("construction_ns=" + __int_to_string(elapsed))
    int i = 0
    for i < 8 { println("metric" + __int_to_string(i) + "=" + __int_to_string(construction_stat(i))); i = i + 1 }
    return 0
}
'''.replace('DATA',str(data)))
    if args.mode=='indexed':
        text=source.read_text().replace('float_construction_result result = read_float_tensor_range("'+str(data)+'", 0, count, 1)', 'int id = new_float_builder(count)\n    int index = 0\n    for index < count { if builder_set_float(id, index, 1.0) != 0 { return 4 }; index = index + 1 }\n    float_construction_result result = finish_float_builder(id)').replace('construction_stat(7) != count','construction_stat(7) != 0 || construction_stat(4) != count')
        source.write_text(text)
    with (out/'build.log').open('w') as log:
        subprocess.run([str(args.compiler),'--compile-unit',str(out/'bulk.sasm'),str(source),str(ROOT/'src/runtime/tensor_builder/tensor_builder.s')],stdout=log,stderr=subprocess.STDOUT,check=True)
        subprocess.run([str(args.compiler),'--emit-bin',str(out/'bulk.sasm'),str(out/'bulk')],stdout=log,stderr=subprocess.STDOUT,check=True)
    records=[]
    for n in SIZES:
        logpath=out/f'{n}.log'
        with logpath.open('w') as log:
            start=time.perf_counter();child=subprocess.Popen([str(out/'bulk'),str(n)],stdout=log,stderr=subprocess.STDOUT)
            _,status,usage=os.wait4(child.pid,0);child.returncode=os.waitstatus_to_exitcode(status);wall=time.perf_counter()-start
        if child.returncode: raise RuntimeError(logpath.read_text())
        values=dict(line.split('=',1) for line in logpath.read_text().splitlines())
        ns=int(values['construction_ns']);records.append(dict(elements=n,wall_s=wall,cpu_user_s=usage.ru_utime,cpu_system_s=usage.ru_stime,peak_rss_kib=usage.ru_maxrss,construction_ns=ns,allocations=int(values['metric0']),requested_bytes=int(values['metric1']),rounded_bytes=int(values['metric2']),copied_bytes=int(values['metric3']),live_builders=int(values['metric5']),read_bytes=int(values['metric6']),decoded=int(values['metric7']),elements_per_s=n*1e9/ns,input_bytes_per_s=(2*n*1e9/ns if args.mode=='bf16' else 0),output_bytes_per_s=8*n*1e9/ns))
        (out/'results.json').write_text(json.dumps(dict(mode=args.mode,compiler=str(args.compiler),compiler_sha256=hashlib.sha256(args.compiler.read_bytes()).hexdigest(),allocation_scope='builder and bulk operations only',results=records),indent=2)+'\n')
if __name__=='__main__':main()
