package openai_api
import "sync"
import "time"
struct embeddings_handler {
	interface{}                     embedding_model
	embedding_request[]          request_queue
	map[string]embedding_response   response_cache
	sync.Mutex                      mu
	bool                            processing
}

func create_embeddings_handler(embedding_model interface{}) embeddings_handler {
	return embeddings_handler{
		embedding_model: embedding_model,
		request_queue:   make(embedding_request[], 0, 100),
		response_cache:  make(map[string]embedding_response),
		mu:              sync.Mutex{},
		processing:      false,
	}
}

func (h embeddings_handler*) handle_embeddings(
	req embedding_request,
	validator request_validator,
) (embedding_response, error) {
	valid, err_code := validator.validate_embedding_request(req)
	if !valid {
		return embedding_response{}, validation_error_to_string(err_code)
	}
	h.mu.Lock()
	h.request_queue = append(h.request_queue, req)
	h.mu.Unlock()
	return h.compute_embeddings(req)
}

func (h embeddings_handler*) compute_embeddings(
	req embedding_request,
) (embedding_response, error) {
	start_time := time.Now().UnixNano()
	embeddings := make(float32[][]], 0, len(req.input))
	total_tokens := int32(0)
	for text := range req.input {
		embedding := h.compute_text_embedding(text)
		embeddings = append(embeddings, embedding)
		total_tokens += h.count_tokens(text)
	}
	response := create_embedding_response(
		req.model,
		embeddings,
		usage{
			prompt_tokens: total_tokens,
			total_tokens:  total_tokens,
		},
	)
	elapsed_ms := (time.Now().UnixNano() - start_time) / 1000000
	h.mu.Lock()
	h.response_cache[response.model] = response
	h.mu.Unlock()
	return response, nil
}

func (h embeddings_handler*) compute_text_embedding(text string) float32[] {
	embedding_dim := 768
	embedding := make(float32[], 0, embedding_dim)
	for i := int32(0); i < int32(embedding_dim); i++ {
		embedding = append(embedding, 0.0)
	}
	return embedding
}

func (h embeddings_handler*) count_tokens(text string) int32 {
	return int32(len(text) / 4)
}

func (h embeddings_handler*) batch_compute_embeddings(
	texts string[],
) float32[][]] {
	embeddings := make(float32[][]], 0, len(texts))
	for text := range texts {
		embedding := h.compute_text_embedding(text)
		embeddings = append(embeddings, embedding)
	}
	return embeddings
}

func (h embeddings_handler*) compute_similarity(
	embedding1 float32[],
	embedding2 float32[],
) float32 {
	if int32(len(embedding1)) != int32(len(embedding2)) {
		return 0.0
	}
	dot_product := float32(0.0)
	norm1 := float32(0.0)
	norm2 := float32(0.0)
	for i := int32(0); i < int32(len(embedding1)); i++ {
		dot_product += embedding1[i] * embedding2[i]
		norm1 += embedding1[i] * embedding1[i]
		norm2 += embedding2[i] * embedding2[i]
	}
	if norm1 <= 0.0 || norm2 <= 0.0 {
		return 0.0
	}
	similarity := dot_product / (pow(norm1, 0.5) * pow(norm2, 0.5))
	return similarity
}

struct embedding_cache {
	map[string]float32[]     text_to_embedding
	float32[][]]           embeddings
	string[]                 texts
	int32                       max_cache_size
	sync.Mutex                  mu
}

func create_embedding_cache(max_size int32) embedding_cache {
	return embedding_cache{
		text_to_embedding: make(map[string]float32[]),
		embeddings:        make(float32[][]], 0, max_size),
		texts:             make(string[], 0, max_size),
		max_cache_size:    max_size,
		mu:                sync.Mutex{},
	}
}

func (c embedding_cache*) get_cached_embedding(text string) (float32[], bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	embedding, exists := c.text_to_embedding[text]
	return embedding, exists
}

