package models

import (
	"fmt"
	"sync"
	"time"
)

type sync_method int32
const (
	SYNC_CROSS_CORRELATION sync_method = iota
	SYNC_DTW
	SYNC_TEMPORAL_ALIGNMENT
	SYNC_PHASE_CORRELATION
	SYNC_FEATURE_MATCHING
)

struct sync_result {
	bool is_synchronized
	float64 time_offset_ms
	float32 confidence_score
	sync_method method_used
	string sync_status
	time.Time sync_time
}

struct audio_video_pair {
	*audio_data audio
	*video_data video
	string pair_id
	float64 duration_difference_ms
	bool manually_aligned
	time.Time created_at
}

struct temporal_alignment {
	int32 audio_frame_index
	int32 video_frame_index
	float64 audio_timestamp
	float64 video_timestamp
	float32 confidence
	bool is_keypoint
}

struct sync_statistics {
	int32 num_alignment_points
	float64 max_time_offset_ms
	float64 mean_time_offset_ms
	float32 alignment_confidence
	int64 num_sync_attempts
	int64 successful_syncs
	time.Time last_sync_time
}

struct audio_video_aligner {
	sync.Mutex mu
	map[string]*audio_video_pair pair_cache
	map[string]*sync_result latest_sync_results
	map[string][]temporal_alignment alignments
	*sync_statistics stats
	sync_method default_method
	float32 confidence_threshold
	int32 search_window_ms
	time.Time created_at
}

func create_audio_video_aligner() *audio_video_aligner {
	ava := &audio_video_aligner{
		pair_cache:            make(map[string]*audio_video_pair),
		latest_sync_results:   make(map[string]*sync_result),
		alignments:            make(map[string][]temporal_alignment),
		stats: *sync_statistics{
			num_alignment_points:     0,
			max_time_offset_ms:       0,
			mean_time_offset_ms:      0,
			alignment_confidence:     0,
			num_sync_attempts:        0,
			successful_syncs:         0,
			last_sync_time:           time.Now(),
		},
		default_method:        SYNC_CROSS_CORRELATION,
		confidence_threshold:  0.8,
		search_window_ms:      5000,
		created_at:            time.Now(),
	}

	return ava
}

func (audio_video_aligner* ava) create_pair(audio_id string, video_id string, audio *audio_data, video *video_data) (string, error) {
	ava.mu.Lock()
	defer ava.mu.Unlock()

	pair_id := audio_id + "_" + video_id
	if _, exists := ava.pair_cache[pair_id]; exists {
		return "", fmt.Errorf("pair already exists")
	}

	pair := &audio_video_pair{
		audio:                  audio,
		video:                  video,
		pair_id:                pair_id,
		duration_difference_ms: (audio.metadata.duration_seconds - video.metadata.duration_seconds) * 1000,
		manually_aligned:       false,
		created_at:             time.Now(),
	}

	ava.pair_cache[pair_id] = pair

	return pair_id, nil
}

func (audio_video_aligner* ava) sync_cross_correlation(pair_id string) (*sync_result, error) {
	ava.mu.Lock()
	pair, exists := ava.pair_cache[pair_id]
	ava.mu.Unlock()

	if !exists {
		return nil, fmt.Errorf("pair %s not found", pair_id)
	}

	if len(pair.audio.samples) == 0 || len(pair.video.frames) == 0 {
		return nil, fmt.Errorf("empty audio or video data")
	}

	max_correlation := float32(0)
	best_offset := float64(0)

	audio_len := len(pair.audio.samples)
	video_len := len(pair.video.frames)

	max_frames := 100
	if video_len > max_frames {
		video_len = max_frames
	}

	for offset := -5000; offset <= 5000; offset += 100 {
		correlation := float32(0)
		count := 0

		for i := 0; i < audio_len && i < video_len; i++ {
			audio_idx := i
			video_idx := i

			if audio_idx >= 0 && audio_idx < len(pair.audio.samples) &&
				video_idx >= 0 && video_idx < len(pair.video.frames) {
				correlation += pair.audio.samples[audio_idx] * float32(pair.video.frames[video_idx].motion_score)
				count++
			}
		}

		if count > 0 {
			correlation /= float32(count)
		}

		if correlation > max_correlation {
			max_correlation = correlation
			best_offset = float64(offset)
		}
	}

	confidence := max_correlation
	if confidence > 1.0 {
		confidence = 1.0
	}
	if confidence < 0 {
		confidence = 0
	}

	result := &sync_result{
		is_synchronized:   confidence > ava.confidence_threshold,
		time_offset_ms:    best_offset,
		confidence_score:  confidence,
		method_used:       SYNC_CROSS_CORRELATION,
		sync_status:       "completed",
		sync_time:         time.Now(),
	}

	ava.mu.Lock()
	ava.latest_sync_results[pair_id] = result
	ava.stats.num_sync_attempts++
	if result.is_synchronized {
		ava.stats.successful_syncs++
	}
	ava.mu.Unlock()

	return result, nil
}

