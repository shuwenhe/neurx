"""Independent NumPy text-only Qwen2.5-VL GQA, bias, half-split RoPE reference."""
import json,pathlib,sys
import numpy as np
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
c=dict(model_type='qwen2_5_vl',hidden_size=16,vocab_size=32,num_hidden_layers=2,num_attention_heads=4,num_key_value_heads=2,intermediate_size=24,rms_norm_eps=1e-6,rope_theta=10000.,max_position_embeddings=64,bos_token_id=1,eos_token_id=2,hidden_act='silu',use_sliding_window=False,tie_word_embeddings=False,rope_scaling={'type':'mrope','mrope_section':[1,0,1]})
rng=np.random.default_rng(77);w={};raw={}
def add(n,shape,norm=False):
 a=(np.ones(shape) if norm else rng.normal(0,.13,shape)).astype(np.float32);bits=a.view(np.uint32);bf=((bits+0x7fff+((bits>>16)&1))>>16).astype(np.uint16);raw[n]=bf;w[n]=(bf.astype(np.uint32)<<16).view(np.float32)
add('model.embed_tokens.weight',(32,16));add('model.norm.weight',(16,),True);add('lm_head.weight',(32,16))
for i in range(2):
 p=f'model.layers.{i}.'
 for n in ['input_layernorm','post_attention_layernorm']:add(p+n+'.weight',(16,),True)
 for n,d in [('q_proj',16),('k_proj',8),('v_proj',8)]:add(p+'self_attn.'+n+'.weight',(d,16));add(p+'self_attn.'+n+'.bias',(d,))
 add(p+'self_attn.o_proj.weight',(16,16))
 for n,shape in [('gate_proj',(24,16)),('up_proj',(24,16)),('down_proj',(16,24))]:add(p+'mlp.'+n+'.weight',shape)
header={};payload=b''
for n,a in raw.items():
 b=a.astype('<u2').tobytes();header[n]=dict(dtype='BF16',shape=list(a.shape),data_offsets=[len(payload),len(payload)+len(b)]);payload+=b
h=json.dumps(header,separators=(',',':')).encode();h+=b' '*((-len(h))%8);(out/'model.safetensors').write_bytes(len(h).to_bytes(8,'little')+h+payload);(out/'config.json').write_text(json.dumps(c))
def norm(x,n):return x/np.sqrt(np.mean(x*x)+c['rms_norm_eps'])*w[n]
def lin(x,n):return w[n+'.weight']@x+(w[n+'.bias'] if n+'.bias' in w else 0)
def rope(x,pos):
 f=pos*c['rope_theta']**(-np.arange(2)/2);a=x[...,:2];b=x[...,2:];return np.concatenate((a*np.cos(f)-b*np.sin(f),b*np.cos(f)+a*np.sin(f)),axis=-1)
cache=[([],[]) for _ in range(2)];logits=[]
for pos,t in enumerate([1,5,7,9]):
 x=w['model.embed_tokens.weight'][t].copy()
 for i in range(2):
  p=f'model.layers.{i}.';a=p+'self_attn.';z=norm(x,p+'input_layernorm.weight');q=rope(lin(z,a+'q_proj').reshape(4,4),pos);k=rope(lin(z,a+'k_proj').reshape(2,4),pos);v=lin(z,a+'v_proj').reshape(2,4)
  cache[i][0].append(k);cache[i][1].append(v);ks=np.repeat(np.array(cache[i][0]),2,axis=1);vs=np.repeat(np.array(cache[i][1]),2,axis=1)
  scores=np.einsum('hd,thd->ht',q,ks)/2;scores=np.exp(scores-scores.max(axis=-1,keepdims=True));scores/=scores.sum(axis=-1,keepdims=True)
  x+=lin(np.einsum('ht,thd->hd',scores,vs).reshape(-1),a+'o_proj');z=norm(x,p+'post_attention_layernorm.weight');g=lin(z,p+'mlp.gate_proj');x+=lin(g/(1+np.exp(-g))*lin(z,p+'mlp.up_proj'),p+'mlp.down_proj')
 logits.append(lin(norm(x,'model.norm.weight'),'lm_head').tolist())
(out/'expected.json').write_text(json.dumps(dict(logits=logits)))
print('Generated independent Qwen VL text reference')
