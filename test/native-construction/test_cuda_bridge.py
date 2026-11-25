"""Native shared-library ABI regression, with tiny DeepSeek or real Qwen weights."""
import ctypes,json,pathlib,sys
lib=ctypes.CDLL(str(pathlib.Path(sys.argv[1]).resolve()))
model=pathlib.Path(sys.argv[2]).resolve();c=json.loads((model/'config.json').read_text())
for n,args,result in [
 ('neurx_s_cuda_config_dimensions',[ctypes.c_char_p]+[ctypes.c_int]*5,ctypes.c_int),
 ('neurx_s_cuda_config_attention',[ctypes.c_int]*4,ctypes.c_int),
 ('neurx_s_cuda_config_finalize',[ctypes.c_char_p]*2+[ctypes.c_int]*3,ctypes.c_int),
 ('neurx_s_cuda_session_create',[],ctypes.c_int),
 ('neurx_s_cuda_session_destroy',[ctypes.c_int],ctypes.c_int),
 ('neurx_s_cuda_session_begin',[ctypes.c_int,ctypes.c_char_p,ctypes.c_int],ctypes.c_int),
 ('neurx_s_cuda_session_next',[ctypes.c_int],ctypes.c_int),
 ('neurx_s_cuda_session_error',[ctypes.c_int],ctypes.c_char_p),
 ('neurx_s_cuda_session_result',[ctypes.c_int],ctypes.c_char_p),
 ('neurx_s_cuda_last_error',[],ctypes.c_char_p),
 ('neurx_s_cuda_prompt_format',[],ctypes.c_char_p)]:
 f=getattr(lib,n);f.argtypes=args;f.restype=result
assert lib.neurx_s_cuda_config_dimensions(str(model).encode(),0,c['vocab_size'],c['hidden_size'],c['intermediate_size'],c['num_hidden_layers'])==0
assert lib.neurx_s_cuda_config_attention(c['num_attention_heads'],c['num_key_value_heads'],c['hidden_size']//c['num_attention_heads'],c['max_position_embeddings'])==0
assert lib.neurx_s_cuda_config_finalize(str(c['rms_norm_eps']).encode(),str(c['rope_theta']).encode(),c.get('attention_bias',True),c.get('mlp_bias',False),c.get('tie_word_embeddings',False))==0,lib.neurx_s_cuda_last_error()
isdeep=c['model_type']=='deepseek_v2'
assert lib.neurx_s_cuda_prompt_format()==(b'plain' if isdeep else b'chatml')
session=lib.neurx_s_cuda_session_create();assert session>0
prompt=b'a' if isdeep else b'Write a detailed explanation of how computers work, covering processors, memory, storage, and operating systems.'
results=[]
for run in range(2):
 assert lib.neurx_s_cuda_session_begin(session,prompt,8)>0,lib.neurx_s_cuda_session_error(session)
 ids=[]
 for _ in range(8):
  token=lib.neurx_s_cuda_session_next(session)
  assert token>=-1,lib.neurx_s_cuda_session_error(session)
  if token==-1:break
  ids.append(token)
 results.append(ids)
assert results[0]==results[1] and results[0],results
if not isdeep:
 output=lib.neurx_s_cuda_session_result(session).decode();print('Qwen output:',repr(output));assert output.startswith('Computers work'),output
else:
 assert lib.neurx_s_cuda_session_begin(session,b'a',999999)==-1
 assert b'context' in lib.neurx_s_cuda_session_error(session).lower()
assert lib.neurx_s_cuda_session_destroy(session)==0
print('PASS: S/CUDA configuration ABI, prompt mode, generation, repeated begin, session cleanup',model)
