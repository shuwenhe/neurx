package neurx.multimodal

struct multimodal_batch {
    int32 batch_size
    int32 seq_len
    []int32 token_ids
    []f32 image_features
    []f32 audio_features
}

func new_batch(
    int32 batch_size,
    int32 seq_len,
    []int32 token_ids,
    []f32 image_features,
    []f32 audio_features
) multimodal_batch {
    multimodal_batch {
        batch_size: batch_size,
        seq_len: seq_len,
        token_ids: token_ids,
        image_features: image_features,
        audio_features: audio_features,
    }
}

func token_count(multimodal_batch batch) int32 {
    len(batch.token_ids)
}
