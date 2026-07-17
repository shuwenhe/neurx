#include "operator_abi.h"
#include "transformer_engine.h"
#include "../inference/logits_sampler.h"

#if !__has_include(<acl/acl.h>) || !__has_include(<atb/atb_infer.h>) || \
    !__has_include(<aclnnop/aclnn_weight_quant_batch_matmul_v2.h>)
#error "Ascend310P plugin requires CANN ACL and ATB headers"
#endif

#include <acl/acl.h>
#include <aclnnop/aclnn_trans_matmul_weight.h>
#include <aclnnop/aclnn_weight_quant_batch_matmul_v2.h>
#include <atb/atb_infer.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <list>
#include <memory>
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

class AclTensorHandle {
 public:
  AclTensorHandle(void* data, aclDataType type,
                  std::initializer_list<int64_t> dimensions) {
    dimensions_.assign(dimensions);
    strides_.resize(dimensions_.size());
    int64_t stride = 1;
    for (std::size_t index = dimensions_.size(); index-- > 0;) {
      strides_[index] = stride;
      stride *= dimensions_[index];
    }
    tensor_ = aclCreateTensor(
        dimensions_.data(), dimensions_.size(), type, strides_.data(), 0,
        ACL_FORMAT_ND, dimensions_.data(), dimensions_.size(), data);
  }

  ~AclTensorHandle() {
    if (tensor_) aclDestroyTensor(tensor_);
  }

  AclTensorHandle(const AclTensorHandle&) = delete;
  AclTensorHandle& operator=(const AclTensorHandle&) = delete;
  aclTensor* get() const { return tensor_; }

 private:
  std::vector<int64_t> dimensions_;
  std::vector<int64_t> strides_;
  aclTensor* tensor_ = nullptr;
};

