package sampling

import "math"

struct embedding_cache {
	token_embeddings map[int32]vec[float32]
	model_embeddings vec[vec[float32]]
}

struct contrastive_search_state {
	alpha float32
	k int32
	degenerate_to_greedy bool
	embedding_cache* embedding_cache
}

func create_contrastive_search_state(float32 alpha, int32 k, bool degenerate) contrastive_search_state* {
	return &contrastive_search_state{
		alpha: alpha,
		k: k,
		degenerate_to_greedy: degenerate,
		embedding_cache: &embedding_cache{
			token_embeddings: make(map[int32]vec[float32]),
			model_embeddings: make(vec[vec[float32]]),
		},
	}
}

func cosine_similarity(vec[float32] vec_a, vec[float32] vec_b) float32 {
	if len(vec_a) == 0 || len(vec_b) == 0 {
		return 0.0
	}
	
	dot_product := 0.0
	norm_a := 0.0
	norm_b := 0.0
	
	for i := 0; i < len(vec_a); i = i + 1 {
		dot_product = dot_product + vec_a[i] * vec_b[i]
		norm_a = norm_a + vec_a[i] * vec_a[i]
		norm_b = norm_b + vec_b[i] * vec_b[i]
	}
	
	if norm_a <= 0.0 || norm_b <= 0.0 {
		return 0.0
	}
	
	norm_a = math.sqrt(norm_a)
	norm_b = math.sqrt(norm_b)
	
	return dot_product / (norm_a * norm_b)
}

func (c* contrastive_search_state) compute_model_diversity(vec[float32] model_embedding, vec[vec[float32]] generated_embeddings) float32 {
	if len(generated_embeddings) == 0 {
		return 0.0
	}
	
	max_similarity := -2.0
	
	for i := 0; i < len(generated_embeddings); i = i + 1 {
		similarity := cosine_similarity(model_embedding, generated_embeddings[i])
		
		if similarity > max_similarity {
			max_similarity = similarity
		}
	}
	
	if max_similarity < -1.0 {
		return 1.0
	}
	
	return 1.0 - max_similarity
}

func (c* contrastive_search_state) compute_model_confidence(vec[float32] logits, int32 candidate_token) float32 {
	if candidate_token < 0 || candidate_token >= int32(len(logits)) {
		return 0.0
	}
	
	max_logit := logits[0]
	for i := 1; i < len(logits); i = i + 1 {
		if logits[i] > max_logit {
			max_logit = logits[i]
		}
	}
	
	exp_logits := make(vec[float32])
	sum := 0.0
	
	for i := 0; i < len(logits); i = i + 1 {
		exp_val := math.exp(logits[i] - max_logit)
		sum = sum + exp_val
		exp_logits = append(exp_logits, exp_val)
	}
	
	if sum > 0.0 {
		return exp_logits[candidate_token] / sum
	}
	
	return 0.0
}

func (c* contrastive_search_state) select_token(vec[float32] logits, vec[vec[float32]] generated_embeddings, vec[vec[float32]] model_embeddings) int32 {
	if len(model_embeddings) == 0 || len(logits) == 0 {
		max_idx := 0
		max_val := logits[0]
		for i := 1; i < len(logits); i = i + 1 {
			if logits[i] > max_val {
				max_val = logits[i]
				max_idx = i
			}
		}
		return int32(max_idx)
	}
	
	k := c.k
	if k > len(logits) {
		k = int32(len(logits))
	}
	
	top_k_tokens := make(vec[int32])
	top_k_scores := make(vec[float32])
	
	for i := 0; i < len(logits); i = i + 1 {
		score := logits[i]
		
		inserted := false
		for j := 0; j < len(top_k_scores); j = j + 1 {
			if score > top_k_scores[j] {
				top_k_tokens = append(make(vec[int32]), top_k_tokens[:j]...)
				top_k_tokens = append(top_k_tokens, int32(i))
				top_k_tokens = append(top_k_tokens, top_k_tokens[j+1:]...)
				
				top_k_scores = append(make(vec[float32]), top_k_scores[:j]...)
				top_k_scores = append(top_k_scores, score)
				top_k_scores = append(top_k_scores, top_k_scores[j+1:]...)
				
				inserted = true
				break
			}
		}
		
		if !inserted && len(top_k_tokens) < int32(k) {
			top_k_tokens = append(top_k_tokens, int32(i))
			top_k_scores = append(top_k_scores, score)
		}
		
		if len(top_k_tokens) > int32(k) {
			top_k_tokens = top_k_tokens[:k]
			top_k_scores = top_k_scores[:k]
		}
	}
	
	best_token := int32(0)
	best_score := -1e9
	
	for i := 0; i < len(top_k_tokens); i = i + 1 {
		token_id := top_k_tokens[i]
		
		confidence := c.compute_model_confidence(logits, token_id)
		
		diversity := 0.0
		if token_id >= 0 && token_id < int32(len(model_embeddings)) {
			diversity = c.compute_model_diversity(model_embeddings[token_id], generated_embeddings)
		}
		
		contrastive_score := c.alpha * confidence + (1.0 - c.alpha) * diversity
		
		if contrastive_score > best_score {
			best_score = contrastive_score
			best_token = token_id
		}
	}
	
	return best_token
}

