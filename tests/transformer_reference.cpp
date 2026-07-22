#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <fstream>
#include <random>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

using Vec = std::vector<double>;

struct Config { int vocab=16, seq=4, dim=8, heads=2, ffn=16; };

struct Param {
    Vec v, g;
    Param() = default;
    explicit Param(size_t n) : v(n), g(n) {}
    void zero_grad() { std::fill(g.begin(), g.end(), 0.0); }
};

struct Model {
    Config c;
    Param emb, nq, nk, wq, wk, wv, wo, nf, wg, wu, wd, out;
    explicit Model(Config cfg) : c(cfg), emb(cfg.vocab*cfg.dim), nq(cfg.dim), nk(cfg.dim),
        wq(cfg.dim*cfg.dim), wk(cfg.dim*cfg.dim), wv(cfg.dim*cfg.dim),
        wo(cfg.dim*cfg.dim), nf(cfg.dim), wg(cfg.dim*cfg.ffn),
        wu(cfg.dim*cfg.ffn), wd(cfg.ffn*cfg.dim), out(cfg.dim*cfg.vocab) {
        std::mt19937 rng(7); std::normal_distribution<double> n(0.0, 0.08);
        for (Param* p : params()) for (double& x : p->v) x=n(rng);
        std::fill(nq.v.begin(),nq.v.end(),1.0); std::fill(nk.v.begin(),nk.v.end(),1.0);
        std::fill(nf.v.begin(),nf.v.end(),1.0);
    }
    std::vector<Param*> params() { return {&emb,&nq,&nk,&wq,&wk,&wv,&wo,&nf,&wg,&wu,&wd,&out}; }
    void zero_grad() { for (Param* p:params()) p->zero_grad(); }
};

struct AdamW {
    double lr=0.03, beta1=0.9, beta2=0.999, eps=1e-8, weight_decay=0.01;
    int64_t step_count=0;
    std::vector<Vec> m, v;

    explicit AdamW(const Model& model) {
        for (Param* p : const_cast<Model&>(model).params()) {
            m.emplace_back(p->v.size(), 0.0);
            v.emplace_back(p->v.size(), 0.0);
        }
    }

    void step(Model& model) {
        std::vector<Param*> ps=model.params();
        assert(ps.size()==m.size() && ps.size()==v.size());
        ++step_count;
        double bias1=1.0-std::pow(beta1,double(step_count));
        double bias2=1.0-std::pow(beta2,double(step_count));
        for(size_t n=0;n<ps.size();++n) for(size_t i=0;i<ps[n]->v.size();++i) {
            double g=ps[n]->g[i];
            m[n][i]=beta1*m[n][i]+(1.0-beta1)*g;
            v[n][i]=beta2*v[n][i]+(1.0-beta2)*g*g;
            double update=(m[n][i]/bias1)/(std::sqrt(v[n][i]/bias2)+eps);
            ps[n]->v[i]-=lr*(update+weight_decay*ps[n]->v[i]);
        }
    }
};

template <typename T>
static bool write_scalar(std::ofstream& out,const T& value) {
    out.write(reinterpret_cast<const char*>(&value),sizeof(value)); return bool(out);
}
template <typename T>
static bool read_scalar(std::ifstream& in,T& value) {
    in.read(reinterpret_cast<char*>(&value),sizeof(value)); return bool(in);
}
static bool write_vec(std::ofstream& out,const Vec& values) {
    uint64_t count=values.size();
    if(!write_scalar(out,count)) return false;
    out.write(reinterpret_cast<const char*>(values.data()),std::streamsize(count*sizeof(double)));
    return bool(out);
}
static bool read_vec(std::ifstream& in,Vec& values,size_t expected) {
    uint64_t count=0;
    if(!read_scalar(in,count) || count!=expected) return false;
    values.resize(size_t(count));
    in.read(reinterpret_cast<char*>(values.data()),std::streamsize(count*sizeof(double)));
    return bool(in);
}

