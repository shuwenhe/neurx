package reasoning
import "sync"
import "time"
	RELEVANCE = 0
	COMPLETENESS = 1
	LOGICAL_CONSISTENCY = 2
	CLARITY = 3
	CONFIDENCE = 4
	NOVELTY = 5
}

struct evaluation_score {
	evaluation_criteria criteria
	float32             score
	string              feedback
	int64               evaluated_at
}

struct thought_quality_metrics {
	float32     relevance_score
	float32     completeness_score
	float32     consistency_score
	float32     clarity_score
	float32     confidence_score
	float32     novelty_score
	float32     overall_score
}

struct thought_evaluation_result {
	string                      thought_id
	thought_quality_metrics     metrics
	evaluation_score[]       detailed_scores
	bool                        is_valid
	bool                        should_prune
	string                      recommendation
	int64                       evaluation_time
}

struct thought_evaluator {
	map[string]thought_quality_metrics metrics_cache
	map[string]thought_evaluation_result results_cache
	float32                     relevance_weight
	float32                     completeness_weight
	float32                     consistency_weight
	float32                     clarity_weight
	float32                     confidence_weight
	float32                     novelty_weight
	float32                     pruning_threshold
	float32                     valid_threshold
	string[]                 evaluated_thoughts
	map[string]int32            evaluation_counts
	sync.Mutex                  mu
}

func create_thought_evaluator() thought_evaluator {
	return thought_evaluator{
		metrics_cache:         make(map[string]thought_quality_metrics),
		results_cache:         make(map[string]thought_evaluation_result),
		relevance_weight:      0.25,
		completeness_weight:   0.20,
		consistency_weight:    0.20,
		clarity_weight:        0.15,
		confidence_weight:     0.15,
		novelty_weight:        0.05,
		pruning_threshold:     0.3,
		valid_threshold:       0.5,
		evaluated_thoughts:    make(string[], 0, 1000),
		evaluation_counts:     make(map[string]int32),
		mu:                    sync.Mutex{},
	}
}

func (thought_evaluator* e) evaluate_thought(
	thought_id string,
	thought_content string,
	context_text string,
	previous_thoughts string[],
) thought_evaluation_result {
	e.mu.Lock()
	defer e.mu.Unlock()
	relevance := e.calculate_relevance(thought_content, context_text)
	completeness := e.calculate_completeness(thought_content)
	consistency := e.calculate_consistency(
		thought_content,
		previous_thoughts,
	)
	clarity := e.calculate_clarity(thought_content)
	confidence := e.calculate_confidence(thought_content)
	novelty := e.calculate_novelty(thought_content, previous_thoughts)
	overall := (relevance * e.relevance_weight) +
	           (completeness * e.completeness_weight) +
	           (consistency * e.consistency_weight) +
	           (clarity * e.clarity_weight) +
	           (confidence * e.confidence_weight) +
	           (novelty * e.novelty_weight)
	metrics := thought_quality_metrics{
		relevance_score:   relevance,
		completeness_score: completeness,
		consistency_score:  consistency,
		clarity_score:     clarity,
		confidence_score:  confidence,
		novelty_score:     novelty,
		overall_score:     overall,
	}
	should_prune := overall < e.pruning_threshold
	is_valid := overall >= e.valid_threshold
	recommendation := "keep"
	if should_prune {
		recommendation = "prune"
	} else if overall > 0.8 {
		recommendation = "prioritize"
	}
	result := thought_evaluation_result{
		thought_id:      thought_id,
		metrics:         metrics,
		detailed_scores: make(evaluation_score[], 0, 6),
		is_valid:        is_valid,
		should_prune:    should_prune,
		recommendation:  recommendation,
		evaluation_time: time.Now().UnixNano(),
	}
	result.detailed_scores = append(result.detailed_scores, evaluation_score{
		criteria:   RELEVANCE,
		score:      relevance,
		feedback:   "Relevance to context",
		evaluated_at: time.Now().UnixNano(),
	})
	result.detailed_scores = append(result.detailed_scores, evaluation_score{
		criteria:   COMPLETENESS,
		score:      completeness,
		feedback:   "Coverage of problem",
		evaluated_at: time.Now().UnixNano(),
	})
	result.detailed_scores = append(result.detailed_scores, evaluation_score{
		criteria:   LOGICAL_CONSISTENCY,
		score:      consistency,
		feedback:   "Logical alignment",
		evaluated_at: time.Now().UnixNano(),
	})
	result.detailed_scores = append(result.detailed_scores, evaluation_score{
		criteria:   CLARITY,
		score:      clarity,
		feedback:   "Expression clarity",
		evaluated_at: time.Now().UnixNano(),
	})
	result.detailed_scores = append(result.detailed_scores, evaluation_score{
		criteria:   CONFIDENCE,
		score:      confidence,
		feedback:   "Confidence level",
		evaluated_at: time.Now().UnixNano(),
	})
	result.detailed_scores = append(result.detailed_scores, evaluation_score{
		criteria:   NOVELTY,
		score:      novelty,
		feedback:   "Novelty of thought",
		evaluated_at: time.Now().UnixNano(),
	})
	e.metrics_cache[thought_id] = metrics
	e.results_cache[thought_id] = result
	e.evaluated_thoughts = append(e.evaluated_thoughts, thought_id)
	if _, exists := e.evaluation_counts[thought_id]; !exists {
		e.evaluation_counts[thought_id] = 0
	}
	e.evaluation_counts[thought_id]++
	return result
}

