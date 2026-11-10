// Independent double-precision Qwen reference, used only to verify S output.
// This executable is never called by NeurX and cannot be its inference backend.
#include "../../src/runtime/model/json.h"
#include "../../src/runtime/model/bpe_tokenizer.h"
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <vector>
using neurx::runtime::model::json;
using Vec=std::vector<double>;
struct Weights {
    int fd=-1;size_t length=0;const unsigned char*bytes=nullptr;size_t start=0;json header;
    explicit Weights(const std::string& path) {
        fd=open(path.c_str(),O_RDONLY);if(fd<0)throw std::runtime_error("open weights");
        struct stat st{};if(fstat(fd,&st))throw std::runtime_error("stat weights");length=st.st_size;
        auto mapped=mmap(nullptr,length,PROT_READ,MAP_PRIVATE,fd,0);if(mapped==MAP_FAILED)throw std::runtime_error("mmap weights");bytes=static_cast<unsigned char*>(mapped);
        uint64_t size=0;std::memcpy(&size,bytes,8);start=8+size;if(start>length)throw std::runtime_error("header size");header=json::parse(std::string(reinterpret_cast<const char*>(bytes+8),size));
    }
    ~Weights(){if(bytes)munmap(const_cast<unsigned char*>(bytes),length);if(fd>=0)close(fd);}
    const uint16_t* tensor(const std::string&name,const std::vector<int64_t>&shape) const {
        const auto& info=header.at(name);if(info.at("dtype").as_string()!="BF16")throw std::runtime_error("not BF16: "+name);
        const auto& actual=info.at("shape").as_array();if(actual.size()!=shape.size())throw std::runtime_error("rank: "+name);
        int64_t count=1;for(size_t i=0;i<shape.size();i++){if(actual[i].as_int()!=shape[i])throw std::runtime_error("shape: "+name);count*=shape[i];}
        auto begin=info.at("data_offsets").as_array()[0].as_int(),end=info.at("data_offsets").as_array()[1].as_int();
        if(begin<0||end-begin!=count*2||start+end>length)throw std::runtime_error("range: "+name);
        return reinterpret_cast<const uint16_t*>(bytes+start+begin);
    }
};
double bf(uint16_t bits){uint32_t word=uint32_t(bits)<<16;float value;std::memcpy(&value,&word,4);return value;}
Vec matvec(const uint16_t* matrix,int rows,int columns,const Vec& input){Vec out(rows);for(int r=0;r<rows;r++)for(int c=0;c<columns;c++)out[r]+=bf(matrix[size_t(r)*columns+c])*input[c];return out;}
Vec norm(const Vec& input,const uint16_t* weight,double epsilon){double square=0;for(double x:input)square+=x*x;double scale=1/std::sqrt(square/input.size()+epsilon);Vec out(input.size());for(size_t i=0;i<input.size();i++)out[i]=input[i]*scale*bf(weight[i]);return out;}
void add(Vec& target,const Vec& source){for(size_t i=0;i<target.size();i++)target[i]+=source[i];}
void rope(Vec& values,int heads,int dim,int pos,double theta){for(int head=0;head<heads;head++)for(int i=0;i<dim/2;i++){double angle=pos/std::pow(theta,2.*i/dim),left=values[head*dim+i],right=values[head*dim+i+dim/2];values[head*dim+i]=left*std::cos(angle)-right*std::sin(angle);values[head*dim+i+dim/2]=right*std::cos(angle)+left*std::sin(angle);}}
int main(int argc,char**argv){
    if(argc!=4){std::cerr<<"usage: reference MODEL LOGITS_JSON NEW_TOKENS\n";return 2;}
    try{
        std::string directory=argv[1];auto cfg=json::parse_file(directory+"/config.json");Weights w(directory+"/model.safetensors");
        int h=cfg.at("hidden_size").as_int(),inter=cfg.at("intermediate_size").as_int(),layers=cfg.at("num_hidden_layers").as_int(),heads=cfg.at("num_attention_heads").as_int(),kvheads=cfg.at("num_key_value_heads").as_int(),vocab=cfg.at("vocab_size").as_int(),dim=h/heads,kv=kvheads*dim;
        double epsilon=cfg.at("rms_norm_eps").as_number(),theta=cfg.at("rope_theta").as_number();
        const auto* embedding=w.tensor("model.embed_tokens.weight",{vocab,h});const auto* finalnorm=w.tensor("model.norm.weight",{h});
        const auto* lm=w.header.contains("lm_head.weight")?w.tensor("lm_head.weight",{vocab,h}):embedding;
        auto tokenizer=neurx::runtime::model::bpe_tokenizer::from_directory(directory);auto prompt=tokenizer.encode("Explain how a compiler performs semantic analysis.");
        std::cout<<std::setprecision(17)<<"prompt";for(auto t:prompt)std::cout<<' '<<t;std::cout<<'\n';
        uint64_t validated=0,bytes=0;for(const auto& pair:w.header.as_object())if(pair.first!="__metadata__"){
            const auto& info=pair.second;auto begin=info.at("data_offsets").as_array()[0].as_int(),end=info.at("data_offsets").as_array()[1].as_int();
            if(info.at("dtype").as_string()!="BF16"||begin<0||end<begin||w.start+end>w.length)throw std::runtime_error("tensor range");
            const auto*p=reinterpret_cast<const uint16_t*>(w.bytes+w.start+begin);for(int64_t i=0;i<(end-begin)/2;i++)if(!std::isfinite(bf(p[i])))throw std::runtime_error("nonfinite weight");validated++;bytes+=end-begin;
        }
        std::cout<<"validated_tensors "<<validated<<" weight_bytes "<<bytes<<'\n';
        std::vector<Vec> keys(layers),values(layers);int position=0;
        auto forward=[&](int token){
            Vec hidden(h);for(int i=0;i<h;i++)hidden[i]=bf(embedding[size_t(token)*h+i]);
            for(int l=0;l<layers;l++){
                std::string pre="model.layers."+std::to_string(l)+".";
                auto n=norm(hidden,w.tensor(pre+"input_layernorm.weight",{h}),epsilon);
                auto q=matvec(w.tensor(pre+"self_attn.q_proj.weight",{h,h}),h,h,n),k=matvec(w.tensor(pre+"self_attn.k_proj.weight",{kv,h}),kv,h,n),v=matvec(w.tensor(pre+"self_attn.v_proj.weight",{kv,h}),kv,h,n);
                for(auto pair:{std::make_pair(&q,"q_proj"),std::make_pair(&k,"k_proj"),std::make_pair(&v,"v_proj")}){auto*bias=w.tensor(pre+"self_attn."+pair.second+".bias",{int64_t(pair.first->size())});for(size_t i=0;i<pair.first->size();i++)(*pair.first)[i]+=bf(bias[i]);}
                rope(q,heads,dim,position,theta);rope(k,kvheads,dim,position,theta);keys[l].insert(keys[l].end(),k.begin(),k.end());values[l].insert(values[l].end(),v.begin(),v.end());Vec attended(h);
                for(int head=0;head<heads;head++){int kh=head/(heads/kvheads);Vec scores(position+1);for(int t=0;t<=position;t++){for(int d=0;d<dim;d++)scores[t]+=q[head*dim+d]*keys[l][t*kv+kh*dim+d];scores[t]/=std::sqrt(double(dim));}double maximum=*std::max_element(scores.begin(),scores.end()),denom=0;for(auto&score:scores){score=std::exp(score-maximum);denom+=score;}for(int d=0;d<dim;d++)for(int t=0;t<=position;t++)attended[head*dim+d]+=scores[t]/denom*values[l][t*kv+kh*dim+d];}
                add(hidden,matvec(w.tensor(pre+"self_attn.o_proj.weight",{h,h}),h,h,attended));
                n=norm(hidden,w.tensor(pre+"post_attention_layernorm.weight",{h}),epsilon);auto gate=matvec(w.tensor(pre+"mlp.gate_proj.weight",{inter,h}),inter,h,n),up=matvec(w.tensor(pre+"mlp.up_proj.weight",{inter,h}),inter,h,n);for(int i=0;i<inter;i++)gate[i]=gate[i]/(1+std::exp(-gate[i]))*up[i];add(hidden,matvec(w.tensor(pre+"mlp.down_proj.weight",{h,inter}),h,inter,gate));
                for(auto x:hidden)if(!std::isfinite(x))throw std::runtime_error("nonfinite activation");
                if(position==0){double sum=0,square=0;for(double x:hidden){sum+=x;square+=x*x;}std::cout<<"layer "<<l<<" first "<<hidden[0]<<" middle "<<hidden[h/2]<<" last "<<hidden[h-1]<<" sum "<<sum<<" square "<<square<<'\n';}
            }
            position++;return hidden;
        };
        Vec hidden;for(auto token:prompt)hidden=forward(token);
        for(int step=0;step<std::stoi(argv[3]);step++){
            auto logits=matvec(lm,vocab,h,norm(hidden,finalnorm,epsilon));int best=std::max_element(logits.begin(),logits.end())-logits.begin();
            if(step==0){std::ofstream out(argv[2]);out<<std::setprecision(17)<<'[';for(int i=0;i<vocab;i++){if(i)out<<',';out<<logits[i];}out<<"]\n";}
            std::cout<<"generated "<<step<<' '<<best<<" logit "<<logits[best]<<'\n';std::cout.flush();
            if(step+1<std::stoi(argv[3]))hidden=forward(best);
        }
    }catch(const std::exception&error){std::cerr<<error.what()<<'\n';return 1;}
}