static bool save_checkpoint(const std::string& path,const Model& model,const AdamW& opt,int64_t train_step) {
    std::ofstream out(path,std::ios::binary|std::ios::trunc);
    const uint64_t magic=0x4e45555258434b31ULL;
    if(!out || !write_scalar(out,magic)) return false;
    if(!write_scalar(out,model.c.vocab) || !write_scalar(out,model.c.seq) ||
       !write_scalar(out,model.c.dim) || !write_scalar(out,model.c.heads) ||
       !write_scalar(out,model.c.ffn) || !write_scalar(out,train_step) ||
       !write_scalar(out,opt.lr) || !write_scalar(out,opt.beta1) || !write_scalar(out,opt.beta2) ||
       !write_scalar(out,opt.eps) || !write_scalar(out,opt.weight_decay) || !write_scalar(out,opt.step_count)) return false;
    std::vector<Param*> ps=const_cast<Model&>(model).params();
    uint64_t count=ps.size();
    if(!write_scalar(out,count) || count!=opt.m.size() || count!=opt.v.size()) return false;
    for(size_t i=0;i<ps.size();++i)
        if(!write_vec(out,ps[i]->v) || !write_vec(out,opt.m[i]) || !write_vec(out,opt.v[i])) return false;
    return bool(out);
}

static bool load_checkpoint(const std::string& path,Model& model,AdamW& opt,int64_t& train_step) {
    std::ifstream in(path,std::ios::binary);
    const uint64_t magic=0x4e45555258434b31ULL;
    uint64_t found_magic=0, count=0; int vocab=0,seq=0,dim=0,heads=0,ffn=0;
    if(!in || !read_scalar(in,found_magic) || found_magic!=magic ||
       !read_scalar(in,vocab) || !read_scalar(in,seq) || !read_scalar(in,dim) ||
       !read_scalar(in,heads) || !read_scalar(in,ffn) ||
       vocab!=model.c.vocab || seq!=model.c.seq || dim!=model.c.dim ||
       heads!=model.c.heads || ffn!=model.c.ffn || !read_scalar(in,train_step) ||
       !read_scalar(in,opt.lr) || !read_scalar(in,opt.beta1) || !read_scalar(in,opt.beta2) ||
       !read_scalar(in,opt.eps) || !read_scalar(in,opt.weight_decay) || !read_scalar(in,opt.step_count) ||
       !read_scalar(in,count)) return false;
    std::vector<Param*> ps=model.params();
    if(count!=ps.size() || count!=opt.m.size() || count!=opt.v.size()) return false;
    for(size_t i=0;i<ps.size();++i)
        if(!read_vec(in,ps[i]->v,ps[i]->v.size()) || !read_vec(in,opt.m[i],ps[i]->v.size()) || !read_vec(in,opt.v[i],ps[i]->v.size())) return false;
    return bool(in.peek()==std::ifstream::traits_type::eof());
}

static Vec mm(const Vec& a,const Vec& b,int m,int k,int n) {
    Vec o(m*n);
    for(int i=0;i<m;i++) for(int p=0;p<k;p++) {
        double x=a[i*k+p]; for(int j=0;j<n;j++) o[i*n+j]+=x*b[p*n+j];
    }
    return o;
}

static Vec mm_backward(const Vec& x,const Vec& w,const Vec& dy,Vec& dw,int m,int k,int n) {
    Vec dx(m*k);
    for(int i=0;i<m;i++) for(int j=0;j<n;j++) {
        double d=dy[i*n+j];
        for(int p=0;p<k;p++) { dw[p*n+j]+=x[i*k+p]*d; dx[i*k+p]+=w[p*n+j]*d; }
    }
    return dx;
}

static Vec rms_forward(const Vec& x,const Vec& gamma,int rows,int d,Vec& inv) {
    Vec y(x.size()); inv.resize(rows);
    for(int r=0;r<rows;r++) {
        double ss=0; for(int j=0;j<d;j++) ss+=x[r*d+j]*x[r*d+j];
        inv[r]=1.0/std::sqrt(ss/d+1e-5);
        for(int j=0;j<d;j++) y[r*d+j]=x[r*d+j]*inv[r]*gamma[j];
    }
    return y;
}

