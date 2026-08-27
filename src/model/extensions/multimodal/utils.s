package neurx.multimodal.utils

import (
    "neurx.tensor.types"
    "neurx.multimodal.types"
)

struct ImageValidator {
    min_width: i32,
    min_height: i32,
    max_width: i32,
    max_height: i32,
    supported_formats: []types.ImageFormat
}

func NewImageValidator() *ImageValidator {
    return *ImageValidator{
        min_width: 32,
        min_height: 32,
        max_width: 4096,
        max_height: 4096,
        supported_formats: []types.ImageFormat{
            types.ImageFormat.rgb,
            types.ImageFormat.rgba,
            types.ImageFormat.bgr
        }
    }
}

func (ImageValidator* v) ValidateImage(
    img: *types.ImageData
) bool {

    if img.width < v.min_width || img.width > v.max_width {
        return false
    }
    if img.height < v.min_height || img.height > v.max_height {
        return false
    }

    format_valid := false
    for _, fmt := range v.supported_formats {
        if fmt == img.format {
            format_valid = true
            break
        }
    }

    if !format_valid {
        return false
    }

    expected_size := img.width * img.height * img.channels
    if i32(len(img.raw_data)) != expected_size {
        return false
    }

    return true
}

struct AudioValidator {
    min_sample_rate: i32,
    max_sample_rate: i32,
    min_duration_ms: i32,
    max_duration_ms: i32
}

func NewAudioValidator() *AudioValidator {
    return *AudioValidator{
        min_sample_rate: 8000,
        max_sample_rate: 48000,
        min_duration_ms: 100,
        max_duration_ms: 300000
    }
}

func (AudioValidator* v) ValidateAudio(
    audio: *types.AudioData
) bool {

    if audio.sample_rate < v.min_sample_rate ||
       audio.sample_rate > v.max_sample_rate {
        return false
    }

    duration_ms := i32(len(audio.samples) * 1000 / audio.sample_rate)
    if duration_ms < v.min_duration_ms ||
       duration_ms > v.max_duration_ms {
        return false
    }

    if audio.num_channels < 1 || audio.num_channels > 8 {
        return false
    }

    return true
}

struct ModalityStatistics {
    modality: types.Modality,
    count: i32,
    total_size_bytes: i64,
    avg_encoding_time_ms: f32,
    min_value: f32,
    max_value: f32,
    mean_value: f32
}

struct StatisticsCollector {
    stats: map[types.Modality, ModalityStatistics]
}

func NewStatisticsCollector() *StatisticsCollector {
    return *StatisticsCollector{
        stats: make(map[types.Modality, ModalityStatistics])
    }
}

func (StatisticsCollector* s) RecordImageProcessing(
    img: *types.ImageData,
    encoding_time_ms: f32
) {
    size := i64(len(img.raw_data))

    var stat ModalityStatistics
    if existing, exists := s.stats[types.Modality.image]; exists {
        stat = existing
    } else {
        stat = ModalityStatistics{
            modality: types.Modality.image,
            count: 0,
            total_size_bytes: 0,
            avg_encoding_time_ms: 0.0,
            min_value: 255.0,
            max_value: 0.0,
            mean_value: 0.0
        }
    }

    stat.count += 1
    stat.total_size_bytes += size
    stat.avg_encoding_time_ms = (stat.avg_encoding_time_ms * f32(stat.count - 1) + encoding_time_ms) / f32(stat.count)

    s.stats[types.Modality.image] = stat
}

func (StatisticsCollector* s) GetStatistics(
    modality: types.Modality
) ModalityStatistics {
    if stat, exists := s.stats[modality]; exists {
        return stat
    }

    return ModalityStatistics{
        modality: modality,
        count: 0,
        total_size_bytes: 0,
        avg_encoding_time_ms: 0.0,
        min_value: 0.0,
        max_value: 0.0,
        mean_value: 0.0
    }
}

struct BatchProcessor {
    batch_size: i32,
    max_batch_memory_mb: i64
}