class Atb310PBackend final : public TransformerPrimitiveBackend {
 public:
  ~Atb310PBackend() override {
    clear_graph_cache();
    quant_weights_.clear();
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

    atb::infer::SoftmaxParam softmax;
    softmax.axes = {-1};
    if (!(create(softmax, &softmax_, "Softmax").ok)) return last_error_;

    atb::infer::TopkToppSamplingParam sampling;
    sampling.topkToppSamplingType =
        atb::infer::TopkToppSamplingParam::BATCH_TOPK_MULTINOMIAL_SAMPLING;
    if (!(create(sampling, &sampling_, "TopkToppSampling").ok)) {
      return last_error_;
    }

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
    if (weight.quantized()) {
      return quantized_linear(input, weight, output, stream);
    }
    if (weight.type != WeightStorage::fp16) {
      return Status::failure("ATB Linear received an unsupported weight type");
    }
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

  Status attention_qkv_rope(
      const TensorView& input, const DeviceWeight& norm_scale,
      const DeviceWeight& query_weight, const DeviceWeight& key_weight,
      const DeviceWeight& value_weight, const TensorView& normalized,
      const TensorView& query, const TensorView& key,
      const TensorView& value, const TransformerBatchPlan& plan,
      Stream stream) override {
    set_stream(stream);
    if (query_weight.type != WeightStorage::fp16 ||
        key_weight.type != WeightStorage::fp16 ||
        value_weight.type != WeightStorage::fp16) {
      return TransformerPrimitiveBackend::attention_qkv_rope(
          input, norm_scale, query_weight, key_weight, value_weight,
          normalized, query, key, value, plan, stream);
    }
    Status status = prepare_rope(plan);
    if (!status.ok) return status;
    GraphEntry* graph = graph_for(
        {GraphKind::attention_qkv_rope, input.rows, input.columns});
    if (!graph) return last_error_;
    atb::VariantPack pack;
    pack.inTensors = {
        fp16(input),
        device_tensor(norm_scale.storage.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(input.columns)}),
        fp16_weight(query_weight), fp16_weight(key_weight),
        fp16_weight(value_weight),
        device_tensor(cos_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(plan.token_count),
                       static_cast<int64_t>(plan.head_size / 2)}),
        device_tensor(sin_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(plan.token_count),
                       static_cast<int64_t>(plan.head_size / 2)}),
        host_i32(q_sequence_lengths_)};
    pack.outTensors = {
        fp16(normalized), fp16(query), fp16(key), fp16(value)};
    return run_graph(*graph, pack, "AttentionQkvRopeGraph");
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

  Status add_rms_norm(const TensorView& left, const TensorView& right,
                      const DeviceWeight& scale,
                      const TensorView& residual,
                      const TensorView& normalized, Stream stream) override {
    set_stream(stream);
    GraphEntry* graph = graph_for(
        {GraphKind::add_rms_norm, left.rows, left.columns});
    if (!graph) return last_error_;
    atb::VariantPack pack;
    pack.inTensors = {
        fp16(left), fp16(right),
        device_tensor(scale.storage.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(left.columns)})};
    pack.outTensors = {fp16(residual), fp16(normalized)};
    return run_graph(*graph, pack, "AddRmsNormGraph");
  }

  Status swiglu(const TensorView& gate, const TensorView& up,
                const TensorView& output, Stream stream) override {
    set_stream(stream);
    GraphEntry* graph =
        graph_for({GraphKind::swiglu, gate.rows, gate.columns});
    if (!graph) return last_error_;
    atb::VariantPack pack;
    pack.inTensors = {fp16(gate), fp16(up)};
    pack.outTensors = {fp16(output)};
    return run_graph(*graph, pack, "SwiGLUGraph");
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

  Status sample_logits(const inference::DeviceBatch& batch,
                       std::size_t vocabulary) {
    if (!batch.device_sampling || !batch.sampled_token_ids ||
        batch.batch_size == 0 || batch.batch_size > 512) {
      return Status::failure("ATB device sampling metadata is invalid");
    }
    const auto* requested = static_cast<const inference::SamplingConfig*>(
        batch.sampling_params);
    std::vector<inference::SamplingConfig> defaults;
    if (!requested) {
      defaults.resize(batch.batch_size);
      requested = defaults.data();
    }

    std::vector<int32_t> topk_host;
    std::vector<uint16_t> topp_host;
    topk_host.reserve(batch.batch_size);
    topp_host.reserve(batch.batch_size);
    atb::infer::TopkToppSamplingParam sampling_param;
    sampling_param.topkToppSamplingType =
        atb::infer::TopkToppSamplingParam::BATCH_TOPK_MULTINOMIAL_SAMPLING;
    sampling_param.randSeeds.reserve(batch.batch_size);
    for (std::size_t row = 0; row < batch.batch_size; ++row) {
      const inference::SamplingConfig& config = requested[row];
      if (!inference::supports_atb_device_sampling(config, vocabulary)) {
        return Status::failure(
            "sampling parameters require the CPU fallback");
      }
      const int32_t topk =
          config.temperature == 0.0F
              ? 1
              : (config.top_k == 0 ? static_cast<int32_t>(vocabulary)
                                   : config.top_k);
      topk_host.push_back(topk);
      topp_host.push_back(
          float_to_fp16_bits(config.temperature == 0.0F ? 1.0F
                                                        : config.top_p));
      sampling_param.randSeeds.push_back(static_cast<uint32_t>(config.seed));
    }
    Status status = upload_i32(sampling_topk_, topk_host);
    if (!status.ok) return status;
    const std::size_t topp_bytes = topp_host.size() * sizeof(uint16_t);
    status = ensure(sampling_topp_, topp_bytes);
    if (!status.ok) return status;
    if (memcpy_async(sampling_topp_.data(), sampling_topp_.size(),
                     topp_host.data(), topp_bytes, MemcpyKind::host_to_device,
                     batch.stream) != kSuccess) {
      return Status::failure(std::string("sampling top-p upload: ") +
                             recent_error());
    }
    const std::size_t probability_bytes =
        batch.batch_size * vocabulary * sizeof(uint16_t);
    status = ensure(sampling_probs_, probability_bytes);
    if (!status.ok) return status;
    status = ensure(sampling_prob_output_,
                    batch.batch_size * sizeof(uint16_t));
    if (!status.ok) return status;

    atb::VariantPack softmax_pack;
    softmax_pack.inTensors = {
        device_tensor(batch.logits, ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(batch.batch_size),
                       static_cast<int64_t>(vocabulary)})};
    softmax_pack.outTensors = {
        device_tensor(sampling_probs_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(batch.batch_size),
                       static_cast<int64_t>(vocabulary)})};
    status = run(softmax_, softmax_pack, "SamplingSoftmax");
    if (!status.ok) return status;

    const atb::Status update =
        atb::UpdateOperationParam(sampling_, sampling_param);
    if (update != atb::NO_ERROR) {
      return atb_error("TopkToppSampling update", update);
    }
    atb::VariantPack sampling_pack;
    sampling_pack.inTensors = {
        device_tensor(sampling_probs_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(batch.batch_size),
                       static_cast<int64_t>(vocabulary)}),
        device_tensor(sampling_topk_.data(), ACL_INT32, ACL_FORMAT_ND,
                      {static_cast<int64_t>(batch.batch_size), 1}),
        device_tensor(sampling_topp_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(batch.batch_size), 1})};
    sampling_pack.outTensors = {
        device_tensor(batch.sampled_token_ids, ACL_INT32, ACL_FORMAT_ND,
                      {static_cast<int64_t>(batch.batch_size), 1}),
        device_tensor(sampling_prob_output_.data(), ACL_FLOAT16, ACL_FORMAT_ND,
                      {static_cast<int64_t>(batch.batch_size), 1})};
    status = run(sampling_, sampling_pack, "TopkToppSampling");
    if (!status.ok) return status;
    return synchronize_stream(batch.stream) == kSuccess
               ? Status::success()
               : Status::failure(std::string("device sampling synchronize: ") +
                                 recent_error());
  }

 private:
  Status quantized_linear(const TensorView& input, const DeviceWeight& weight,
                          const TensorView& output, Stream stream) {
    if (!weight.storage.data() || !weight.scales.data() ||
        weight.rows != input.columns || weight.columns != output.columns) {
      return Status::failure("ACLNN INT8 Linear weight shape is invalid");
    }
    AclTensorHandle x(
        input.data, ACL_FLOAT16,
        {static_cast<int64_t>(input.rows),
         static_cast<int64_t>(input.columns)});
    aclTensor* w = transformed_weight(weight, stream);
    if (!w) return last_error_;
    AclTensorHandle scale(
        weight.scales.data(), ACL_FLOAT16,
        {static_cast<int64_t>(weight.columns)});
    AclTensorHandle y(
        output.data, ACL_FLOAT16,
        {static_cast<int64_t>(output.rows),
         static_cast<int64_t>(output.columns)});
    if (!x.get() || !scale.get() || !y.get()) {
      return Status::failure("aclCreateTensor failed for INT8 Linear");
    }

    uint64_t workspace_bytes = 0;
    aclOpExecutor* executor = nullptr;
    const aclnnStatus prepared =
        aclnnWeightQuantBatchMatmulV2GetWorkspaceSize(
            x.get(), w, scale.get(), nullptr, nullptr, nullptr, nullptr,
            0, y.get(), &workspace_bytes, &executor);
    if (prepared != ACLNN_SUCCESS) {
      return Status::failure(
          "aclnnWeightQuantBatchMatmulV2GetWorkspaceSize status=" +
          std::to_string(prepared));
    }
    if (workspace_bytes > quant_workspace_.size()) {
      Status status = ensure(quant_workspace_, workspace_bytes);
      if (!status.ok) return status;
    }
    const aclnnStatus launched = aclnnWeightQuantBatchMatmulV2(
        quant_workspace_.data(), workspace_bytes, executor, stream);
    return launched == ACLNN_SUCCESS
               ? Status::success()
               : Status::failure("aclnnWeightQuantBatchMatmulV2 status=" +
                                 std::to_string(launched));
  }

  struct QuantWeightEntry {
    const void* source = nullptr;
    DeviceBuffer formatted;
    aclTensor* tensor = nullptr;

    ~QuantWeightEntry() {
      if (tensor) aclDestroyTensor(tensor);
    }
  };

  aclTensor* transformed_weight(const DeviceWeight& weight, Stream stream) {
    for (const auto& entry : quant_weights_) {
      if (entry->source == weight.storage.data()) return entry->tensor;
    }
    auto entry = std::make_unique<QuantWeightEntry>();
    entry->source = weight.storage.data();
    const int64_t dimensions[] = {
        static_cast<int64_t>(weight.columns),
        static_cast<int64_t>(weight.rows)};
    const aclIntArray* shape = aclCreateIntArray(dimensions, 2);
    if (!shape) {
      last_error_ = Status::failure("aclCreateIntArray failed for INT8 weight");
      return nullptr;
    }
    uint64_t formatted_bytes = 0;
    const aclnnStatus sized =
        aclnnCalculateMatmulWeightSizeV2(shape, ACL_INT8, &formatted_bytes);
    aclDestroyIntArray(shape);
    if (sized != ACLNN_SUCCESS || formatted_bytes < weight.storage.size()) {
      last_error_ = Status::failure(
          "aclnnCalculateMatmulWeightSizeV2 status=" +
          std::to_string(sized));
      return nullptr;
    }
    Status status = entry->formatted.allocate(formatted_bytes);
    if (!status.ok) {
      last_error_ = status;
      return nullptr;
    }
    if (memcpy_async(entry->formatted.data(), entry->formatted.size(),
                     weight.storage.data(), weight.storage.size(),
                     MemcpyKind::device_to_device, stream) != kSuccess) {
      last_error_ = Status::failure(
          std::string("INT8 transformed-weight copy: ") + recent_error());
      return nullptr;
    }
    const int64_t strides[] = {dimensions[1], 1};
    entry->tensor = aclCreateTensor(
        dimensions, 2, ACL_INT8, strides, 0, ACL_FORMAT_ND, dimensions, 2,
        entry->formatted.data());
    if (!entry->tensor) {
      last_error_ =
          Status::failure("aclCreateTensor failed for transformed INT8 weight");
      return nullptr;
    }
    uint64_t workspace_bytes = 0;
    aclOpExecutor* executor = nullptr;
    const aclnnStatus prepared = aclnnTransMatmulWeightGetWorkspaceSize(
        entry->tensor, &workspace_bytes, &executor);
    if (prepared != ACLNN_SUCCESS) {
      last_error_ = Status::failure(
          "aclnnTransMatmulWeightGetWorkspaceSize status=" +
          std::to_string(prepared));
      return nullptr;
    }
    status = ensure(quant_transform_workspace_, workspace_bytes);
    if (!status.ok) {
      last_error_ = status;
      return nullptr;
    }
    const aclnnStatus transformed = aclnnTransMatmulWeight(
        quant_transform_workspace_.data(), workspace_bytes, executor, stream);
    if (transformed != ACLNN_SUCCESS) {
      last_error_ = Status::failure("aclnnTransMatmulWeight status=" +
                                    std::to_string(transformed));
      return nullptr;
    }
    aclTensor* result = entry->tensor;
    quant_weights_.push_back(std::move(entry));
    return result;
  }

  enum class GraphKind { swiglu, add_rms_norm, attention_qkv_rope };

  struct GraphKey {
    GraphKind kind;
    std::size_t rows;
    std::size_t columns;

    bool operator==(const GraphKey& other) const {
      return kind == other.kind && rows == other.rows &&
             columns == other.columns;
    }
  };

  struct GraphEntry {
    GraphKey key;
    atb::Operation* graph = nullptr;
    std::vector<atb::Operation*> nodes;
    DeviceBuffer workspace;
  };

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

  void destroy_graph(GraphEntry& entry) {
    if (entry.graph) atb::DestroyOperation(entry.graph);
    entry.graph = nullptr;
    for (atb::Operation* operation : entry.nodes) {
      if (operation) atb::DestroyOperation(operation);
    }
    entry.nodes.clear();
  }

  void clear_graph_cache() {
    for (GraphEntry& entry : graph_cache_) destroy_graph(entry);
    graph_cache_.clear();
  }

  Status create_graph(const GraphKey& key, GraphEntry* entry) {
    if (!entry) return Status::failure("ATB graph cache entry is null");
    entry->key = key;
    atb::GraphParam graph;
    graph.name =
        key.kind == GraphKind::swiglu
            ? "NeurxSwiGLU"
            : (key.kind == GraphKind::add_rms_norm
                   ? "NeurxAddRmsNorm"
                   : "NeurxAttentionQkvRope");
    if (key.kind == GraphKind::swiglu) {
      graph.inTensorNum = 2;
      graph.outTensorNum = 1;
      graph.internalTensorNum = 1;
      graph.nodes.resize(2);
      atb::infer::ActivationParam swish;
      swish.activationType = atb::infer::ACTIVATION_SWISH;
      swish.scale = 1.0F;
      atb::Operation* swish_operation = nullptr;
      atb::Status code = atb::CreateOperation(swish, &swish_operation);
      if (code != atb::NO_ERROR) return atb_error("Graph Swish", code);
      entry->nodes.push_back(swish_operation);
      atb::infer::ElewiseParam multiply;
      multiply.elewiseType = atb::infer::ElewiseParam::ELEWISE_MUL;
      atb::Operation* multiply_operation = nullptr;
      code = atb::CreateOperation(multiply, &multiply_operation);
      if (code != atb::NO_ERROR) {
        destroy_graph(*entry);
        return atb_error("Graph Multiply", code);
      }
      entry->nodes.push_back(multiply_operation);
      graph.nodes[0].operation = swish_operation;
      graph.nodes[0].inTensorIds = {0};
      graph.nodes[0].outTensorIds = {3};
      graph.nodes[1].operation = multiply_operation;
      graph.nodes[1].inTensorIds = {3, 1};
      graph.nodes[1].outTensorIds = {2};
    } else if (key.kind == GraphKind::add_rms_norm) {
      graph.inTensorNum = 3;
      graph.outTensorNum = 2;
      graph.internalTensorNum = 0;
      graph.nodes.resize(2);
      atb::infer::ElewiseParam add;
      add.elewiseType = atb::infer::ElewiseParam::ELEWISE_ADD;
      atb::Operation* add_operation = nullptr;
      atb::Status code = atb::CreateOperation(add, &add_operation);
      if (code != atb::NO_ERROR) return atb_error("Graph Add", code);
      entry->nodes.push_back(add_operation);
      atb::infer::RmsNormParam norm;
      norm.layerType = atb::infer::RmsNormParam::RMS_NORM_NORM;
      norm.normParam.epsilon = 1.0e-5F;
      atb::Operation* norm_operation = nullptr;
      code = atb::CreateOperation(norm, &norm_operation);
      if (code != atb::NO_ERROR) {
        destroy_graph(*entry);
        return atb_error("Graph RmsNorm", code);
      }
      entry->nodes.push_back(norm_operation);
      graph.nodes[0].operation = add_operation;
      graph.nodes[0].inTensorIds = {0, 1};
      graph.nodes[0].outTensorIds = {3};
      graph.nodes[1].operation = norm_operation;
      graph.nodes[1].inTensorIds = {3, 2};
      graph.nodes[1].outTensorIds = {4};
    } else {
      graph.inTensorNum = 8;
      graph.outTensorNum = 4;
      graph.internalTensorNum = 2;
      graph.nodes.resize(5);

      atb::infer::RmsNormParam norm;
      norm.layerType = atb::infer::RmsNormParam::RMS_NORM_NORM;
      norm.normParam.epsilon = 1.0e-5F;
      atb::Operation* norm_operation = nullptr;
      atb::Status code = atb::CreateOperation(norm, &norm_operation);
      if (code != atb::NO_ERROR) return atb_error("Graph QKV RmsNorm", code);
      entry->nodes.push_back(norm_operation);
      graph.nodes[0].operation = norm_operation;
      graph.nodes[0].inTensorIds = {0, 1};
      graph.nodes[0].outTensorIds = {8};

      atb::infer::LinearParam linear;
      linear.transposeA = false;
      linear.transposeB = false;
      linear.hasBias = false;
      constexpr uint32_t projection_outputs[] = {12, 13, 11};
      for (std::size_t projection = 0; projection < 3; ++projection) {
        atb::Operation* linear_operation = nullptr;
        code = atb::CreateOperation(linear, &linear_operation);
        if (code != atb::NO_ERROR) {
          destroy_graph(*entry);
          return atb_error("Graph QKV Linear", code);
        }
        entry->nodes.push_back(linear_operation);
        graph.nodes[projection + 1].operation = linear_operation;
        graph.nodes[projection + 1].inTensorIds = {
            8, static_cast<uint32_t>(projection + 2)};
        graph.nodes[projection + 1].outTensorIds = {
            projection_outputs[projection]};
      }

      atb::infer::RopeParam rope;
      rope.rotaryCoeff = 2;
      atb::Operation* rope_operation = nullptr;
      code = atb::CreateOperation(rope, &rope_operation);
      if (code != atb::NO_ERROR) {
        destroy_graph(*entry);
        return atb_error("Graph QKV RoPE", code);
      }
      entry->nodes.push_back(rope_operation);
      graph.nodes[4].operation = rope_operation;
      graph.nodes[4].inTensorIds = {12, 13, 5, 6, 7};
      graph.nodes[4].outTensorIds = {9, 10};
    }
    const atb::Status code = atb::CreateOperation(graph, &entry->graph);
    if (code != atb::NO_ERROR) {
      destroy_graph(*entry);
      return atb_error("Create GraphOperation", code);
    }
    return Status::success();
  }

  GraphEntry* graph_for(const GraphKey& key) {
    for (auto entry = graph_cache_.begin(); entry != graph_cache_.end();
         ++entry) {
      if (entry->key == key) {
        graph_cache_.splice(graph_cache_.begin(), graph_cache_, entry);
        return &graph_cache_.front();
      }
    }
    GraphEntry entry;
    Status status = create_graph(key, &entry);
    if (!status.ok) {
      last_error_ = status;
      return nullptr;
    }
    graph_cache_.push_front(std::move(entry));
    while (graph_cache_.size() > kMaxGraphCacheEntries) {
      if (stream_ && synchronize_stream(stream_) != kSuccess) {
        last_error_ =
            Status::failure("ATB graph eviction synchronization failed");
        destroy_graph(graph_cache_.front());
        graph_cache_.pop_front();
        return nullptr;
      }
      destroy_graph(graph_cache_.back());
      graph_cache_.pop_back();
    }
    return &graph_cache_.front();
  }

  Status run_graph(GraphEntry& entry, atb::VariantPack& pack,
                   const char* name) {
    uint64_t workspace_bytes = 0;
    atb::Status code =
        entry.graph->Setup(pack, workspace_bytes, context_);
    if (code != atb::NO_ERROR) return atb_error(name, code);
    if (workspace_bytes > entry.workspace.size()) {
      Status status = ensure(entry.workspace, workspace_bytes);
      if (!status.ok) return status;
    }
    code = entry.graph->Execute(
        pack, static_cast<uint8_t*>(entry.workspace.data()), workspace_bytes,
        context_);
    return code == atb::NO_ERROR ? Status::success()
                                 : atb_error(name, code);
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

  atb::Tensor fp16_weight(const DeviceWeight& weight) const {
    return device_tensor(
        weight.storage.data(), ACL_FLOAT16, ACL_FORMAT_ND,
        {static_cast<int64_t>(weight.rows),
         static_cast<int64_t>(weight.columns)});
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
  atb::Operation* add_ = nullptr;
  atb::Operation *softmax_ = nullptr, *sampling_ = nullptr;
  DeviceBuffer workspace_, quant_workspace_, quant_transform_workspace_;
  DeviceBuffer slot_, blocks_, cos_, sin_;
  DeviceBuffer sampling_topk_, sampling_topp_, sampling_probs_;
  DeviceBuffer sampling_prob_output_;
  std::vector<int32_t> slot_host_, block_host_, sequence_lengths_;
  std::vector<int32_t> q_sequence_lengths_;
  static constexpr std::size_t kMaxGraphCacheEntries = 32;
  std::list<GraphEntry> graph_cache_;
  std::list<std::unique_ptr<QuantWeightEntry>> quant_weights_;
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
    if (status.ok && batch.device_sampling) {
      status = backend_.sample_logits(batch, model->metadata().vocabulary);
    }
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

extern "C" uint32_t neurx_cann_operator_abi_version() { return 2; }

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