static Vec rms_backward(const Vec& x,const Vec& gamma,const Vec& inv,const Vec& dy,Vec& dgamma,int rows,int d) {
    Vec dx(x.size());
    for(int r=0;r<rows;r++) {
        double dot=0; for(int j=0;j<d;j++) dot+=dy[r*d+j]*gamma[j]*x[r*d+j];
        for(int j=0;j<d;j++) {
            dgamma[j]+=dy[r*d+j]*x[r*d+j]*inv[r];
            dx[r*d+j]=dy[r*d+j]*gamma[j]*inv[r]-x[r*d+j]*std::pow(inv[r],3)*dot/d;
        }
    }
    return dx;
}

static void rope(Vec& x,int t,int d,int heads,bool inverse=false) {
    int hd=d/heads;
    for(int p=0;p<t;p++) for(int h=0;h<heads;h++) for(int j=0;j+1<hd;j+=2) {
        double angle=p/std::pow(10000.0,double(j)/hd), cs=std::cos(angle), sn=std::sin(angle);
        if(inverse) sn=-sn;
        int z=p*d+h*hd+j; double a=x[z],b=x[z+1]; x[z]=a*cs-b*sn; x[z+1]=a*sn+b*cs;
    }
}

struct Cache {
    std::vector<int> ids;
    Vec x,iq,ik,n1,q,k,v,att,ctx,proj,res,iff,n2,gate,up,swiglu,h,logits;
};

static Vec attention_forward(const Config& c,const Vec& q,const Vec& k,const Vec& v,Vec& att) {
    int t=c.seq,d=c.dim,hd=d/c.heads; double scale=1/std::sqrt(double(hd));
    Vec ctx(t*d); att.assign(c.heads*t*t,0.0);
    for(int h=0;h<c.heads;h++) for(int i=0;i<t;i++) {
        double mx=-1e100;
        for(int j=0;j<=i;j++) { double s=0; for(int z=0;z<hd;z++) s+=q[i*d+h*hd+z]*k[j*d+h*hd+z]; att[(h*t+i)*t+j]=s*scale; mx=std::max(mx,s*scale); }
        double sum=0; for(int j=0;j<=i;j++) sum+=std::exp(att[(h*t+i)*t+j]-mx);
        for(int j=0;j<=i;j++) att[(h*t+i)*t+j]=std::exp(att[(h*t+i)*t+j]-mx)/sum;
        for(int z=0;z<hd;z++) for(int j=0;j<=i;j++) ctx[i*d+h*hd+z]+=att[(h*t+i)*t+j]*v[j*d+h*hd+z];
    }
    return ctx;
}

static void attention_backward(const Config& c,const Vec& q,const Vec& k,const Vec& v,const Vec& att,const Vec& dctx,Vec& dq,Vec& dk,Vec& dv) {
    int t=c.seq,d=c.dim,hd=d/c.heads; double scale=1/std::sqrt(double(hd));
    dq.assign(t*d,0); dk.assign(t*d,0); dv.assign(t*d,0);
    for(int h=0;h<c.heads;h++) for(int i=0;i<t;i++) {
        Vec da(i+1),ds(i+1); double dot=0;
        for(int j=0;j<=i;j++) {
            for(int z=0;z<hd;z++) { da[j]+=dctx[i*d+h*hd+z]*v[j*d+h*hd+z]; dv[j*d+h*hd+z]+=att[(h*t+i)*t+j]*dctx[i*d+h*hd+z]; }
            dot+=da[j]*att[(h*t+i)*t+j];
        }
        for(int j=0;j<=i;j++) ds[j]=att[(h*t+i)*t+j]*(da[j]-dot);
        for(int j=0;j<=i;j++) for(int z=0;z<hd;z++) {
            dq[i*d+h*hd+z]+=ds[j]*k[j*d+h*hd+z]*scale;
            dk[j*d+h*hd+z]+=ds[j]*q[i*d+h*hd+z]*scale;
        }
    }
}

