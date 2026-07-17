#include "operator_abi.h"
#include "transformer_engine.h"

#if !__has_include(<acl/acl.h>) || !__has_include(<atb/atb_infer.h>)
#error "Ascend310P plugin requires CANN ACL and ATB headers"
#endif

#include <acl/acl.h>
#include <atb/atb_infer.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <utility>
#include <vector>

namespace neurx::cann {
namespace {

atb::Tensor device_tensor(void* data, aclDataType dtype, aclFormat format,
                          std::initializer_list<int64_t> dimensions) {
  atb::Tensor result;
  result.desc.dtype = dtype;
  result.desc.format = format;
  result.desc.shape.dimNum = dimensions.size();
  std::size_t elements = 1;
  std::size_t index = 0;
  for (const int64_t dimension : dimensions) {
    result.desc.shape.dims[index++] = dimension;
    elements *= static_cast<std::size_t>(dimension);
  }
  result.deviceData = data;
  const std::size_t element_bytes =
      dtype == ACL_INT64 ? sizeof(int64_t)
                         : (dtype == ACL_INT32 ? sizeof(int32_t)
                                              : sizeof(uint16_t));
  result.dataSize = elements * element_bytes;
  return result;
}

atb::Tensor host_i32(std::vector<int32_t>& values) {
  atb::Tensor result =
      device_tensor(nullptr, ACL_INT32, ACL_FORMAT_ND,
                    {static_cast<int64_t>(values.size())});
  result.hostData = values.data();
  return result;
}

Status atb_error(const char* operation, atb::Status code) {
  return Status::failure(std::string(operation) + " ATB status=" +
                         std::to_string(code));
}

class Atb310PBackend final : public TransformerPrimitiveBackend {
 public:
  ~Atb310PBackend() override {
    for (atb::Operation* operation : operations_) {
      if (operation) atb::DestroyOperation(operation);
    }
    if (context_) atb::DestroyContext(context_);
  }

  Status initialize(const ModelMetadata& model, const KvCacheConfig& cache) {
    if (ready_) return Status::success();
    atb::Status code = atb::CreateContext(&context_);
    if (code != atb::NO_ERROR) return atb_error("CreateContext", code);

    atb::infer::GatherParam gather;
    gather.axis = 0;
    if (!(create(gather, &gather_, "Gather").ok)) return last_error_;

    atb::infer::RmsNormParam norm;
    norm.layerType = atb::infer::RmsNormParam::RMS_NORM_NORM;
    norm.normParam.epsilon = 1.0e-5F;
    if (!(create(norm, &norm_, "RmsNorm").ok)) return last_error_;

    atb::infer::LinearParam linear;
    linear.transposeA = false;
    linear.transposeB = false;
    linear.hasBias = false;
    if (!(create(linear, &linear_, "Linear").ok)) return last_error_;

    atb::infer::RopeParam rope;
    rope.rotaryCoeff = 2;
    if (!(create(rope, &rope_, "RoPE").ok)) return last_error_;

    atb::infer::ReshapeAndCacheParam reshape_cache;
    if (!(create(reshape_cache, &reshape_cache_, "ReshapeAndCache").ok)) {
      return last_error_;
    }

    atb::infer::PagedAttentionParam attention;
    attention.headNum = static_cast<int32_t>(model.attention_heads);
    attention.kvHeadNum = static_cast<int32_t>(model.attention_heads);
    attention.qkScale =
        1.0F / std::sqrt(static_cast<float>(cache.head_size));
    if (!(create(attention, &paged_attention_, "PagedAttention").ok)) {
      return last_error_;
    }

    atb::infer::ElewiseParam add;
    add.elewiseType = atb::infer::ElewiseParam::ELEWISE_ADD;
    if (!(create(add, &add_, "Add").ok)) return last_error_;

    atb::infer::ActivationParam swish;
    swish.activationType = atb::infer::ACTIVATION_SWISH;
    swish.scale = 1.0F;
    if (!(create(swish, &swish_, "Swish").ok)) return last_error_;

    atb::infer::ElewiseParam multiply;
    multiply.elewiseType = atb::infer::ElewiseParam::ELEWISE_MUL;
    if (!(create(multiply, &multiply_, "Multiply").ok)) return last_error_;

    model_ = model;
    cache_ = cache;
    ready_ = true;
    return Status::success();
  }

  Status embedding(const void* ids, const DeviceWeight& table,
                   const TensorView& output, Stream stream) override {
    set_stream(stream);
    atb::VariantPack pack;
    pack.inTensors = {
        device_tensor(table.storage.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {model_.vocabulary, model_.hidden_size}),
        device_tensor(const_cast<void*>(ids), ACL_INT32, ACL_FORMAT_ND,
                      {static_cast<int64_t>(output.rows)})};
    pack.outTensors = {fp16(output)};
    return run(gather_, pack, "Gather");
  }