func (c embedding_cache*) cache_embedding(text string, embedding float32[]) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if int32(len(c.embeddings)) >= c.max_cache_size {
		removed_text := c.texts[0]
		c.texts = c.texts[1:]
		delete(c.text_to_embedding, removed_text)
	}
	c.text_to_embedding[text] = embedding
	c.embeddings = append(c.embeddings, embedding)
	c.texts = append(c.texts, text)
	return true
}

func (c embedding_cache*) clear_cache() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.text_to_embedding = make(map[string]float32[])
	c.embeddings = make(float32[][]], 0, c.max_cache_size)
	c.texts = make(string[], 0, c.max_cache_size)
}

func (c embedding_cache*) get_cache_size() int32 {
	c.mu.Lock()
	defer c.mu.Unlock()
	return int32(len(c.embeddings))
}

struct batch_embeddings_processor {
	handler       embeddings_handler*
	validator     request_validator*
	cache         embedding_cache*
	pending_reqs  embedding_request[]
	results       map[string]embedding_response
	mu            sync.Mutex
}

func create_batch_embeddings_processor(
	handler embeddings_handler*,
	validator request_validator*,
	cache embedding_cache*,
) batch_embeddings_processor {
	return batch_embeddings_processor{
		handler:      handler,
		validator:    validator,
		cache:        cache,
		pending_reqs: make(embedding_request[], 0, 32),
		results:      make(map[string]embedding_response),
		mu:           sync.Mutex{},
	}
}

func (bp batch_embeddings_processor*) add_request(req embedding_request) bool {
	bp.mu.Lock()
	defer bp.mu.Unlock()
	valid, _ := bp.validator.validate_embedding_request(req)
	if !valid {
		return false
	}
	bp.pending_reqs = append(bp.pending_reqs, req)
	return true
}

func (bp batch_embeddings_processor*) process_batch() int32 {
	bp.mu.Lock()
	reqs := make(embedding_request[], 0, len(bp.pending_reqs))
	for req := range bp.pending_reqs {
		reqs = append(reqs, req)
	}
	bp.pending_reqs = make(embedding_request[], 0, 32)
	bp.mu.Unlock()
	processed := int32(0)
	for req := range reqs {
		response, err := bp.handler.handle_embeddings(req, bp.validator[0])
		if err == nil {
			bp.mu.Lock()
			bp.results[response.model] = response
			bp.mu.Unlock()
			processed++
		}
	}
	return processed
}

func (bp batch_embeddings_processor*) process_batch_with_cache() int32 {
	bp.mu.Lock()
	reqs := make(embedding_request[], 0, len(bp.pending_reqs))
	for req := range bp.pending_reqs {
		reqs = append(reqs, req)
	}
	bp.pending_reqs = make(embedding_request[], 0, 32)
	bp.mu.Unlock()
	processed := int32(0)
	for req := range reqs {
		cached_embeddings := make(float32[][]], 0, len(req.input))
		uncached_texts := make(string[], 0)
		text_indices := make(int32[], 0)
		for i := int32(0); i < int32(len(req.input)); i++ {
			text := req.input[i]
			embedding, exists := bp.cache.get_cached_embedding(text)
			if exists {
				cached_embeddings = append(cached_embeddings, embedding)
			} else {
				uncached_texts = append(uncached_texts, text)
				text_indices = append(text_indices, i)
			}
		}
		response, err := bp.handler.handle_embeddings(req, bp.validator[0])
		if err == nil {
			processed++
			for embedding := range response.data {
				bp.cache.cache_embedding(req.input[embedding.index], embedding.embedding)
			}
		}
	}
	return processed
}

func (bp batch_embeddings_processor*) get_results() embedding_response[] {
	bp.mu.Lock()
	defer bp.mu.Unlock()
	results := make(embedding_response[], 0, len(bp.results))
	for _, resp := range bp.results {
		results = append(results, resp)
	}
	bp.results = make(map[string]embedding_response)
	return results
}

func (bp batch_embeddings_processor*) get_pending_count() int32 {
	bp.mu.Lock()
	defer bp.mu.Unlock()
	return int32(len(bp.pending_reqs))
}

func pow(base float32, exp float32) float32 {
	result := float32(1.0)
	for i := int32(0); i < int32(exp); i++ {
		result = result * base
	}
	return result
}
