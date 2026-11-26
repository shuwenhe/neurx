#include "mapped_weight_store.h"
#include "strict_model_json.h"
#include <openssl/evp.h>
#include <algorithm>
#include <array>
#include <iomanip>
#include <sstream>
#include <cmath>
#include <sys/mman.h>

namespace neurx::runtime::model {
struct MappedRegion {
  int fd=-1;
  void* base=MAP_FAILED;
  uint64_t size=0;
  ~MappedRegion() {
    if (base!=MAP_FAILED) ::munmap(base,size_t(size));
    if (fd>=0) ::close(fd);
  }
};
namespace {
using detail::checked_add;using detail::checked_mul;using detail::model_json;
void require(bool condition, const std::string& reason) {
  if (!condition) throw std::runtime_error(reason);
}
bool basename(const std::string& value) {
  return !value.empty() && value!="." && value!=".." &&
    value.find('/')==std::string::npos && value.find('\\')==std::string::npos && value.find('\0')==std::string::npos;
}
uint64_t dtype_bytes(const std::string& type) {
  if (type=="BOOL" || type=="U8" || type=="I8") return 1;
  if (type=="BF16" || type=="F16" || type=="I16" || type=="U16") return 2;
  if (type=="F32" || type=="I32" || type=="U32") return 4;
  if (type=="F64" || type=="I64" || type=="U64") return 8;
  throw std::runtime_error("unsupported safetensors dtype: "+type);
}
struct digest {
  EVP_MD_CTX* ctx=EVP_MD_CTX_new();
  digest() { if (!ctx || EVP_DigestInit_ex(ctx,EVP_sha256(),nullptr)!=1) { if(ctx)EVP_MD_CTX_free(ctx);ctx=nullptr;throw std::runtime_error("cannot initialize metadata SHA256"); } }
  ~digest() { EVP_MD_CTX_free(ctx); }
  void add(const std::string& v) {
    // Length framing avoids ambiguous concatenation of file names/JSON/size.
    uint64_t n=v.size();std::array<uint8_t,8> length{};
    for (size_t i=0;i<8;++i) length[i]=uint8_t(n>>(i*8));
    if (EVP_DigestUpdate(ctx,length.data(),length.size())!=1 || EVP_DigestUpdate(ctx,v.data(),v.size())!=1)
      throw std::runtime_error("metadata SHA256 update failed");
  }
  std::string finish() {
    std::array<uint8_t,EVP_MAX_MD_SIZE> raw{};unsigned n=0;
    if (EVP_DigestFinal_ex(ctx,raw.data(),&n)!=1) throw std::runtime_error("metadata SHA256 failed");
    std::ostringstream out;
    for (unsigned i=0;i<n;++i) out<<std::hex<<std::setfill('0')<<std::setw(2)<<int(raw[i]);
    return out.str();
  }
};
model_json read_index(int dirfd, uint64_t budget, uint64_t& bytes) {
  detail::fd_owner f(::openat(dirfd,"model.safetensors.index.json",O_RDONLY|O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK));
  struct stat st{};
  require(f.value>=0 && !::fstat(f.value,&st) && S_ISREG(st.st_mode) && st.st_size>0 &&
          uint64_t(st.st_size)<=std::min<uint64_t>(16ULL<<20,budget),"invalid/big/missing checkpoint index");
  bytes=uint64_t(st.st_size);
  std::string text(size_t(st.st_size),'\0');detail::pread_exact(f.value,0,text.data(),text.size());
  return detail::strict_parse(text);
}
}
const uint8_t* TensorSlice::data() const {
  require(bool(owner_),"uninitialized tensor slice");
  struct stat st{};
  require(!::fstat(owner_->fd,&st) && st.st_size>=0 && uint64_t(st.st_size)==owner_->size,"checkpoint changed while mapped");
  return static_cast<const uint8_t*>(owner_->base)+offset_;
}
void TensorSlice::copy(uint64_t start, void* target, uint64_t count) const {
  require(start<=size_ && count<=size_-start,"tensor copy outside slice");
  if (!count) return;
  require(bool(owner_) && target && count<=SIZE_MAX,"invalid tensor copy destination");
  detail::pread_exact(owner_->fd,checked_add(offset_,start),target,size_t(count));
}
MappedWeightStore MappedWeightStore::open(const std::string& directory, StoreLimits limits) {
  detail::fd_owner dir(::open(directory.c_str(),O_RDONLY|O_DIRECTORY|O_CLOEXEC));
  require(dir.value>=0,"cannot open checkpoint directory: "+directory);
  require(limits.max_header_bytes && limits.max_metadata_bytes && limits.max_shards && limits.max_tensors,"zero metadata resource limit");
  struct stat st_index{},st_single{};
  bool indexed=::fstatat(dir.value,"model.safetensors.index.json",&st_index,AT_SYMLINK_NOFOLLOW)==0;
  bool single=::fstatat(dir.value,"model.safetensors",&st_single,AT_SYMLINK_NOFOLLOW)==0;
  require(!(indexed && single),"ambiguous single and sharded checkpoint");
  std::map<std::string,std::string> expected;
  std::set<std::string> shards;
  uint64_t index_bytes=0, expected_payload=0;
  bool has_expected_payload=false;
  digest identity;identity.add("NeurX-metadata-only-v1");
  if (indexed) {
    auto index=read_index(dir.value,limits.max_metadata_bytes,index_bytes);const auto& wm=index.at("weight_map");
    require(wm.is_object() && !wm.empty() && wm.size()<=limits.max_tensors,"invalid/empty checkpoint weight_map");
    for (const auto& item:wm.items()) {
      auto file=item.value().get<std::string>();
      require(basename(file),"unsafe checkpoint shard path");
      expected.emplace(item.key(),file);shards.insert(file);
    }
    identity.add(index.dump());
    if (index.contains("metadata") && index.at("metadata").contains("total_size")) {
      const auto& total=index.at("metadata").at("total_size");
      if (total.is_number_integer()) expected_payload=detail::natural(total);
      else {
        require(total.is_number_float(),"invalid index total_size");
        double v=total.get<double>();
        require(std::isfinite(v) && v>=0 && std::floor(v)==v && v<=9007199254740991.0,"inexact/invalid floating total_size");
        expected_payload=uint64_t(v);
      }
      has_expected_payload=true;
    }
  } else { require(single,"missing checkpoint index/weights");shards.insert("model.safetensors"); }
  require(shards.size()<=limits.max_shards,"too many checkpoint shards");
  MappedWeightStore result;uint64_t metadata_bytes=index_bytes;
  for (const auto& shard:shards) {
    detail::fd_owner file(::openat(dir.value,shard.c_str(),O_RDONLY|O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK));
    struct stat st{};
    require(file.value>=0 && !::fstat(file.value,&st) && S_ISREG(st.st_mode) && st.st_size>=8,"cannot map regular shard: "+shard);
    uint64_t size=uint64_t(st.st_size);require(size<=SIZE_MAX,"shard larger than address space");
    std::array<uint8_t,8> prefix{};detail::pread_exact(file.value,0,prefix.data(),8);
    uint64_t hs=0;for (size_t i=0;i<8;++i) hs|=uint64_t(prefix[i])<<(i*8);
    require(hs && hs<=size-8 && hs<=limits.max_header_bytes,"invalid/truncated/oversize checkpoint header");
    metadata_bytes=checked_add(metadata_bytes,hs);require(metadata_bytes<=limits.max_metadata_bytes,"checkpoint metadata budget exceeded");
    std::string raw(size_t(hs),'\0');detail::pread_exact(file.value,8,raw.data(),raw.size());
    auto header=detail::strict_parse(raw);require(header.is_object(),"checkpoint header is not an object");
    std::vector<std::pair<uint64_t,uint64_t>> spans;uint64_t tensor_count=0;
    for (const auto& entry:header.items()) {
      if (entry.key()=="__metadata__") {
        require(entry.value().is_object(),"invalid safetensors metadata");
        for (const auto& v:entry.value()) require(v.is_string(),"metadata must contain strings");
        continue;
      }
      TensorDescriptor desc;desc.name=entry.key();desc.shard=shard;
      require(!desc.name.empty(),"empty tensor name");
      const auto& value=entry.value();desc.dtype=value.at("dtype").get<std::string>();
      uint64_t count=1;const auto& shape=value.at("shape");
      require(shape.is_array() && shape.size()<=32,"invalid tensor rank");
      for (const auto& dim:shape) { auto d=detail::natural(dim);desc.shape.push_back(d);count=checked_mul(count,d); }
      auto bytes=checked_mul(count,dtype_bytes(desc.dtype));const auto& offsets=value.at("data_offsets");
      require(offsets.is_array() && offsets.size()==2,"invalid tensor offsets");
      uint64_t a=detail::natural(offsets[0]),b=detail::natural(offsets[1]);
      require(b>=a && b<=size-8-hs && b-a==bytes,"tensor range/shape/dtype byte mismatch: "+desc.name);
      desc.offset=checked_add(8+hs,a);desc.size=bytes;
      if (indexed) {
        auto it=expected.find(desc.name);
        require(it!=expected.end() && it->second==shard,"tensor/index shard mismatch: "+desc.name);
      }
      require(result.tensors_.emplace(desc.name,std::move(desc)).second,"duplicate tensor across shards");
      require(result.tensors_.size()<=limits.max_tensors,"tensor metadata count limit exceeded");
      spans.emplace_back(a,b);++tensor_count;
    }
    require(tensor_count>0,"empty checkpoint shard");
    std::sort(spans.begin(),spans.end());uint64_t end=0;
    for (auto span:spans) { require(span.first==end,"overlapping/gapped tensor ranges");end=span.second; }
    require(end==size-8-hs,"unaccounted/truncated shard payload");
    auto region=std::make_shared<MappedRegion>();region->fd=file.release();region->size=size;
    region->base=::mmap(nullptr,size_t(size),PROT_READ,MAP_PRIVATE,region->fd,0);
    require(region->base!=MAP_FAILED,"cannot mmap checkpoint shard");
    (void)::madvise(region->base,size_t(size),MADV_RANDOM);
    result.maps_.emplace(shard,std::move(region));
    result.mapped_bytes_=checked_add(result.mapped_bytes_,size);
    result.payload_bytes_=checked_add(result.payload_bytes_,end);
    identity.add(shard);identity.add(std::to_string(size));identity.add(header.dump());
  }
  require(!indexed || result.tensors_.size()==expected.size(),"index references missing tensors");
  require(!has_expected_payload || expected_payload==result.payload_bytes_,"index total_size does not match tensor payload");
  result.metadata_identity_=identity.finish();return result;
}
const TensorDescriptor& MappedWeightStore::view(const std::string& name) const {
  auto it=tensors_.find(name);if(it==tensors_.end()) throw std::runtime_error("missing mapped tensor: "+name);
  return it->second;
}
TensorSlice MappedWeightStore::tensor(const std::string& name) const {
  const auto& d=view(name);TensorSlice slice;
  slice.owner_=maps_.at(d.shard);slice.offset_=d.offset;slice.size_=d.size;slice.shape_=d.shape;slice.dtype_=d.dtype;return slice;
}
TensorSlice MappedWeightStore::expert(const std::string& name, uint64_t id) const {
  auto slice=tensor(name);require(slice.shape_.size()==3 && id<slice.shape_[0],"expert slice outside rank-3 tensor");
  auto size=checked_mul(checked_mul(slice.shape_[1],slice.shape_[2]),dtype_bytes(slice.dtype_));
  slice.offset_=checked_add(slice.offset_,checked_mul(id,size));slice.size_=size;
  slice.shape_.erase(slice.shape_.begin());return slice;
}
TensorSlice MappedWeightStore::rows(const std::string& name, uint64_t first, uint64_t count) const {
  auto slice=tensor(name);require(slice.shape_.size()==2,"row slice requires rank-2 tensor");
  require(first<=slice.shape_[0] && count<=slice.shape_[0]-first,"row slice outside tensor");
  auto stride=checked_mul(slice.shape_[1],dtype_bytes(slice.dtype_));
  slice.offset_=checked_add(slice.offset_,checked_mul(first,stride));slice.size_=checked_mul(count,stride);slice.shape_[0]=count;return slice;
}
}