  Status rms_norm(const TensorView& input, const DeviceWeight& scale,
                  const TensorView& output, Stream stream) override {
    set_stream(stream);
    atb::VariantPack pack;
    pack.inTensors = {
        fp16(input),
        device_tensor(scale.storage.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(input.columns)})};
    pack.outTensors = {fp16(output)};
    return run(norm_, pack, "RmsNorm");
  }

  Status linear(const TensorView& input, const DeviceWeight& weight,
                const TensorView& output, Stream stream) override {
    set_stream(stream);
    atb::VariantPack pack;
    pack.inTensors = {
        fp16(input),
        device_tensor(weight.storage.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(input.columns),
                       static_cast<int64_t>(output.columns)})};
    pack.outTensors = {fp16(output)};
    return run(linear_, pack, "Linear");
  }

  Status rope(const TensorView& query, const TensorView& key,
              const TransformerBatchPlan& plan, Stream stream) override {
    set_stream(stream);
    Status status = prepare_rope(plan);
    if (!status.ok) return status;
    atb::VariantPack pack;
    pack.inTensors = {
        fp16(query), fp16(key),
        device_tensor(cos_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(plan.token_count),
                       static_cast<int64_t>(plan.head_size / 2)}),
        device_tensor(sin_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(plan.token_count),
                       static_cast<int64_t>(plan.head_size / 2)}),
        host_i32(q_sequence_lengths_)};
    // The 310P ATB RoPE path permits q/k output aliasing.
    pack.outTensors = {fp16(query), fp16(key)};
    return run(rope_, pack, "RoPE");
  }

  Status store_kv(const TensorView& key, const TensorView& value,
                  std::size_t layer, const TransformerBatchPlan& plan,
                  PagedKvCache& cache, Stream stream) override {
    set_stream(stream);
    slot_host_.clear();
    for (const auto& request : plan.requests) {
      slot_host_.insert(slot_host_.end(), request.write_slots.begin(),
                        request.write_slots.end());
    }
    Status status = upload_i32(slot_, slot_host_);
    if (!status.ok) return status;
    atb::Tensor key_cache = cache_tensor(cache.key_layer_address(layer));
    atb::Tensor value_cache = cache_tensor(cache.value_layer_address(layer));
    atb::VariantPack pack;
    pack.inTensors = {
        fp16_3d(key, plan), fp16_3d(value, plan), key_cache, value_cache,
        device_tensor(slot_.data(), ACL_INT32, ACL_FORMAT_ND,
                      {static_cast<int64_t>(slot_host_.size())})};
    pack.outTensors = {key_cache, value_cache};
    return run(reshape_cache_, pack, "ReshapeAndCache");
  }

  Status attention(const TensorView& query, const TensorView&,
                   const TensorView&, std::size_t layer,
                   const TransformerBatchPlan& plan, PagedKvCache& cache,
                   const TensorView& output, Stream stream) override {
    set_stream(stream);
    PagedAttentionMetadata metadata;
    Status status = build_paged_attention_metadata(plan, &metadata);
    if (!status.ok) return status;
    block_host_ = std::move(metadata.block_tables);
    sequence_lengths_ = std::move(metadata.context_lengths);
    const std::size_t query_rows = metadata.rows;
    status = upload_i32(blocks_, block_host_);
    if (!status.ok) return status;
    atb::VariantPack pack;
    pack.inTensors = {
        fp16_3d(query, plan), cache_tensor(cache.key_layer_address(layer)),
        cache_tensor(cache.value_layer_address(layer)),
        device_tensor(blocks_.data(), ACL_INT32, ACL_FORMAT_ND,
                      {static_cast<int64_t>(query_rows),
                       static_cast<int64_t>(plan.max_blocks_per_request)}),
        host_i32(sequence_lengths_)};
    pack.outTensors = {fp16_3d(output, plan)};
    return run(paged_attention_, pack, "PagedAttention");
  }

  Status add(const TensorView& left, const TensorView& right,
             const TensorView& output, Stream stream) override {
    set_stream(stream);
    atb::VariantPack pack;
    pack.inTensors = {fp16(left), fp16(right)};
    pack.outTensors = {fp16(output)};
    return run(add_, pack, "Add");
  }

  Status swiglu(const TensorView& gate, const TensorView& up,
                const TensorView& output, Stream stream) override {
    set_stream(stream);
    atb::VariantPack activation;
    activation.inTensors = {fp16(gate)};
    activation.outTensors = {fp16(output)};
    Status status = run(swish_, activation, "Swish");
    if (!status.ok) return status;
    atb::VariantPack multiply;
    multiply.inTensors = {fp16(output), fp16(up)};
    multiply.outTensors = {fp16(output)};
    return run(multiply_, multiply, "SwiGLU");
  }

  Status gather_last(const TensorView& hidden,
                     const TransformerBatchPlan& plan,
                     const TensorView& output, Stream stream) override {
    const std::size_t row_bytes = hidden.columns * sizeof(uint16_t);
    std::size_t row = 0;
    for (std::size_t request = 0; request < plan.requests.size(); ++request) {
      row += plan.phase == inference::Phase::decode
                 ? 1
                 : plan.requests[request].write_slots.size();
      auto* source = static_cast<unsigned char*>(hidden.data) +
                     (row - 1) * row_bytes;
      auto* destination = static_cast<unsigned char*>(output.data) +
                          request * row_bytes;
      if (memcpy_async(destination, row_bytes, source, row_bytes,
                       MemcpyKind::device_to_device, stream) != kSuccess) {
        return Status::failure(std::string("gather last token: ") +
                               recent_error());
      }
    }
    return Status::success();
  }

 private:
  template <typename Param>
  Status create(const Param& param, atb::Operation** output,
                const char* name) {
    const atb::Status code = atb::CreateOperation(param, output);
    if (code != atb::NO_ERROR) {
      last_error_ = atb_error(name, code);
      return last_error_;
    }
    operations_.push_back(*output);
    return Status::success();
  }

  void set_stream(Stream stream) {
    stream_ = stream;
    context_->SetExecuteStream(stream);
  }

  atb::Tensor fp16(const TensorView& view) const {
    return device_tensor(view.data, ACL_FLOAT16, ACL_FORMAT_ND,
                         {static_cast<int64_t>(view.rows),
                          static_cast<int64_t>(view.columns)});
  }

  atb::Tensor fp16_3d(const TensorView& view,
                      const TransformerBatchPlan& plan) const {
    return device_tensor(view.data, ACL_FLOAT16, ACL_FORMAT_ND,
                         {static_cast<int64_t>(view.rows),
                          static_cast<int64_t>(plan.head_count),
                          static_cast<int64_t>(plan.head_size)});
  }

  atb::Tensor cache_tensor(void* address) const {
    return device_tensor(
        address, ACL_FLOAT16, ACL_FORMAT_FRACTAL_NZ,
        {static_cast<int64_t>(cache_.block_count),
         static_cast<int64_t>(cache_.head_size * cache_.kv_heads / 16),
         static_cast<int64_t>(cache_.tokens_per_block), 16});
  }

  Status ensure(DeviceBuffer& buffer, std::size_t bytes) {
    if (buffer.size() >= bytes) return Status::success();
    if (buffer.data() && synchronize_stream(stream_) != kSuccess) {
      return Status::failure("ATB buffer growth synchronization failed");
    }
    return buffer.allocate(bytes);
  }

  Status upload_i32(DeviceBuffer& buffer,
                    const std::vector<int32_t>& values) {
    const std::size_t bytes = values.size() * sizeof(int32_t);
    Status status = ensure(buffer, bytes);
    if (!status.ok) return status;
    return memcpy_async(buffer.data(), buffer.size(), values.data(), bytes,
                        MemcpyKind::host_to_device, stream_) == kSuccess
               ? Status::success()
               : Status::failure(std::string("ATB metadata upload: ") +
                                 recent_error());
  }

  Status prepare_rope(const TransformerBatchPlan& plan) {
    std::vector<uint16_t> cos_host;
    std::vector<uint16_t> sin_host;
    q_sequence_lengths_.clear();
    cos_host.reserve(plan.token_count * plan.head_size / 2);
    sin_host.reserve(plan.token_count * plan.head_size / 2);
    for (const auto& request : plan.requests) {
      const std::size_t count = request.write_slots.size();
      q_sequence_lengths_.push_back(static_cast<int32_t>(count));
      for (std::size_t token = request.sequence_tokens - count;
           token < request.sequence_tokens; ++token) {
        for (std::size_t pair = 0; pair < plan.head_size / 2; ++pair) {
          const float frequency =
              std::pow(10000.0F, -2.0F * static_cast<float>(pair) /
                                      static_cast<float>(plan.head_size));
          const float angle = static_cast<float>(token) * frequency;
          cos_host.push_back(float_to_fp16_bits(std::cos(angle)));
          sin_host.push_back(float_to_fp16_bits(std::sin(angle)));
        }
      }
    }
    const std::size_t bytes = cos_host.size() * sizeof(uint16_t);
    Status status = ensure(cos_, bytes);
    if (!status.ok) return status;
    status = ensure(sin_, bytes);
    if (!status.ok) return status;
    if (memcpy_async(cos_.data(), cos_.size(), cos_host.data(), bytes,
                     MemcpyKind::host_to_device, stream_) != kSuccess ||
        memcpy_async(sin_.data(), sin_.size(), sin_host.data(), bytes,
                     MemcpyKind::host_to_device, stream_) != kSuccess) {
      return Status::failure(std::string("RoPE table upload: ") +
                             recent_error());
    }
    return Status::success();
  }

  Status run(atb::Operation* operation, atb::VariantPack& pack,
             const char* name) {
    uint64_t workspace_bytes = 0;
    atb::Status code = operation->Setup(pack, workspace_bytes, context_);
    if (code != atb::NO_ERROR) return atb_error(name, code);
    if (workspace_bytes > workspace_.size()) {
      Status status = ensure(workspace_, workspace_bytes);
      if (!status.ok) return status;
    }
    code = operation->Execute(
        pack, static_cast<uint8_t*>(workspace_.data()), workspace_bytes,
        context_);
    return code == atb::NO_ERROR ? Status::success()
                                 : atb_error(name, code);
  }

  bool ready_ = false;
  Status last_error_;
  ModelMetadata model_;
  KvCacheConfig cache_;
  Stream stream_ = nullptr;
  atb::Context* context_ = nullptr;
  std::vector<atb::Operation*> operations_;
  atb::Operation *gather_ = nullptr, *norm_ = nullptr, *linear_ = nullptr;
  atb::Operation *rope_ = nullptr, *reshape_cache_ = nullptr;
  atb::Operation* paged_attention_ = nullptr;
  atb::Operation *add_ = nullptr, *swish_ = nullptr, *multiply_ = nullptr;
  DeviceBuffer workspace_, slot_, blocks_, cos_, sin_;
  std::vector<int32_t> slot_host_, block_host_, sequence_lengths_;
  std::vector<int32_t> q_sequence_lengths_;
};