func (thought_evaluator* e) calculate_relevance(
	thought string,
	context string,
) float32 {
	if len(thought) == 0 || len(context) == 0 {
		return 0.0
	}
	score := float32(0.0)
	context_words := e.tokenize(context)
	thought_words := e.tokenize(thought)
	matches := int32(0)
	for tw := range thought_words {
		for cw := range context_words {
			if tw == cw {
				matches++
				break
			}
		}
	}
	if int32(len(context_words)) > 0 {
		score = float32(matches) / float32(len(context_words))
	}
	if score > 1.0 {
		score = 1.0
	}
	return score
}

func (thought_evaluator* e) calculate_completeness(thought string) float32 {
	if len(thought) == 0 {
		return 0.0
	}
	length := float32(len(thought))
	if length < 20.0 {
		return 0.2
	} else if length < 100.0 {
		return 0.5
	} else if length < 500.0 {
		return 0.8
	}
	return 1.0
}

func (thought_evaluator* e) calculate_consistency(
	thought string,
	previous_thoughts string[],
) float32 {
	if int32(len(previous_thoughts)) == 0 {
		return 0.8
	}
	score := float32(1.0)
	penalties := float32(0)
	thought_lower := e.to_lower(thought)
	contradiction_keywords := string[]{
		"contradicts",
		"conflicts",
		"opposite",
		"wrong",
		"incorrect",
	}
	for keyword := range contradiction_keywords {
		if e.contains_substring(thought_lower, keyword) {
			penalties += 0.2
		}
	}
	score = score - penalties
	if score < 0.0 {
		score = 0.0
	}
	return score
}

func (thought_evaluator* e) calculate_clarity(thought string) float32 {
	if len(thought) == 0 {
		return 0.0
	}
	score := float32(0.7)
	length := int32(len(thought))
	if length > 1000 {
		score -= 0.2
	}
	complexity_factor := e.count_substring(thought, ",") +
	                     e.count_substring(thought, ";")
	if complexity_factor > 10 {
		score -= 0.15
	}
	if score < 0.0 {
		score = 0.0
	}
	if score > 1.0 {
		score = 1.0
	}
	return score
}

func (thought_evaluator* e) calculate_confidence(thought string) float32 {
	if len(thought) == 0 {
		return 0.0
	}
	confidence_keywords := map[string]float32{
		"certain":     1.0,
		"definitely":  0.95,
		"clearly":     0.9,
		"probably":    0.7,
		"likely":      0.75,
		"possibly":    0.5,
		"maybe":       0.4,
		"perhaps":     0.45,
		"unsure":      0.2,
		"uncertain":   0.15,
	}
	thought_lower := e.to_lower(thought)
	max_conf := float32(0.5)
	for keyword := range confidence_keywords {
		if e.contains_substring(thought_lower, keyword) {
			if confidence_keywords[keyword] > max_conf {
				max_conf = confidence_keywords[keyword]
			}
		}
	}
	return max_conf
}

