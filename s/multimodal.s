package neurx.multimodal

use neurx.tensor.tensor
use neurx.tensor.new

func _copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _copy_tensor(tensor value) tensor {
    new(_copy_float(value.data), _copy_int(value.shape), value.requires_grad)
}

struct multimodal_batch {
    int batch_size
    int seq_len
    []int token_ids
    []float image_features
    []float audio_features
}

func new_batch(
    int batch_size,
    int seq_len,
    []int token_ids,
    []float image_features,
    []float audio_features
) multimodal_batch {
    multimodal_batch {
        batch_size: batch_size,
        seq_len: seq_len,
        token_ids: token_ids,
        image_features: image_features,
        audio_features: audio_features,
    }
}

func multimodal_state_dict(multimodal_batch batch) multimodal_batch {
    multimodal_batch {
        batch_size: batch.batch_size,
        seq_len: batch.seq_len,
        token_ids: _copy_int(batch.token_ids),
        image_features: _copy_float(batch.image_features),
        audio_features: _copy_float(batch.audio_features),
    }
}

func multimodal_load_state_dict(multimodal_batch batch, multimodal_batch other) multimodal_batch {
    del batch
    multimodal_batch {
        batch_size: other.batch_size,
        seq_len: other.seq_len,
        token_ids: _copy_int(other.token_ids),
        image_features: _copy_float(other.image_features),
        audio_features: _copy_float(other.audio_features),
    }
}

func token_count(multimodal_batch batch) int {
    len(batch.token_ids)
}