static double forward(Model& m,const std::vector<int>& ids,const std::vector<int>& targets,Cache& c) {
    int t=m.c.seq,d=m.c.dim,vocab=m.c.vocab,f=m.c.ffn; c.ids=ids; c.x.assign(t*d,0);
    for(int i=0;i<t;i++) for(int j=0;j<d;j++) c.x[i*d+j]=m.emb.v[ids[i]*d+j];
    c.n1=rms_forward(c.x,m.nq.v,t,d,c.iq);
    c.q=mm(c.n1,m.wq.v,t,d,d); c.k=mm(c.n1,m.wk.v,t,d,d); c.v=mm(c.n1,m.wv.v,t,d,d);
    rope(c.q,t,d,m.c.heads); rope(c.k,t,d,m.c.heads);
    c.ctx=attention_forward(m.c,c.q,c.k,c.v,c.att); c.proj=mm(c.ctx,m.wo.v,t,d,d); c.res=c.x;
    for(size_t i=0;i<c.res.size();i++) c.res[i]+=c.proj[i];
    c.n2=rms_forward(c.res,m.nf.v,t,d,c.iff); c.gate=mm(c.n2,m.wg.v,t,d,f); c.up=mm(c.n2,m.wu.v,t,d,f); c.swiglu.resize(t*f);
    for(int i=0;i<t*f;i++) { double s=1/(1+std::exp(-c.gate[i])); c.swiglu[i]=c.gate[i]*s*c.up[i]; }
    Vec down=mm(c.swiglu,m.wd.v,t,f,d); c.h=c.res; for(size_t i=0;i<c.h.size();i++) c.h[i]+=down[i];
    c.logits=mm(c.h,m.out.v,t,d,vocab); double loss=0;
    for(int i=0;i<t;i++) { double mx=*std::max_element(c.logits.begin()+i*vocab,c.logits.begin()+(i+1)*vocab),sum=0; for(int z=0;z<vocab;z++) sum+=std::exp(c.logits[i*vocab+z]-mx); loss+=std::log(sum)+mx-c.logits[i*vocab+targets[i]]; }
    return loss/t;
}

static void backward(Model& m,const std::vector<int>& targets,const Cache& c) {
    int t=m.c.seq,d=m.c.dim,vocab=m.c.vocab,f=m.c.ffn; m.zero_grad(); Vec dl(c.logits.size());
    for(int i=0;i<t;i++) { double mx=*std::max_element(c.logits.begin()+i*vocab,c.logits.begin()+(i+1)*vocab),sum=0; for(int z=0;z<vocab;z++) sum+=std::exp(c.logits[i*vocab+z]-mx); for(int z=0;z<vocab;z++) dl[i*vocab+z]=std::exp(c.logits[i*vocab+z]-mx)/sum/t; dl[i*vocab+targets[i]]-=1.0/t; }
    Vec dh=mm_backward(c.h,m.out.v,dl,m.out.g,t,d,vocab), dres=dh;
    Vec dsw=mm_backward(c.swiglu,m.wd.v,dh,m.wd.g,t,f,d),dg(t*f),du(t*f);
    for(int i=0;i<t*f;i++) { double s=1/(1+std::exp(-c.gate[i])); dg[i]=dsw[i]*c.up[i]*(s+c.gate[i]*s*(1-s)); du[i]=dsw[i]*c.gate[i]*s; }
    Vec dn2=mm_backward(c.n2,m.wg.v,dg,m.wg.g,t,d,f),tmp=mm_backward(c.n2,m.wu.v,du,m.wu.g,t,d,f); for(size_t i=0;i<dn2.size();i++) dn2[i]+=tmp[i];
    tmp=rms_backward(c.res,m.nf.v,c.iff,dn2,m.nf.g,t,d); for(size_t i=0;i<dres.size();i++) dres[i]+=tmp[i];
    Vec dctx=mm_backward(c.ctx,m.wo.v,dres,m.wo.g,t,d,d),dq,dk,dv; attention_backward(m.c,c.q,c.k,c.v,c.att,dctx,dq,dk,dv);
    rope(dq,t,d,m.c.heads,true); rope(dk,t,d,m.c.heads,true);
    Vec dn1=mm_backward(c.n1,m.wq.v,dq,m.wq.g,t,d,d); tmp=mm_backward(c.n1,m.wk.v,dk,m.wk.g,t,d,d); for(size_t i=0;i<dn1.size();i++) dn1[i]+=tmp[i]; tmp=mm_backward(c.n1,m.wv.v,dv,m.wv.g,t,d,d); for(size_t i=0;i<dn1.size();i++) dn1[i]+=tmp[i];
    Vec dx=rms_backward(c.x,m.nq.v,c.iq,dn1,m.nq.g,t,d); for(size_t i=0;i<dx.size();i++) dx[i]+=dres[i];
    for(int i=0;i<t;i++) for(int j=0;j<d;j++) m.emb.g[c.ids[i]*d+j]+=dx[i*d+j];
}

