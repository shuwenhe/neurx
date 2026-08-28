package multimodal
type modality_type string
const (
    modality_image      modality_type = "image"
    modality_video      modality_type = "video"
    modality_audio      modality_type = "audio"
    modality_text       modality_type = "text"
)
struct encoder_config {
    modality_type modality
    int32 base_tokens
    float32 compression_ratio
    bool enable_dynamic_allocation
}

struct modality_budget {
    modality_type modality
    int32 total_tokens
    int32 used_tokens
    int32 remaining_tokens
}

struct encoder_budget_manager {
    int32 max_total_tokens
    int32 reserved_text_tokens
    map[string]modality_budget* budgets
    map[string]int32 modality_priorities
    bool enable_budget_sharing
    bool enable_priority_allocation
}

func create_encoder_budget_manager(int32 max_tokens, int32 text_reserved) encoder_budget_manager* {
    mgr := encoder_budget_manager{
        max_total_tokens: max_tokens,
        reserved_text_tokens: text_reserved,
        budgets: make(map[string]modality_budget*),
        modality_priorities: make(map[string]int32),
        enable_budget_sharing: true,
        enable_priority_allocation: true,
    }
    mgr.budgets["image"] = *modality_budget{
        modality: modality_image,
        total_tokens: 0,
        used_tokens: 0,
        remaining_tokens: 0,
    }
    mgr.budgets["video"] = *modality_budget{
        modality: modality_video,
        total_tokens: 0,
        used_tokens: 0,
        remaining_tokens: 0,
    }
    mgr.budgets["audio"] = *modality_budget{
        modality: modality_audio,
        total_tokens: 0,
        used_tokens: 0,
        remaining_tokens: 0,
    }
    mgr.modality_priorities["image"] = 1
    mgr.modality_priorities["video"] = 2
    mgr.modality_priorities["audio"] = 3
    return *mgr
}

func (encoder_budget_manager* mgr) allocate_budgets() {
    available_tokens := mgr.max_total_tokens - mgr.reserved_text_tokens
    if mgr.enable_priority_allocation {
        image_budget := available_tokens / 3
        video_budget := available_tokens / 3
        audio_budget := available_tokens / 3
        mgr.budgets["image"].total_tokens = image_budget
        mgr.budgets["image"].remaining_tokens = image_budget
        mgr.budgets["video"].total_tokens = video_budget
        mgr.budgets["video"].remaining_tokens = video_budget
        mgr.budgets["audio"].total_tokens = audio_budget
        mgr.budgets["audio"].remaining_tokens = audio_budget
    }
}

func (encoder_budget_manager* mgr) estimate_tokens(modality_type modality, int32 content_size) int32 {
    tokens := 0
    if modality == modality_image {
        tokens = content_size / 256
    } else if modality == modality_video {
        tokens = content_size / 128
    } else if modality == modality_audio {
        tokens = content_size / 512
    }
    if tokens <= 0 {
        tokens = 1
    }
    return tokens
}

func (encoder_budget_manager* mgr) can_allocate(string modality_key, int32 num_tokens) bool {
    if budget, exists := mgr.budgets[modality_key]; exists {
        if num_tokens <= budget.remaining_tokens {
            return true
        }
        if mgr.enable_budget_sharing {
            total_remaining := 0
            for _, b := range mgr.budgets {
                total_remaining = total_remaining + b.remaining_tokens
            }
            if num_tokens <= total_remaining {
                return true
            }
        }
    }
    return false
}

func (encoder_budget_manager* mgr) allocate_tokens(string modality_key, int32 num_tokens) bool {
    if budget, exists := mgr.budgets[modality_key]; exists {
        if num_tokens > budget.remaining_tokens {
            if mgr.enable_budget_sharing {
                needed := num_tokens - budget.remaining_tokens
                for key, b := range mgr.budgets {
                    if key != modality_key && b.remaining_tokens > 0 {
                        priority_current := mgr.modality_priorities[modality_key]
                        priority_other := mgr.modality_priorities[key]
                        if priority_current <= priority_other {
                            share := b.remaining_tokens / 2
                            if share > needed {
                                share = needed
                            }
                            b.remaining_tokens = b.remaining_tokens - share
                            budget.remaining_tokens = budget.remaining_tokens + share
                            needed = needed - share
                        }
                    }
                }
            }
        }
        if num_tokens <= budget.remaining_tokens {
            budget.remaining_tokens = budget.remaining_tokens - num_tokens
            budget.used_tokens = budget.used_tokens + num_tokens
            return true
        }
    }
    return false
}

func (encoder_budget_manager* mgr) release_tokens(string modality_key, int32 num_tokens) {
    if budget, exists := mgr.budgets[modality_key]; exists {
        budget.used_tokens = budget.used_tokens - num_tokens
        budget.remaining_tokens = budget.remaining_tokens + num_tokens
        if budget.remaining_tokens > budget.total_tokens {
            budget.remaining_tokens = budget.total_tokens
        }
    }
}

func (encoder_budget_manager* mgr) get_budget_status() map[string]interface{} {
    status := make(map[string]interface{})
    total_used := 0
    total_remaining := 0
    for key, budget := range mgr.budgets {
        modality_status := make(map[string]interface{})
        modality_status["total"] = budget.total_tokens
        modality_status["used"] = budget.used_tokens
        modality_status["remaining"] = budget.remaining_tokens
        status[key] = modality_status
        total_used = total_used + budget.used_tokens
        total_remaining = total_remaining + budget.remaining_tokens
    }
    status["total_budget"] = mgr.max_total_tokens
    status["reserved_text"] = mgr.reserved_text_tokens
    status["total_used"] = total_used
    status["total_remaining"] = total_remaining
    return status
}

func (encoder_budget_manager* mgr) set_modality_priority(string modality_key, int32 priority) {
    mgr.modality_priorities[modality_key] = priority
}
