package multimodal

type pruning_strategy string

const (
    prune_quality       pruning_strategy = "quality"
    prune_motion        pruning_strategy = "motion"
    prune_content       pruning_strategy = "content"
    prune_temporal      pruning_strategy = "temporal"
)

struct pruning_config {
    pruning_strategy strategy
    int32 target_frame_count
    float32 quality_threshold
    float32 motion_threshold
    bool enable_adaptive_pruning
}

struct frame_importance {
    int32 frame_id
    float32 importance_score
    bool is_selected
    string reason
}

struct video_pruner {
    pruning_config config
    vec[frame_importance*] frame_scores
    int32 total_frames_pruned
    int32 total_frames_kept
}

func create_video_pruner() video_pruner* {
    return &video_pruner{
        config: pruning_config{
            strategy: prune_motion,
            target_frame_count: 8,
            quality_threshold: 0.5,
            motion_threshold: 0.3,
            enable_adaptive_pruning: true,
        },
        frame_scores: make(vec[frame_importance*]),
        total_frames_pruned: 0,
        total_frames_kept: 0,
    }
}

func (video_pruner* pruner) compute_frame_importance(video_data* vid) vec[frame_importance*] {
    scores := make(vec[frame_importance*])
    
    if vid == nil || len(vid.frames) == 0 {
        return scores
    }
    
    for i := 0; i < len(vid.frames); i = i + 1 {
        frame := vid.frames[i]
        
        importance := 0.0
        reason := ""
        
        if frame.info.is_keyframe {
            importance = 1.0
            reason = "keyframe"
        } else if frame.info.scene_change_score > pruner.config.motion_threshold {
            importance = 0.8
            reason = "scene_change"
        } else {
            importance = float32(i) / float32(len(vid.frames))
            reason = "temporal"
        }
        
        score := &frame_importance{
            frame_id: frame.frame_id,
            importance_score: importance,
            is_selected: false,
            reason: reason,
        }
        
        scores = append(scores, score)
    }
    
    pruner.frame_scores = scores
    return scores
}

func (video_pruner* pruner) prune_quality(video_data* vid) vec[video_frame*] {
    result := make(vec[video_frame*])
    
    scores := pruner.compute_frame_importance(vid)
    
    selected_count := 0
    for i := 0; i < len(scores); i = i + 1 {
        if selected_count >= pruner.config.target_frame_count {
            break
        }
        
        if scores[i].importance_score >= pruner.config.quality_threshold {
            scores[i].is_selected = true
            if scores[i].frame_id >= 0 && scores[i].frame_id < len(vid.frames) {
                result = append(result, vid.frames[scores[i].frame_id])
            }
            selected_count = selected_count + 1
        }
    }
    
    pruner.total_frames_kept = selected_count
    pruner.total_frames_pruned = len(vid.frames) - selected_count
    
    return result
}

func (video_pruner* pruner) prune_motion(video_data* vid) vec[video_frame*] {
    result := make(vec[video_frame*])
    
    scores := pruner.compute_frame_importance(vid)
    
    selected_indices := make(vec[int32])
    selected_count := 0
    
    for i := 0; i < len(scores); i = i + 1 {
        if selected_count >= pruner.config.target_frame_count {
            break
        }
        
        score := scores[i]
        
        can_select := true
        for j := 0; j < len(selected_indices); j = j + 1 {
            if selected_indices[j] == score.frame_id {
                can_select = false
                break
            }
        }
        
        if can_select && score.importance_score > pruner.config.motion_threshold {
            score.is_selected = true
            selected_indices = append(selected_indices, score.frame_id)
            if score.frame_id < int32(len(vid.frames)) && score.frame_id >= 0 {
                result = append(result, vid.frames[score.frame_id])
            }
            selected_count = selected_count + 1
        }
    }
    
    pruner.total_frames_kept = selected_count
    pruner.total_frames_pruned = len(vid.frames) - selected_count
    
    return result
}

func (video_pruner* pruner) prune_temporal(video_data* vid) vec[video_frame*] {
    result := make(vec[video_frame*])
    
    if len(vid.frames) == 0 {
        return result
    }
    
    interval := len(vid.frames) / pruner.config.target_frame_count
    if interval <= 0 {
        interval = 1
    }
    
    selected_count := 0
    for i := 0; i < len(vid.frames); i = i + interval {
        if selected_count >= pruner.config.target_frame_count {
            break
        }
        
        result = append(result, vid.frames[i])
        selected_count = selected_count + 1
    }
    
    pruner.total_frames_kept = selected_count
    pruner.total_frames_pruned = len(vid.frames) - selected_count
    
    return result
}

func (video_pruner* pruner) prune_video(video_data* vid) vec[video_frame*] {
    if pruner.config.strategy == prune_quality {
        return pruner.prune_quality(vid)
    }
    if pruner.config.strategy == prune_motion {
        return pruner.prune_motion(vid)
    }
    if pruner.config.strategy == prune_temporal {
        return pruner.prune_temporal(vid)
    }
    
    return pruner.prune_temporal(vid)
}

func (video_pruner* pruner) get_pruning_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["strategy"] = pruner.config.strategy
    stats["target_frame_count"] = pruner.config.target_frame_count
    stats["frames_kept"] = pruner.total_frames_kept
    stats["frames_pruned"] = pruner.total_frames_pruned
    return stats
}