static bool gradient_check(Model& m,const std::vector<int>& x,const std::vector<int>& y) {
    Cache c; forward(m,x,y,c); backward(m,y,c); double eps=1e-5,max_rel=0; int checked=0;
    for(Param* p:m.params()) for(size_t i=0;i<p->v.size();i+=std::max<size_t>(1,p->v.size()/3)) {
        double old=p->v[i]; p->v[i]=old+eps; Cache a; double lp=forward(m,x,y,a); p->v[i]=old-eps; Cache b; double lm=forward(m,x,y,b); p->v[i]=old;
        double num=(lp-lm)/(2*eps),ana=p->g[i],rel=std::abs(num-ana)/std::max(1e-7,std::abs(num)+std::abs(ana)); max_rel=std::max(max_rel,rel); checked++;
        if(rel>2e-3) { std::printf("gradient-check FAIL param=%p index=%zu analytic=%.9g numeric=%.9g rel=%.3g\n",(void*)p,i,ana,num,rel); return false; }
    }
    std::printf("gradient-check PASS checked=%d max_relative_error=%.3g\n",checked,max_rel); return true;
}

static bool causal_check(Model& m) {
    std::vector<int>a={1,2,3,4},b={1,2,9,10},y={2,3,4,5}; Cache ca,cb; forward(m,a,y,ca); forward(m,b,y,cb);
    double err=0; for(int pos=0;pos<2;pos++) for(int v=0;v<m.c.vocab;v++) err=std::max(err,std::abs(ca.logits[pos*m.c.vocab+v]-cb.logits[pos*m.c.vocab+v]));
    std::printf("causal-mask %s max_prefix_difference=%.3g\n",err<1e-12?"PASS":"FAIL",err); return err<1e-12;
}

static bool overfit_check(Model& m) {
    std::vector<int>x={1,2,3,4},y={2,3,4,5}; Cache c; double first=forward(m,x,y,c),loss=first;
    for(int step=0;step<600;step++) { loss=forward(m,x,y,c); backward(m,y,c); for(Param* p:m.params()) for(size_t i=0;i<p->v.size();i++) p->v[i]-=0.03*p->g[i]; }
    loss=forward(m,x,y,c); int correct=0;
    for(int pos=0;pos<m.c.seq;pos++) {
        auto begin=c.logits.begin()+pos*m.c.vocab;
        int predicted=int(std::max_element(begin,begin+m.c.vocab)-begin);
        correct+=predicted==y[pos];
    }
    bool ok=loss<0.08 && loss<first*0.05 && correct==m.c.seq;
    std::printf("tiny-overfit %s initial_loss=%.6f final_loss=%.6f next_token_accuracy=%d/%d\n",ok?"PASS":"FAIL",first,loss,correct,m.c.seq); return ok;
}

