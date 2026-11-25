"""Independent NumPy DeepSeek-V2 equations; no native decoder implementation reuse."""
import json,math,pathlib,sys
import numpy as np
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
c=dict(model_type='deepseek_v2',hidden_size=16,vocab_size=32,num_hidden_layers=2,num_attention_heads=2,num_key_value_heads=2,intermediate_size=24,kv_lora_rank=8,q_lora_rank=None,qk_nope_head_dim=4,qk_rope_head_dim=4,v_head_dim=4,n_routed_experts=4,n_shared_experts=1,num_experts_per_tok=2,moe_intermediate_size=12,first_k_dense_replace=1,moe_layer_freq=1,norm_topk_prob=False,routed_scaling_factor=1.,topk_method='greedy',scoring_func='softmax',rms_norm_eps=1e-6,rope_theta=10000.,max_position_embeddings=128,bos_token_id=1,eos_token_id=2,attention_bias=False,mlp_bias=False,tie_word_embeddings=False,hidden_act='silu',rope_scaling=dict(type='yarn',factor=4.,original_max_position_embeddings=16,beta_fast=32.,beta_slow=1.,mscale=.707,mscale_all_dim=.707))
rng=np.random.default_rng(42);w={}; raw={}
def add(n,shape,norm=False):
 a=(np.ones(shape) if norm else rng.normal(0,.12,shape)).astype(np.float32)
 bits=a.view(np.uint32); bf=((bits+0x7fff+((bits>>16)&1))>>16).astype(np.uint16)
 w[n]=(bf.astype(np.uint32)<<16).view(np.float32);raw[n]=bf
add('model.embed_tokens.weight',(32,16));add('model.norm.weight',(16,),True);add('lm_head.weight',(32,16))
for i in range(2):
 p=f'model.layers.{i}.'
 for n in ['input_layernorm','post_attention_layernorm']:add(p+n+'.weight',(16,),True)
 for n,shape in [('q_proj',(16,16)),('kv_a_proj_with_mqa',(12,16)),('kv_a_layernorm',(8,)),('kv_b_proj',(16,8)),('o_proj',(16,8))]:add(p+'self_attn.'+n+'.weight',shape,n=='kv_a_layernorm')
 roots=[(p+'mlp.',24)] if i==0 else [(p+'mlp.shared_experts.',12)]+[(p+f'mlp.experts.{j}.',12) for j in range(4)]
 if i:add(p+'mlp.gate.weight',(4,16))
 for r,d in roots:
  for n,shape in [('gate_proj',(d,16)),('up_proj',(d,16)),('down_proj',(16,d))]:add(r+n+'.weight',shape)
header={};payload=b''
for n,a in raw.items():
 b=a.astype('<u2').tobytes();header[n]=dict(dtype='BF16',shape=list(a.shape),data_offsets=[len(payload),len(payload)+len(b)]);payload+=b
h=json.dumps(header,separators=(',',':')).encode();h+=b' '*((-len(h))%8)
(out/'model.safetensors').write_bytes(len(h).to_bytes(8,'little')+h+payload)
(out/'config.json').write_text(json.dumps(c))
def norm(x,n):return x/np.sqrt(np.mean(x*x)+c['rms_norm_eps'])*w[n]
def lin(x,n):return w[n+'.weight']@x
def mlp(x,p):
 g=lin(x,p+'gate_proj');return lin((g/(1+np.exp(-g)))*lin(x,p+'up_proj'),p+'down_proj')
r=c['rope_scaling'];dim=4
corr=lambda b:dim*math.log(r['original_max_position_embeddings']/(b*2*math.pi))/(2*math.log(c['rope_theta']))
lo=max(math.floor(corr(r['beta_fast'])),0);hi=min(math.ceil(corr(r['beta_slow'])),dim-1)
if lo==hi:hi+=.001
ramp=np.clip((np.arange(dim//2)-lo)/(hi-lo),0,1)
freq=c['rope_theta']**(-np.arange(0,dim,2)/dim)*((1-ramp)+ramp/r['factor'])
ms=lambda v:1+.1*v*math.log(r['factor'])
scale=ms(r['mscale_all_dim'])**2/math.sqrt(8)
def rope(x,pos):
 a=x[...,::2];b=x[...,1::2];angle=pos*freq
 return np.concatenate((a*np.cos(angle)-b*np.sin(angle),b*np.cos(angle)+a*np.sin(angle)),axis=-1)*ms(r['mscale'])/ms(r['mscale_all_dim'])
cache=[([],[]) for _ in range(2)]; logits=[]; routes=[]
for pos,t in enumerate([1,5,7,9]):
 x=w['model.embed_tokens.weight'][t].copy()
 for i in range(2):
  p=f'model.layers.{i}.';a=p+'self_attn.';z=norm(x,p+'input_layernorm.weight')
  q=lin(z,a+'q_proj').reshape(2,8);qa=np.concatenate((q[:,:4],rope(q[:,4:],pos)),axis=-1)
  ka=lin(z,a+'kv_a_proj_with_mqa');kv=lin(norm(ka[:8],a+'kv_a_layernorm.weight'),a+'kv_b_proj').reshape(2,8)
  k=np.concatenate((kv[:,:4],np.broadcast_to(rope(ka[8:],pos),(2,4))),axis=-1)
  cache[i][0].append(k);cache[i][1].append(kv[:,4:]);ks=np.array(cache[i][0]);vs=np.array(cache[i][1])
  scores=np.einsum('hd,thd->ht',qa,ks)*scale;scores=np.exp(scores-scores.max(axis=-1,keepdims=True));scores/=scores.sum(axis=-1,keepdims=True)
  x=x+lin(np.einsum('ht,thd->hd',scores,vs).reshape(-1),a+'o_proj');z=norm(x,p+'post_attention_layernorm.weight')
  if i==0:y=mlp(z,p+'mlp.')
  else:
   sc=lin(z,p+'mlp.gate');sc=np.exp(sc-sc.max());sc/=sc.sum();idx=np.argsort(-sc)[:2];routes.append(idx.tolist());y=mlp(z,p+'mlp.shared_experts.')
   for j in idx:y+=sc[j]*mlp(z,p+f'mlp.experts.{j}.')
  x=x+y
 logits.append(lin(norm(x,'model.norm.weight'),'lm_head').tolist())
(out/'expected.json').write_text(json.dumps(dict(ids=[1,5,7,9],logits=logits,routes=routes)))
print('Generated independent BF16 MLA/YaRN/MoE fixture',out)