func (c* contrastive_search_state) cache_embeddings(int32 token_id, vec[float32] embedding) {
	if c.embedding_cache != nil {
		c.embedding_cache.token_embeddings[token_id] = embedding
	}
}

func contrastive_decoding_step(vec[float32] logits, vec[vec[float32]] context_embeddings, float32 alpha, int32 k) int32 {
	if alpha < 0.0 {
		alpha = 0.0
	}
	if alpha > 1.0 {
		alpha = 1.0
	}
	
	if len(logits) == 0 {
		return 0
	}
	
	if k <= 0 {
		k = 4
	}
	
	if k > int32(len(logits)) {
		k = int32(len(logits))
	}
	
	top_k_indices := make(vec[int32])
	top_k_vals := make(vec[float32])
	
	for i := 0; i < len(logits); i = i + 1 {
		val := logits[i]
		
		inserted := false
		for j := 0; j < len(top_k_vals); j = j + 1 {
			if val > top_k_vals[j] {
				top_k_vals = append(make(vec[float32]), top_k_vals[:j]...)
				top_k_vals = append(top_k_vals, val)
				top_k_vals = append(top_k_vals, top_k_vals[j+1:]...)
				
				top_k_indices = append(make(vec[int32]), top_k_indices[:j]...)
				top_k_indices = append(top_k_indices, int32(i))
				top_k_indices = append(top_k_indices, top_k_indices[j+1:]...)
				
				inserted = true
				break
			}
		}
		
		if !inserted && len(top_k_indices) < int32(k) {
			top_k_vals = append(top_k_vals, val)
			top_k_indices = append(top_k_indices, int32(i))
		}
		
		if len(top_k_indices) > int32(k) {
			top_k_indices = top_k_indices[:k]
			top_k_vals = top_k_vals[:k]
		}
	}
	
	best_idx := int32(0)
	best_score := -1e9
	
	for i := 0; i < len(top_k_indices); i = i + 1 {
		token_idx := top_k_indices[i]
		
		model_confidence := 0.0
		if len(logits) > 0 {
			max_logit := logits[0]
			for j := 1; j < len(logits); j = j + 1 {
				if logits[j] > max_logit {
					max_logit = logits[j]
				}
			}
			
			model_confidence = math.exp(logits[token_idx] - max_logit)
		}
		
		diversity_score := 1.0
		if len(context_embeddings) > 0 && token_idx < int32(len(context_embeddings)) {
			max_sim := -2.0
			for j := 0; j < len(context_embeddings); j = j + 1 {
				sim := cosine_similarity(context_embeddings[token_idx], context_embeddings[j])
				if sim > max_sim {
					max_sim = sim
				}
			}
			diversity_score = 1.0 - (max_sim + 1.0) / 2.0
		}
		
		contrastive_score := alpha * model_confidence + (1.0 - alpha) * diversity_score
		
		if contrastive_score > best_score {
			best_score = contrastive_score
			best_idx = token_idx
		}
	}
	
	return best_idx
}