func (audio_video_aligner* ava) sync_dtw(pair_id string) (*sync_result, error) {
	ava.mu.Lock()
	pair, exists := ava.pair_cache[pair_id]
	ava.mu.Unlock()

	if !exists {
		return nil, fmt.Errorf("pair %s not found", pair_id)
	}

	if len(pair.audio.samples) == 0 || len(pair.video.frames) == 0 {
		return nil, fmt.Errorf("empty audio or video data")
	}

	audio_len := len(pair.audio.samples)
	video_len := len(pair.video.frames)

	if audio_len > 1000 {
		audio_len = 1000
	}
	if video_len > 1000 {
		video_len = 1000
	}

	dtw_matrix := make([][]float32, audio_len)
	for i := 0; i < audio_len; i++ {
		dtw_matrix[i] = make([]float32, video_len)
		for j := 0; j < video_len; j++ {
			dtw_matrix[i][j] = 999999.0
		}
	}

	for i := 0; i < audio_len; i++ {
		for j := 0; j < video_len; j++ {
			cost := float32(0)
			if i < len(pair.audio.samples) && j < len(pair.video.frames) {
				audio_val := pair.audio.samples[i]
				video_val := pair.video.frames[j].motion_score
				diff := audio_val - video_val
				cost = diff * diff
			}

			if i == 0 && j == 0 {
				dtw_matrix[i][j] = cost
			} else if i == 0 {
				dtw_matrix[i][j] = cost + dtw_matrix[i][j-1]
			} else if j == 0 {
				dtw_matrix[i][j] = cost + dtw_matrix[i-1][j]
			} else {
				min_val := dtw_matrix[i-1][j]
				if dtw_matrix[i][j-1] < min_val {
					min_val = dtw_matrix[i][j-1]
				}
				if dtw_matrix[i-1][j-1] < min_val {
					min_val = dtw_matrix[i-1][j-1]
				}
				dtw_matrix[i][j] = cost + min_val
			}
		}
	}

	normalized_distance := dtw_matrix[audio_len-1][video_len-1] / float32(audio_len+video_len)
	confidence := 1.0 / (1.0 + normalized_distance)

	best_offset := float64(0)
	if audio_len > 0 && video_len > 0 {
		best_offset = float64((audio_len - video_len) * 1000 / video_len)
	}

	result := &sync_result{
		is_synchronized:   confidence > ava.confidence_threshold,
		time_offset_ms:    best_offset,
		confidence_score:  confidence,
		method_used:       SYNC_DTW,
		sync_status:       "completed",
		sync_time:         time.Now(),
	}

	ava.mu.Lock()
	ava.latest_sync_results[pair_id] = result
	ava.stats.num_sync_attempts++
	if result.is_synchronized {
		ava.stats.successful_syncs++
	}
	ava.mu.Unlock()

	return result, nil
}

