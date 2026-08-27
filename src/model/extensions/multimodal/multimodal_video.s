package multimodal

type sampling_strategy string

const (
    strategy_uniform        sampling_strategy = "uniform"
    strategy_keyframe       sampling_strategy = "keyframe"
    strategy_adaptive       sampling_strategy = "adaptive"
)

struct frame_info {
    int32 frame_id
    int32 timestamp_ms
    bool is_keyframe
    float32 scene_change_score
}

struct video_metadata {
    int32 width
    int32 height
    int32 total_frames
    int32 fps
    int32 duration_ms
    string codec
    int32 bitrate_kbps
}

struct video_frame {
    int32 frame_id
    uint8[] frame_data
    frame_info* info
    int32 size_bytes
}

struct video_data {
    video_frame*[] frames
    video_metadata* metadata
    int32 total_frames
    string source_url
}

struct video_processor {
    int32 target_fps
    int32 max_frames_to_extract
    sampling_strategy strategy

    bool enable_motion_detection
    float32 motion_threshold

    bool enable_scene_detection
    float32 scene_change_threshold
}

func create_video_processor() video_processor* {
    return *video_processor{
        target_fps: 2,
        max_frames_to_extract: 8,
        strategy: strategy_keyframe,
        enable_motion_detection: true,
        motion_threshold: 0.5,
        enable_scene_detection: true,
        scene_change_threshold: 0.3,
    }
}

func (video_processor* proc) extract_frames_uniform(video_data* vid, int32 num_frames) video_frame*[] {
    result := make(video_frame*[])

    if vid == nil || vid.metadata == nil || vid.total_frames == 0 {
        return result
    }

    if num_frames > vid.total_frames {
        num_frames = vid.total_frames
    }

    interval := vid.total_frames / num_frames
    if interval <= 0 {
        interval = 1
    }

    for i := 0; i < num_frames; i = i + 1 {
        frame_idx := i * interval
        if frame_idx < len(vid.frames) {
            result = append(result, vid.frames[frame_idx])
        }
    }

    return result
}

func (video_processor* proc) extract_frames_keyframe(video_data* vid, int32 num_frames) video_frame*[] {
    result := make(video_frame*[])

    if vid == nil || vid.metadata == nil {
        return result
    }

    keyframe_count := 0
    for i := 0; i < len(vid.frames) && keyframe_count < num_frames; i = i + 1 {
        if vid.frames[i].info.is_keyframe {
            result = append(result, vid.frames[i])
            keyframe_count = keyframe_count + 1
        }
    }

    if len(result) < num_frames {
        for i := 0; i < len(vid.frames) && len(result) < num_frames; i = i + 1 {
            found := false
            for j := 0; j < len(result); j = j + 1 {
                if result[j].frame_id == vid.frames[i].frame_id {
                    found = true
                    break
                }
            }
            if !found {
                result = append(result, vid.frames[i])
            }
        }
    }

    return result
}

func (video_processor* proc) extract_frames_adaptive(video_data* vid, int32 num_frames) video_frame*[] {
    result := make(video_frame*[])

    if vid == nil || vid.metadata == nil {
        return result
    }

    keyframes := proc.extract_frames_keyframe(vid, num_frames / 2)
    for i := 0; i < len(keyframes); i = i + 1 {
        result = append(result, keyframes[i])
    }

    uniform_frames := proc.extract_frames_uniform(vid, num_frames / 2)
    for i := 0; i < len(uniform_frames); i = i + 1 {
        found := false
        for j := 0; j < len(result); j = j + 1 {
            if result[j].frame_id == uniform_frames[i].frame_id {
                found = true
                break
            }
        }
        if !found {
            result = append(result, uniform_frames[i])
        }
    }

    return result
}

func (video_processor* proc) extract_frames(video_data* vid, int32 num_frames) video_frame*[] {
    if proc.strategy == strategy_uniform {
        return proc.extract_frames_uniform(vid, num_frames)
    }
    if proc.strategy == strategy_keyframe {
        return proc.extract_frames_keyframe(vid, num_frames)
    }
    if proc.strategy == strategy_adaptive {
        return proc.extract_frames_adaptive(vid, num_frames)
    }

    return proc.extract_frames_uniform(vid, num_frames)
}

func (video_processor* proc) detect_scene_changes(video_data* vid) int32[] {
    scene_changes := make(int32[])

    if vid == nil || len(vid.frames) < 2 {
        return scene_changes
    }

    for i := 1; i < len(vid.frames); i = i + 1 {
        if vid.frames[i].info.scene_change_score > proc.scene_change_threshold {
            scene_changes = append(scene_changes, int32(i))
        }
    }

    return scene_changes
}

func (video_processor* proc) get_video_stats(video_data* vid) map[string]interface{} {
    stats := make(map[string]interface{})

    if vid == nil || vid.metadata == nil {
        return stats
    }

    stats["width"] = vid.metadata.width
    stats["height"] = vid.metadata.height
    stats["total_frames"] = vid.metadata.total_frames
    stats["fps"] = vid.metadata.fps
    stats["duration_ms"] = vid.metadata.duration_ms
    stats["codec"] = vid.metadata.codec

    return stats
}
