package neurx.multimodal

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

func token_count(multimodal_batch batch) int {
    len(batch.token_ids)
}