func (thought_evaluator* e) calculate_novelty(
	thought string,
	previous_thoughts string[],
) float32 {
	if int32(len(previous_thoughts)) == 0 {
		return 1.0
	}
	novelty_score := float32(1.0)
	for prev := range previous_thoughts {
		similarity := e.calculate_text_similarity(thought, prev)
		if similarity > 0.8 {
			novelty_score -= 0.3
		} else if similarity > 0.6 {
			novelty_score -= 0.1
		}
	}
	if novelty_score < 0.0 {
		novelty_score = 0.0
	}
	return novelty_score
}

func (thought_evaluator* e) calculate_text_similarity(
	text1 string,
	text2 string,
) float32 {
	if len(text1) == 0 && len(text2) == 0 {
		return 1.0
	}
	if len(text1) == 0 || len(text2) == 0 {
		return 0.0
	}
	common := int32(0)
	total := int32(len(text1)) + int32(len(text2))
	for i := int32(0); i < int32(len(text1)); i++ {
		for j := int32(0); j < int32(len(text2)); j++ {
			if text1[i] == text2[j] {
				common++
				break
			}
		}
	}
	return float32(common*2) / float32(total)
}

func (thought_evaluator* e) tokenize(text string) []string {
	tokens := make(string[], 0)
	current_token := ""
	for i := int32(0); i < int32(len(text)); i++ {
		if text[i] == ' ' || text[i] == '\n' || text[i] == '\t' {
			if len(current_token) > 0 {
				tokens = append(tokens, current_token)
				current_token = ""
			}
		} else {
			current_token = current_token + string(text[i])
		}
	}
	if len(current_token) > 0 {
		tokens = append(tokens, current_token)
	}
	return tokens
}

func (thought_evaluator* e) to_lower(text string) string {
	result := ""
	for i := int32(0); i < int32(len(text)); i++ {
		c := text[i]
		if c >= 'A' && c <= 'Z' {
			result = result + string(c+32)
		} else {
			result = result + string(c)
		}
	}
	return result
}

func (thought_evaluator* e) contains_substring(
	text string,
	substr string,
) bool {
	if len(substr) > len(text) {
		return false
	}
	for i := int32(0); i <= int32(len(text))-int32(len(substr)); i++ {
		match := true
		for j := int32(0); j < int32(len(substr)); j++ {
			if text[i+j] != substr[j] {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}
	return false
}

func (thought_evaluator* e) count_substring(
	text string,
	substr string,
) int32 {
	if len(substr) == 0 {
		return 0
	}
	count := int32(0)
	for i := int32(0); i <= int32(len(text))-int32(len(substr)); i++ {
		match := true
		for j := int32(0); j < int32(len(substr)); j++ {
			if text[i+j] != substr[j] {
				match = false
				break
			}
		}
		if match {
			count++
		}
	}
	return count
}

func (thought_evaluator* e) get_cached_metrics(
	thought_id string,
) (thought_quality_metrics, bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	metrics, exists := e.metrics_cache[thought_id]
	return metrics, exists
}

func (thought_evaluator* e) get_evaluation_result(
	thought_id string,
) (thought_evaluation_result, bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	result, exists := e.results_cache[thought_id]
	return result, exists
}

func (thought_evaluator* e) set_thresholds(
	pruning_threshold float32,
	valid_threshold float32,
) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if pruning_threshold >= 0.0 && pruning_threshold <= 1.0 {
		e.pruning_threshold = pruning_threshold
	}
	if valid_threshold >= 0.0 && valid_threshold <= 1.0 {
		e.valid_threshold = valid_threshold
	}
}

func (thought_evaluator* e) get_statistics() map[string]interface{} {
	e.mu.Lock()
	defer e.mu.Unlock()
	stats := make(map[string]interface{})
	stats["total_evaluated"] = int32(len(e.evaluated_thoughts))
	stats["cached_results"] = int32(len(e.results_cache))
	total_score := float32(0.0)
	for _, result := range e.results_cache {
		total_score += result.metrics.overall_score
	}
	if int32(len(e.results_cache)) > 0 {
		avg_score := total_score / float32(len(e.results_cache))
		stats["average_score"] = avg_score
	}
	return stats
}

func (thought_evaluator* e) clear_cache() {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.metrics_cache = make(map[string]thought_quality_metrics)
	e.results_cache = make(map[string]thought_evaluation_result)
	e.evaluated_thoughts = make(string[], 0, 1000)
	e.evaluation_counts = make(map[string]int32)
}