func (audio_video_aligner* ava) detect_sync_points(pair_id string) ([]temporal_alignment, error) {
	ava.mu.Lock()
	pair, exists := ava.pair_cache[pair_id]
	ava.mu.Unlock()

	if !exists {
		return nil, fmt.Errorf("pair %s not found", pair_id)
	}

	alignment_points := make([]temporal_alignment, 0)

	for i := 0; i < len(pair.video.frames) && i < 50; i++ {
		video_frame := pair.video.frames[i]
		audio_idx := (i * len(pair.audio.samples)) / len(pair.video.frames)

		if audio_idx < len(pair.audio.samples) {
			alignment := temporal_alignment{
				audio_frame_index: int32(audio_idx),
				video_frame_index: video_frame.frame_index,
				audio_timestamp:   float64(audio_idx) / float64(pair.audio.metadata.sample_rate),
				video_timestamp:   video_frame.timestamp,
				confidence:        video_frame.motion_score,
				is_keypoint:       video_frame.is_keyframe,
			}

			alignment_points = append(alignment_points, alignment)
		}
	}

	ava.mu.Lock()
	ava.alignments[pair_id] = alignment_points
	ava.mu.Unlock()

	return alignment_points, nil
}

func (audio_video_aligner* ava) auto_sync(pair_id string) (*sync_result, error) {
	methods := []sync_method{
		SYNC_CROSS_CORRELATION,
		SYNC_DTW,
		SYNC_TEMPORAL_ALIGNMENT,
	}

	best_result := (*sync_result)(nil)
	best_confidence := float32(0)

	for _, method := range methods {
		var result *sync_result
		var err error

		switch method {
		case SYNC_CROSS_CORRELATION:
			result, err = ava.sync_cross_correlation(pair_id)
		case SYNC_DTW:
			result, err = ava.sync_dtw(pair_id)
		case SYNC_TEMPORAL_ALIGNMENT:
			result, err = ava.sync_cross_correlation(pair_id)
		default:
			result, err = ava.sync_cross_correlation(pair_id)
		}

		if err == nil && result != nil && result.confidence_score > best_confidence {
			best_result = result
			best_confidence = result.confidence_score
		}
	}

	if best_result == nil {
		return nil, fmt.Errorf("auto sync failed for pair %s", pair_id)
	}

	return best_result, nil
}

func (audio_video_aligner* ava) manually_align(pair_id string, time_offset_ms float64) error {
	ava.mu.Lock()
	pair, exists := ava.pair_cache[pair_id]
	if !exists {
		ava.mu.Unlock()
		return fmt.Errorf("pair %s not found", pair_id)
	}

	pair.manually_aligned = true
	result := &sync_result{
		is_synchronized:   true,
		time_offset_ms:    time_offset_ms,
		confidence_score:  1.0,
		method_used:       SYNC_CROSS_CORRELATION,
		sync_status:       "manual",
		sync_time:         time.Now(),
	}

	ava.latest_sync_results[pair_id] = result
	ava.mu.Unlock()

	return nil
}

func (audio_video_aligner* ava) get_sync_result(pair_id string) (*sync_result, error) {
	ava.mu.Lock()
	defer ava.mu.Unlock()

	result, exists := ava.latest_sync_results[pair_id]
	if !exists {
		return nil, fmt.Errorf("no sync result for pair %s", pair_id)
	}

	return result, nil
}

func (audio_video_aligner* ava) get_alignment_points(pair_id string) []temporal_alignment {
	ava.mu.Lock()
	defer ava.mu.Unlock()

	points, _ := ava.alignments[pair_id]
	return points
}

func (audio_video_aligner* ava) get_aligner_stats() *sync_statistics {
	ava.mu.Lock()
	defer ava.mu.Unlock()

	return ava.stats
}

func (audio_video_aligner* ava) set_confidence_threshold(threshold float32) error {
	if threshold < 0 || threshold > 1 {
		return fmt.Errorf("threshold must be between 0 and 1")
	}

	ava.mu.Lock()
	defer ava.mu.Unlock()

	ava.confidence_threshold = threshold

	return nil
}

func (audio_video_aligner* ava) set_sync_method(method sync_method) {
	ava.mu.Lock()
	defer ava.mu.Unlock()

	ava.default_method = method
}

func (audio_video_aligner* ava) clear_pair(pair_id string) error {
	ava.mu.Lock()
	defer ava.mu.Unlock()

	delete(ava.pair_cache, pair_id)
	delete(ava.latest_sync_results, pair_id)
	delete(ava.alignments, pair_id)

	return nil
}