func NewBatchProcessor(i32 batch_size) *BatchProcessor {
    return *BatchProcessor{
        batch_size: batch_size,
        max_batch_memory_mb: 4096
    }
}

func (BatchProcessor* b) CanAddToBatch(
    current_size: i32,
    current_memory_mb: i64,
    new_item_memory_mb: i64
) bool {
    if current_size >= b.batch_size {
        return false
    }

    if current_memory_mb + new_item_memory_mb > b.max_batch_memory_mb {
        return false
    }

    return true
}

struct TensorUtils {
}

func TensorStackTensors(
    tensors: []types.Tensor
) *types.Tensor {
    if len(tensors) == 0 {
        return nil
    }

    batch_size := i32(len(tensors))
    feature_dim := tensors[0].shape[len(tensors[0].shape) - 1]

    stacked := make([]f32, batch_size * feature_dim)
    idx := 0

    for i := 0; i < len(tensors); i += 1 {
        for j := 0; j < len(tensors[i].data); j += 1 {
            stacked[idx] = tensors[i].data[j]
            idx += 1
        }
    }

    return *types.Tensor{
        data: stacked,
        shape: [2]i32{batch_size, feature_dim},
        dtype: "float32"
    }
}

func ConcatenateEmbeddings(
    embeddings: []*types.Tensor
) *types.Tensor {
    if len(embeddings) == 0 {
        return nil
    }

    seq_len := embeddings[0].shape[0]
    total_dim := i32(0)

    for i := 0; i < len(embeddings); i += 1 {
        total_dim += embeddings[i].shape[1]
    }

    concatenated := make([]f32, seq_len * total_dim)
    col_idx := 0

    for i := 0; i < len(embeddings); i += 1 {
        emb_dim := embeddings[i].shape[1]

        for seq := 0; seq < seq_len; seq += 1 {
            for dim := 0; dim < emb_dim; dim += 1 {
                concatenated[seq * total_dim + col_idx + dim] = embeddings[i].data[seq * emb_dim + dim]
            }
        }

        col_idx += emb_dim
    }

    return *types.Tensor{
        data: concatenated,
        shape: [2]i32{seq_len, total_dim},
        dtype: "float32"
    }
}

func ComputeSimilarity(
    emb1: *types.Tensor,
    emb2: *types.Tensor
) f32 {
    if len(emb1.data) != len(emb2.data) {
        return 0.0
    }

    dot_product := f32(0.0)
    norm1 := f32(0.0)
    norm2 := f32(0.0)

    for i := 0; i < len(emb1.data); i += 1 {
        dot_product += emb1.data[i] * emb2.data[i]
        norm1 += emb1.data[i] * emb1.data[i]
        norm2 += emb2.data[i] * emb2.data[i]
    }

    if norm1 == 0.0 || norm2 == 0.0 {
        return 0.0
    }

    return dot_product / (Sqrt(f64(norm1)) * Sqrt(f64(norm2)))
}

func Sqrt(f64 x) f64 {
    if x == 0.0 {
        return 0.0
    }

    result := x
    for i := 0; i < 10; i += 1 {
        result = (result + x / result) / 2.0
    }
    return result
}

func NormalizeEmbedding(
    embedding: *types.Tensor
) *types.Tensor {
    norm := f32(0.0)

    for i := 0; i < len(embedding.data); i += 1 {
        norm += embedding.data[i] * embedding.data[i]
    }

    norm = f32(Sqrt(f64(norm)))

    if norm == 0.0 {
        return embedding
    }

    normalized := make([]f32, len(embedding.data))
    for i := 0; i < len(embedding.data); i += 1 {
        normalized[i] = embedding.data[i] / norm
    }

    return *types.Tensor{
        data: normalized,
        shape: embedding.shape,
        dtype: embedding.dtype
    }
}

func main() {
    println("Multimodal Utils Module")
    println("✅ Utility functions ready")
}
