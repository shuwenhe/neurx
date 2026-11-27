#include "../../src/runtime/model/hybrid_config.h"
#include "../../src/runtime/model/mapped_weight_store.h"
#include "../../src/runtime/model/architecture_registry.h"
#include <nlohmann/json.hpp>
#include <sys/resource.h>
#include <chrono>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <filesystem>
#include <fstream>
#include <cstring>
#include <set>
#include <sys/mman.h>
#include <unistd.h>
using namespace neurx::runtime::model;
using J = nlohmann::json;
static J bytes(const TensorSlice& slice) {
  std::vector<uint8_t> sample(std::min<uint64_t>(slice.size(), 32));
  slice.copy(0, sample.data(), sample.size());
  std::ostringstream hex;
  for (auto b : sample) hex << std::hex << std::setw(2) << std::setfill('0') << int(b);
  return J{{"shape",slice.shape()},{"size",slice.size()},{"hex",hex.str()}};
}
int main(int argc, char** argv) {
  try {
    if (argc < 3) throw std::runtime_error("usage: probe command directory [tensor/id]");
    const auto begin = std::chrono::steady_clock::now();
    std::string op=argv[1], dir=argv[2]; J out;
    if (op=="config") {
      auto c=HybridDecoderConfig::from_file(dir+"/config.json");
      auto state=c.state_bytes(argc>3 ? std::stoull(argv[3]) : 32);
      size_t full=0; for (auto kind:c.layer_types) full+=kind==MixerKind::full_attention;
      out={{"layers",c.layer_types.size()},{"full",full},{"linear",c.layer_types.size()-full},
           {"hidden",c.hidden_size},{"query_width",c.full.query_heads*c.full.head_dim},
           {"kv_bytes",state.kv},{"recurrent_bytes",state.recurrent},{"conv_bytes",state.conv}};
    } else if (op=="inspect") {
      auto adapter=ArchitectureRegistry::resolve(dir);
      auto store=MappedWeightStore::open(dir);
      auto manifest=adapter.validate(store);
      out={{"tensors",store.tensors().size()},{"text",manifest.text},
           {"vision",manifest.vision},{"mtp",manifest.mtp},{"payload_bytes",store.payload_bytes()},
           {"mapped_bytes",store.mapped_bytes()},{"metadata_identity",adapter.metadata_identity(store)},
           {"runtime_supported",adapter.runtime_supported()}};
    } else if (op=="verify-mapped") {
      auto store=MappedWeightStore::open(dir);
      ArchitectureRegistry::resolve(dir).validate(store);
      std::vector<uint8_t> buffer(1<<20);
      uint64_t total=0, tensors=0;
      std::set<std::string> shards;
      const auto page=uint64_t(::sysconf(_SC_PAGESIZE));
      if (!page) throw std::runtime_error("invalid page size");
      for (const auto& item:store.tensors()) {
        const auto slice=store.tensor(item.first);
        const auto* mapped=slice.data();
        // Inspect actual VM permissions, rather than trusting an API comment.
        std::ifstream maps("/proc/self/maps");std::string line;bool readonly=false;
        while(std::getline(maps,line)) {
          std::istringstream fields(line);std::string range,perms;
          if (!(fields>>range>>perms)) continue;
          auto dash=range.find('-');
          auto lo=std::stoull(range.substr(0,dash),nullptr,16);
          auto hi=std::stoull(range.substr(dash+1),nullptr,16);
          auto address=reinterpret_cast<uintptr_t>(mapped);
          if(address>=lo && address<hi) { readonly=perms.size()>=2 && perms[0]=='r' && perms[1]!='w';break; }
        }
        if(!readonly)throw std::runtime_error("tensor mapping is not read-only: "+item.first);
        for(uint64_t offset=0;offset<slice.size();) {
          auto count=std::min<uint64_t>(buffer.size(),slice.size()-offset);
          slice.copy(offset,buffer.data(),count);
          if(std::memcmp(mapped+offset,buffer.data(),count))
            throw std::runtime_error("mapped/pread mismatch: "+item.first);
          // Release touched pages from this process; do not accumulate 70GB RSS.
          auto address=reinterpret_cast<uintptr_t>(mapped+offset);
          auto aligned=address-address%page;
          if(::madvise(reinterpret_cast<void*>(aligned),address-aligned+count,MADV_DONTNEED))
            throw std::runtime_error("cannot release mapped verification pages");
          offset+=count;total+=count;
        }
        shards.insert(item.second.shard);++tensors;
      }
      out={{"verified_tensors",tensors},{"verified_bytes",total},
           {"verified_shards",shards.size()},{"read_only",true},
           {"buffer_bytes",buffer.size()}};
    } else if (op=="lifetime") {
      if (argc!=4) throw std::runtime_error("lifetime tensor required");
      TensorSlice slice;
      { auto store=MappedWeightStore::open(dir); slice=store.tensor(argv[3]); }
      out=bytes(slice);
      bool rejected=false;
      try { uint8_t v; slice.copy(slice.size(),&v,1); } catch(const std::exception&) { rejected=true; }
      out["bounds_rejected"]=rejected;
    } else if (op=="fd-stress") {
      auto count=[] { size_t n=0; for (const auto& e:std::filesystem::directory_iterator("/proc/self/fd")) { (void)e;++n; } return n; };
      auto before=count();
      for (int i=0;i<128;++i) { try { auto store=MappedWeightStore::open(dir); } catch(const std::exception&) {} }
      out={{"fd_before",before},{"fd_after",count()}};
    } else {
      StoreLimits limits;
      if (op=="store-limit" && argc==5) { limits.max_header_bytes=std::stoull(argv[3]);limits.max_metadata_bytes=std::stoull(argv[4]); }
      auto store=MappedWeightStore::open(dir,limits);
      if (op=="store") out={{"tensors",store.tensors().size()},{"payload_bytes",store.payload_bytes()}};
      else if (op=="store-limit") out={{"tensors",store.tensors().size()}};
      else if (op=="expert" && argc==5) out=bytes(store.expert(argv[3],std::stoull(argv[4])));
      else if (op=="rows" && argc==6) out=bytes(store.rows(argv[3],std::stoull(argv[4]),std::stoull(argv[5])));
      else throw std::runtime_error("unknown operation");
    }
    rusage usage{}; getrusage(RUSAGE_SELF,&usage);
    out["max_rss_kib"]=usage.ru_maxrss;
    out["elapsed_ms"]=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();
    std::cout<<out.dump()<<'\n'; return 0;
  } catch(const std::exception& e) { std::cerr<<"REJECTED: "<<e.what()<<'\n'; return 1; }
}
