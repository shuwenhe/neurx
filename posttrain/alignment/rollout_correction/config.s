import "tensor/tensor.s"
enum ISAggregationLevel {
    NONE,
    TOKEN,
    SEQUENCE
}
enum RejectionMode {
    NONE,
    TOKEN_K1,
    TOKEN_K2,
    TOKEN_K3,
    SEQ_SUM_K1,
    SEQ_SUM_K2,
    SEQ_SUM_K3,
    SEQ_MEAN_K1,
    SEQ_MEAN_K2,
    SEQ_MEAN_K3,
    SEQ_MAX_K2,
    SEQ_MAX_K3
}
enum LossType {
    PPO_CLIP,
    REINFORCE
}
struct ISThreshold {
    lower: f32
    upper: f32
    is_icepop: bool
}

struct RSThreshold {
    lower: f32
    upper: f32
}

struct RolloutCorrectionConfig {
    is_level: ISAggregationLevel
    is_threshold: ISThreshold
    is_batch_normalize: bool
    rs_modes: []RejectionMode
    rs_thresholds: []RSThreshold
    bypass_mode: bool
    loss_type: LossType
}
func new_rollout_correction_config() -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.NONE,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: 1e10,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [],
        rs_thresholds: [],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func parse_threshold(threshold_str: string) -> (f32, f32) {
    if threshold_str.contains("_") {
        let parts = threshold_str.split("_")
        if parts.len() != 2 {
            panic("Invalid threshold format, expected 'lower_upper'")
        }
        let lower = parse_f32(parts[0])
        let upper = parse_f32(parts[1])
        return lower, upper
    } else {
        let upper = parse_f32(threshold_str)
        let lower = 1.0 / upper
        return lower, upper
    }
}

func decoupled_token_is(threshold: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.TOKEN,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: threshold,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [],
        rs_thresholds: [],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func decoupled_seq_is(threshold: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.SEQUENCE,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: threshold,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [],
        rs_thresholds: [],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func decoupled_token_icepop(threshold_lower: f32, threshold_upper: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.TOKEN,
        is_threshold: ISThreshold{
            lower: threshold_lower,
            upper: threshold_upper,
            is_icepop: true,
        },
        is_batch_normalize: false,
        rs_modes: [],
        rs_thresholds: [],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func decoupled_seq_is_rs(is_threshold: f32, rs_lower: f32, rs_upper: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.SEQUENCE,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: is_threshold,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_SUM_K1],
        rs_thresholds: [RSThreshold{lower: rs_lower, upper: rs_upper}],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func decoupled_geo_rs(rs_lower: f32, rs_upper: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.NONE,
        is_threshold: ISThreshold{lower: 0.0, upper: 1e10, is_icepop: false},
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_MEAN_K1],
        rs_thresholds: [RSThreshold{lower: rs_lower, upper: rs_upper}],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func decoupled_k3_rs(rs_upper: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.NONE,
        is_threshold: ISThreshold{lower: 0.0, upper: 1e10, is_icepop: false},
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_SUM_K3],
        rs_thresholds: [RSThreshold{lower: 0.0, upper: rs_upper}],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func decoupled_k3_rs_seq_tis(rs_upper: f32, is_threshold: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.SEQUENCE,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: is_threshold,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_SUM_K3],
        rs_thresholds: [RSThreshold{lower: 0.0, upper: rs_upper}],
        bypass_mode: false,
        loss_type: LossType.PPO_CLIP,
    }
}

func bypass_ppo_clip() -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.NONE,
        is_threshold: ISThreshold{lower: 0.0, upper: 1e10, is_icepop: false},
        is_batch_normalize: false,
        rs_modes: [],
        rs_thresholds: [],
        bypass_mode: true,
        loss_type: LossType.PPO_CLIP,
    }
}

func bypass_ppo_clip_geo_rs(rs_lower: f32, rs_upper: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.NONE,
        is_threshold: ISThreshold{lower: 0.0, upper: 1e10, is_icepop: false},
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_MEAN_K1],
        rs_thresholds: [RSThreshold{lower: rs_lower, upper: rs_upper}],
        bypass_mode: true,
        loss_type: LossType.PPO_CLIP,
    }
}

func bypass_ppo_clip_k3_rs(rs_upper: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.NONE,
        is_threshold: ISThreshold{lower: 0.0, upper: 1e10, is_icepop: false},
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_SUM_K3],
        rs_thresholds: [RSThreshold{lower: 0.0, upper: rs_upper}],
        bypass_mode: true,
        loss_type: LossType.PPO_CLIP,
    }
}

func bypass_pg_is(is_threshold: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.SEQUENCE,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: is_threshold,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [],
        rs_thresholds: [],
        bypass_mode: true,
        loss_type: LossType.REINFORCE,
    }
}

func bypass_pg_geo_rs(rs_lower: f32, rs_upper: f32) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.NONE,
        is_threshold: ISThreshold{lower: 0.0, upper: 1e10, is_icepop: false},
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_MEAN_K1],
        rs_thresholds: [RSThreshold{lower: rs_lower, upper: rs_upper}],
        bypass_mode: true,
        loss_type: LossType.REINFORCE,
    }
}

func bypass_pg_geo_rs_seq_tis(
    rs_lower: f32,
    rs_upper: f32,
    is_threshold: f32
) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.SEQUENCE,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: is_threshold,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_MEAN_K1],
        rs_thresholds: [RSThreshold{lower: rs_lower, upper: rs_upper}],
        bypass_mode: true,
        loss_type: LossType.REINFORCE,
    }
}

func bypass_pg_geo_rs_token_tis(
    rs_lower: f32,
    rs_upper: f32,
    is_threshold: f32
) -> RolloutCorrectionConfig {
    return RolloutCorrectionConfig{
        is_level: ISAggregationLevel.TOKEN,
        is_threshold: ISThreshold{
            lower: 0.0,
            upper: is_threshold,
            is_icepop: false,
        },
        is_batch_normalize: false,
        rs_modes: [RejectionMode.SEQ_MEAN_K1],
        rs_thresholds: [RSThreshold{lower: rs_lower, upper: rs_upper}],
        bypass_mode: true,
        loss_type: LossType.REINFORCE,
    }
}

func parse_f32(s: string) -> f32 {
    return 1.0
}