class Plugin {
 public:
  inference::AdapterStatus execute(const inference::DeviceBatch& batch) {
    std::lock_guard<std::mutex> lock(mutex_);
    const auto* model = static_cast<const Nxtrfmv2Model*>(batch.model);
    auto* cache = static_cast<PagedKvCache*>(batch.kv_cache);
    if (!model || !cache) {
      return inference::AdapterStatus::failure(
          "operator plugin requires model and KV cache handles");
    }
    Status status = backend_.initialize(model->metadata(), cache->config());
    if (!status.ok) return inference::AdapterStatus::failure(status.message);
    TransformerBatchPlan plan;
    status = build_transformer_batch_plan(batch, *model, *cache, &plan);
    if (!status.ok) return inference::AdapterStatus::failure(status.message);
    if (activation_.size() < plan.scratch_bytes) {
      if (activation_.data() &&
          synchronize_stream(batch.stream) != kSuccess) {
        return inference::AdapterStatus::failure(
            "activation workspace growth synchronization failed");
      }
      status = activation_.allocate(plan.scratch_bytes);
      if (!status.ok) return inference::AdapterStatus::failure(status.message);
    }
    inference::DeviceBatch launch = batch;
    launch.workspace = activation_.data();
    launch.workspace_bytes = activation_.size();
    status = execute_transformer(launch, *model, *cache, backend_);
    return status.ok ? inference::AdapterStatus::success()
                     : inference::AdapterStatus::failure(status.message);
  }

 private:
  std::mutex mutex_;
  Atb310PBackend backend_;
  DeviceBuffer activation_;
};

Plugin& plugin() {
  static Plugin instance;
  return instance;
}

}  // namespace
}  // namespace neurx::cann

extern "C" uint32_t neurx_cann_operator_abi_version() { return 1; }

namespace {
NeurxCannOperatorStatus abi_status(
    const neurx::inference::AdapterStatus& status) {
  static thread_local std::string message;
  message = status.message;
  return {status.ok ? 0 : 1, status.ok ? nullptr : message.c_str()};
}
}

extern "C" NeurxCannOperatorStatus neurx_cann_prefill(
    const neurx::inference::DeviceBatch& batch) {
  if (batch.schedule.phase != neurx::inference::Phase::prefill) {
    return {1, "prefill launcher received a decode batch"};
  }
  return abi_status(neurx::cann::plugin().execute(batch));
}

extern "C" NeurxCannOperatorStatus neurx_cann_decode(
    const neurx::inference::DeviceBatch& batch) {
  if (batch.schedule.phase != neurx::inference::Phase::decode) {
    return {1, "decode launcher received a prefill batch"};
  }
  return abi_status(neurx::cann::plugin().execute(batch));
}