static double max_parameter_difference(Model& a,Model& b) {
    double maximum=0.0; std::vector<Param*> ap=a.params(),bp=b.params();
    if(ap.size()!=bp.size()) return INFINITY;
    for(size_t p=0;p<ap.size();++p) {
        if(ap[p]->v.size()!=bp[p]->v.size()) return INFINITY;
        for(size_t i=0;i<ap[p]->v.size();++i) maximum=std::max(maximum,std::abs(ap[p]->v[i]-bp[p]->v[i]));
    }
    return maximum;
}

static void train_steps(Model& model,AdamW& optimizer,const std::vector<int>& x,const std::vector<int>& y,int count) {
    for(int step=0;step<count;++step) {
        Cache cache; forward(model,x,y,cache); backward(model,y,cache); optimizer.step(model);
    }
}

static bool checkpoint_resume_check() {
    Config cfg; std::vector<int>x={1,2,3,4},y={2,3,4,5};
    constexpr int total_steps=48, save_after=19;
    const std::string path="transformer_reference_resume.ckpt";

    Model uninterrupted(cfg); AdamW uninterrupted_opt(uninterrupted);
    train_steps(uninterrupted,uninterrupted_opt,x,y,total_steps);
    Cache uninterrupted_cache; double uninterrupted_loss=forward(uninterrupted,x,y,uninterrupted_cache);

    Model interrupted(cfg); AdamW interrupted_opt(interrupted);
    train_steps(interrupted,interrupted_opt,x,y,save_after);
    bool saved=save_checkpoint(path,interrupted,interrupted_opt,save_after);

    Model resumed(cfg); AdamW resumed_opt(resumed); int64_t restored_step=-1;
    bool loaded=saved && load_checkpoint(path,resumed,resumed_opt,restored_step);
    if(loaded) train_steps(resumed,resumed_opt,x,y,total_steps-int(restored_step));
    Cache resumed_cache; double resumed_loss=loaded?forward(resumed,x,y,resumed_cache):INFINITY;
    double max_diff=loaded?max_parameter_difference(uninterrupted,resumed):INFINITY;
    bool ok=loaded && restored_step==save_after && resumed_opt.step_count==total_steps &&
            max_diff<1e-14 && std::abs(uninterrupted_loss-resumed_loss)<1e-14;
    std::remove(path.c_str());
    std::printf("checkpoint-resume %s restored_step=%lld optimizer_step=%lld max_parameter_difference=%.3g loss_difference=%.3g\n",
        ok?"PASS":"FAIL",static_cast<long long>(restored_step),static_cast<long long>(resumed_opt.step_count),
        max_diff,std::abs(uninterrupted_loss-resumed_loss));
    return ok;
}

static bool checkpoint_rejects_corruption_check() {
    Config cfg; Model model(cfg); AdamW optimizer(model); int64_t step=0;
    const std::string path="transformer_reference_corrupt.ckpt";
    { std::ofstream out(path,std::ios::binary|std::ios::trunc); out << "not-a-neurx-checkpoint"; }
    bool rejected=!load_checkpoint(path,model,optimizer,step);
    std::remove(path.c_str());
    std::printf("checkpoint-corruption %s\n",rejected?"PASS":"FAIL");
    return rejected;
}

#ifndef NEURX_TRANSFORMER_REFERENCE_NO_MAIN
int main() {
    Config cfg; Model model(cfg); std::vector<int>x={1,2,3,4},y={2,3,4,5};
    bool ok=causal_check(model) && gradient_check(model,x,y) && overfit_check(model) &&
            checkpoint_resume_check() && checkpoint_rejects_corruption_check();
    std::printf("transformer-reference %s architecture=decoder-only layers=1 heads=%d dim=%d ffn=%d\n",ok?"PASS":"FAIL",cfg.heads,cfg.dim,cfg.ffn);
    return ok?0:1;
}
#endif
