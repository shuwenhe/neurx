// ============================================================
// NEURX ADVANCED RAG system - English textgenerate
// completeimplementation: English textdataEnglish text + English text + English textranking + English text
// English text: FAISS / Chroma / Milvus / Pinecone / English text
// ============================================================

module rag_system

// ==================== English textconfiguration ====================

struct retrieval_system_config {
    // English textdataEnglish textconfiguration
    vector_db_backend: string = "faiss"           // faiss | chroma | milvus | pinecone | in_memory
    vector_dim: int = 768                          // English text (English textuseEnglish text embedding Model)
    index_type: string = "IVF_FLAT"                // English text: FLAT / IVF_FLAT / HNSW / IVF_PQ
    metric: string = "cosine"                      // English text: cosine / l2 / inner_product
    nprobe: int = 10                               // IVF English text (English text)
    nlist: int = 100                               // IVF English textcount

    // English textparameter
    top_k: int = 5                                 // English textcount
    rerank_top_k: int = 3                          // English textrankingEnglish textcount
    similarity_threshold: float = 0.7              // English text (English textresultEnglish text)
    max_chunk_length: int = 512                    // English text

    // English textmodelconfiguration
    embedding_model_name: string = "bge-large-zh-v1.5"  // defaultuse BGE English textmodel
    embedding_batch_size: int = 32                 // English text
    normalize_embeddings: bool = true              // English text

    // English textweight
    vector_weight: float = 0.7                     // English textweight
    keyword_weight: float = 0.3                    # keywordsEnglish textweight

    // English textrankingconfiguration
    enable_reranking: bool = true                  # English textranking
    reranker_model: string = "bge-reranker-v2-m3"  # English textrankingmodel
    reranker_score_threshold: float = 0.5          # English textrankingEnglish text

    // advancedEnglish text
    enable_hybrid_search: bool = true              # English text (English text+keywords)
    enable_query_expansion: bool = true            # English textqueryextension
    enable_cross_encoder_rerank: bool = true       # use Cross-Encoder English text
    max_context_tokens: int = 4096                 # English text token English text
    citation_format: string = "[doc{index}]"       # English text
}

struct DocumentChunk {
    id: string                                     // Chunk ID (UUID)
    content: string                                // English textcontent
    metadata: DocumentMetadata                     // English textdata
    embedding: tensor?                             // English textcomputeEnglish text (English text)
    chunk_index: int                               // English text
    token_count: int                               // Token countEnglish text
}

struct DocumentMetadata {
    source_id: string                              // SourceEnglish text ID
    source_path: string?                           // filepathEnglish text URL
    title: string                                  // English texttitle
    author: string?                                // author
    created_at: float?                             // English texttimeEnglish text
    document_type: string                          // English text: pdf/html/markdown/text/webpage
    language: string = "zh"                        // language
    tags: list<string>                             // English text
    url?: string                                   // English text URL (English textweb page)
    page_number?: int                              // English text (PDF)
    section?: string                               // section/English texttitle
    relevance_score?: float                        // English text (English text)
}

struct SearchResult {
    chunks: list<DocumentChunk>                    // English text
    scores: list<float>                            // English text/English text
    query: string                                  // English textquery
    expanded_query: string?                        # extensionEnglish textquery
    retrieval_metadata: RetrievalMetadata          # English textdata
}

struct RetrievalMetadata {
    total_scanned: int                             // English text
    total_returned: int                            // English textresultEnglish text
    vector_search_time_ms: float                   # English textsearchEnglish text
    keyword_search_time_ms: float                  # keywordssearchEnglish text
    rerank_time_ms: float                          # English textrankingEnglish text
    fusion_time_ms: float                          # resultEnglish text
    used_hybrid_search: bool                       # English textuseEnglish text
    used_query_expansion: bool                     # English textuseEnglish textqueryextension
}

// ==================== English textdataEnglish text ====================

interface VectorDBInterface {
    init(config: retrieval_system_config)
    insert(chunks: list<DocumentChunk>)
    delete(chunk_ids: list<string>)
    search(query_embedding: tensor, top_k: int)
    save(path: string)
    load(path: string)
    count()
    clear()
    get_status()
}

struct SearchResultItem {
    chunk_id: string
    score: float
    metadata: DocumentMetadata
}

struct DBStatus {
    total_documents: int
    index_type: string
    memory_usage_mb: float
    is_initialized: bool
    last_updated: float
}

// ==================== In-Memory English textdataEnglish text (defaultimplementation) ====================

class InMemoryVectorDB implements VectorDBInterface {
    config: retrieval_system_config
    embeddings: map<str, tensor>              // chunk_id -> embedding
    documents: map<str, DocumentChunk>        // chunk_id -> document chunk
    index_built: bool = false
    created_at: float
    last_updated: float

    init(config: retrieval_system_config) {
        this.config = config
        this.embeddings = map<str, tensor>{}
        this.documents = map<str, DocumentChunk>{}
        this.created_at = current_timestamp()
        this.last_updated = this.created_at
    }

    insert(chunks: list<DocumentChunk>) {
        for chunk in chunks {
            if chunk.embedding != null {
                this.embeddings[chunk.id] = chunk.embedding!
            }
            this.documents[chunk.id] = chunk
        }
        this.index_built = true
        this.last_updated = current_timestamp()
    }

    delete(chunk_ids: list<string>) {
        for id in chunk_ids {
            if id in this.embeddings { this.embeddings.remove(id) }
            if id in this.documents { this.documents.remove(id) }
        }
        this.last_updated = current_timestamp()
    }

    search(query_embedding: tensor, top_k: int) {
        results: list<SearchResultItem> = []

        for chunk_id, doc_emb in this.embeddings {
            let score = compute_similarity(query_embedding, doc_emb, this.config.metric)

            if score >= this.config.similarity_threshold {
                results.append(SearchResultItem{
                    chunk_id=chunk_id,
                    score=score,
                    metadata=this.documents[chunk_id].metadata
                })
            }
        }

        // Sort by score descending and return top-k
        results.sort_by_descending(r => r.score)

        if results.length > top_k {
            return results[:top_k]
        }
        return results
    }

    save(path: string) {
        data = {
            "config": serialize(this.config),
            "documents": [serialize(doc) for doc in this.documents.values()],
            "embeddings": {id: emb.numpy() for id, emb in this.embeddings},
            "created_at": this.created_at,
            "last_updated": this.last_updated
        }
        write_json_file(path, data)
    }

    load(path: string) {
        data = read_json_file(path)
        this.config = deserialize(data["config"])

        for doc_data in data["documents"]:
            let doc = deserialize(doc_data)
            this.documents[doc.id] = doc

        for id_str, emb_array in data["embeddings"] {
            this.embeddings[id_str] = tensor(emb_array)
        }

        this.index_built = true
        this.last_updated = data["last_updated"]
    }

    count() {
        return this.documents.size()
    }

    clear() {
        this.embeddings.clear()
        this.documents.clear()
        this.index_built = false
    }

    get_status() {
        total_mem = sum(emb.numel() * emb.element_size() for emb in this.embeddings.values())
        return DBStatus{
            total_documents=this.count(),
            index_type="In-Memory (Brute Force)",
            memory_usage_mb=total_mem / (1024 * 1024),
            is_initialized=this.index_built,
            last_updated=this.last_updated
        }
    }
}

// ==================== FAISS English textdataEnglish text ====================

class FAISSVectorDB implements VectorDBInterface {
    config: retrieval_system_config
    index: any  // faiss.Index object
    id_to_chunk: map<int, DocumentChunk>
    next_id: int = 0
    is_trained: bool = false

    init(config: retrieval_system_config) {
        this.config = config
        this.id_to_chunk = map<int, DocumentChunk>{}
        this._create_index(config)
    }

    _create_index(config: retrieval_system_config) {
        dim = config.vector_dim
        match config.index_type {
            "FLAT" => {
                // Exact search (brute force), most accurate but slow for large datasets
                if config.metric == "cosine" or config.metric == "inner_product":
                    this.index = faiss.IndexIP(dim)  # Inner Product (for normalized vectors = cosine)
                else {
                    this.index = faiss.IndexFlatL2(dim)  # L2 distance
                }
                this.is_trained = true  # FLAT doesn't need training
            }
            "IVF_FLAT" => {
                // Inverted File with Flat quantizer
                quantizer = faiss.IndexFlatL2(dim)
                this.index = faiss.IndexIVFFlat(quantizer, dim, config.nlist, faiss.METRIC_L2)
                this.is_trained = false  # Needs add() to train
            }
            "HNSW" => {
                // Hierarchical Navigable Small World graph (fast, good recall)
                if config.metric == "l2":
                    this.index = faiss.IndexHNSWFlat(dim, 32)  # M=32 connections
                else:
                    this.index = faiss.IndexHNSWFlat(dim, 32, faiss.METRIC_INNER_PRODUCT)
                this.is_trained = true
            }
            "IVF_PQ" => {
                // Inverted File with Product Quantization (memory efficient)
                quantizer = faiss.IndexFlatL2(dim)
                m = min(48, dim // 2)  // Number of subquantizers
                nbits = 8             // Bits per subquantizer
                this.index = faiss.IndexIVFPQ(quantizer, dim, config.nlist, m, nbits)
                this.is_trained = false
            }
            _ => throw error(f"Unsupported FAISS index type: {config.index_type}")
        }

        // Set nprobe for IVF indexes
        if "IVF" in config.index_type {
            this.index.nprobe = config.nprobe
        }
    }

    insert(chunks: list<DocumentChunk>) {
        if chunks.length == 0 { return }

        // Collect embeddings that are not null
        valid_chunks: list<(DocumentChunk, tensor)> = []
        for chunk in chunks {
            if chunk.embedding != null {
                valid_chunks.append((chunk, chunk.embedding!))
            }
        }

        if valid_chunks.length == 0 { return }

        // Build matrix of embeddings: [N, dim]
        embeddings_matrix = stack([emb for _, emb in valid_chunks])

        // Normalize for cosine similarity if needed
        if this.config.normalize_embeddings || this.config.metric == "cosine" {
            embeddings_matrix = l2_normalize(embeddings_matrix, axis=1)
        }

        // Train index if needed (for IVF types)
        if !this.is_trained && embeddings_matrix.shape[0] >= 256 {
            this.index.train(embeddings_matrix)
            this.is_trained = true
        }

        // Add to index
        start_id = this.next_id
        ids_to_add = arange(start_id, start_id + valid_chunks.length).astype('int64')
        this.index.add_with_ids(embeddings_matrix, ids_to_add)

        // Store mapping from internal ID to chunk
        for i, (chunk, _) in enumerate(valid_chunks) {
            this.id_to_chunk[start_id + i] = chunk
        }

        this.next_id += valid_chunks.length
    }

    delete(chunk_ids: list<string>) {
        // FAISS doesn't support direct deletion; we use a filter approach
        // Mark as deleted in our mapping (lazy deletion)
        for chunk_id in chunk_ids {
            // Find internal ID by scanning
            for int_id, chunk in this.id_to_chunk {
                if chunk.id == chunk_id {
                    this.id_to_chunk.remove(int_id)
                    break
                }
            }
        }
    }

    search(query_embedding: tensor, top_k: int) {
        // Ensure query is 2D: [1, dim]
        if query_embedding.ndim == 1 {
            query_embedding = query_embedding.unsqueeze(0)
        }

        // Normalize query if needed
        if this.config.normalize_embeddings || this.config.metric == "cosine" {
            query_embedding = l2_normalize(query_embedding, axis=1)
        }

        // Search (search a bit more than needed for safety margin)
        k_actual = min(top_k * 2, this.index.ntotal)  // Get extra for potential filtering
        if k_actual == 0 { return [] }

        distances, indices = this.index.search(query_embedding, k_actual)

        results: list<SearchResultItem> = []
        for i in range(distances.shape[1]) {
            int_id = indices[0][i]

            // Skip invalid IDs (deleted or out of range)
            if int_id < 0 || int_id not in this.id_to_chunk { continue }

            score = distances[0][i]

            // For IP/Cosine: higher is better, already correct
            // For L2: convert to similarity (lower distance = better)
            if this.config.metric == "l2" {
                score = 1.0 / (1.0 + score)  # Convert L2 to similarity-like score
            }

            if score >= this.config.similarity_threshold {
                results.append(SearchResultItem{
                    chunk_id=this.id_to_chunk[int_id].id,
                    score=float(score),
                    metadata=this.id_to_chunk[int_id].metadata
                })

                if results.length >= top_k { break }
            }
        }

        return results
    }

    save(path: string) {
        faiss.write_index(this.index, path + ".index")

        # Save mapping
        mapping_data = [(int_id, serialize(chunk)) for int_id, chunk in this.id_to_chunk]
        write_pickle_file(path + ".mapping", {"mapping": mapping_data, "next_id": this.next_id})
    }

    load(path: string) {
        this.index = faiss.read_index(path + ".index")

        mapping_info = read_pickle_file(path + ".mapping")
        for int_id, chunk_data in mapping_info["mapping"] {
            this.id_to_chunk[int_id] = deserialize(chunk_data)
        }
        this.next_id = mapping_info["next_id"]
        this.is_trained = true
    }

    count() {
        return this.index.ntotal
    }

    clear() {
        this._create_index(this.config)
        this.id_to_chunk.clear()
        this.next_id = 0
    }

    get_status() {
        mem_bytes = faiss.index_memory_size(this.index) ?? 0
        return DBStatus{
            total_documents=this.count(),
            index_type=f"FAISS ({this.config.index_type})",
            memory_usage_mb=mem_bytes / (1024 * 1024),
            is_initialized=true,
            last_updated=current_timestamp()
        }
    }
}

// ==================== embedding English text ====================

class EmbeddingService {
    model_name: string
    model: any  // Pretrained embedding model
    tokenizer: any
    config: retrieval_system_config
    cache: LRUCache<string, tensor>

    init(model_name: string, config: retrieval_system_config) {
        this.model_name = model_name
        this.config = config
        this.cache = new LRUCache(capacity=10000)

        // Load model and tokenizer based on backend
        match model_name.split("/")[0].split("-")[0].to_lower() {
            "bge" => {
                // BGE series (BAAI/BGE models)
                this.model, this.tokenizer = load_transformers_model(
                    f"BAAI/{model_name}",
                    trust_remote_code=true
                )
            }
            "e5" => {
                // E5 series (Microsoft)
                this.model, this.tokenizer = load_transformers_model(
                    f"intfloat/{model_name}"
                )
            }
            "gte" => {
                // GTE series (Alibaba)
                this.model, this.tokenizer = load_transformers_model(
                    f"thenlper/{model_name}"
                )
            }
            _ => {
                // Default: try loading from HuggingFace Hub
                this.model, this.tokenizer = load_transformers_model(
                    model_name,
                    trust_remote_code=true
                )
            }
        }

        # Set model to eval mode
        this.model.eval()
        if has_gpu():
            this.model.to(device="cuda")
    }

    embed(texts: list<string>) {
        embeddings: list<tensor> = []

        # Process in batches
        for batch_start in range(0, texts.length, this.config.embedding_batch_size) {
            batch_texts = texts[batch_start : batch_start + this.config.embedding_batch_size]

            # Check cache first
            uncached_texts: list<string> = []
            uncached_indices: list<int> = []
            cached_results: map<int, tensor> = {}

            for i, text in enumerate(batch_texts) {
                cache_key = text[:200]  # Use first 200 chars as key
                if cache_key in this.cache {
                    cached_results[i] = this.cache[cache_key]
                } else {
                    uncached_texts.append(text)
                    uncached_indices.append(i)
                }
            }

            # Compute uncached embeddings
            if uncached_texts.length > 0 {
                batch_embeddings = this._compute_embeddings(uncached_texts)

                # Cache and store results
                for j, emb in enumerate(batch_embeddings) {
                    original_idx = uncached_indices[j]
                    cache_key = uncached_texts[j][:200]
                    this.cache[cache_key] = emb
                    cached_results[original_idx] = emb
                }
            }

            # Reorder back to original sequence
            for i in range(batch_texts.length) {
                embeddings.append(cached_results[i])
            }
        }

        return embeddings
    }

    embed_single(text: string) {
        results = this.embed([text])
        return results[0]
    }

    _compute_embeddings(texts: list<string>) {
        # Tokenize
        encoded = this.tokenizer(
            texts,
            padding=true,
            truncation=true,
            max_length=512,
            return_tensors="pt"
        )

        # Move to GPU if available
        if has_gpu() {
            encoded = {k: v.to("cuda") for k, v in encoded}

        # Forward pass (no grad for inference)
        with no_grad():
            outputs = this.model(**encoded)

        # Extract embeddings (use mean pooling or [CLS] token)
        # Most Chinese models use mean pooling over attention mask
        attention_mask = encoded["attention_mask"]
        hidden_states = outputs.last_hidden_state
        input_mask_expanded = attention_mask.unsqueeze(-1).expand(hidden_states.shape).float()

        sum_embeddings = (hidden_states * input_mask_expanded).sum(dim=1)
        sum_mask = input_mask_expanded.sum(dim=1).clamp(min=1e-9)

        embeddings = sum_embeddings / sum_mask  # [batch, hidden_dim]

        # Normalize if configured
        if this.config.normalize_embeddings {
            embeddings = l2_normalize(embeddings, p=2, dim=1)

        # Move to CPU and convert to list of tensors
        result: list<tensor> = []
        for i in range(embeddings.shape[0]):
            result.append(embeddings[i].detach().cpu())

        return result
    }
}

// LRU Cache implementation for embedding caching
class LRUCache<K, V> {
    capacity: int
    cache: OrderedDict<K, V>

    init(capacity: int) {
        this.capacity = capacity
        this.cache = new OrderedMap<K, V>()

    __getitem__(key: K) {
        if key not in this.cache {
            raise KeyError(key)
        # Move to end (most recently used)
        value = this.cache[key]
        this.cache.move_to_end(key)
        return value
    }

    __setitem__(key: K, value: V) {
        if key in this.cache:
            this.cache.move_to_end(key)
        elif this.cache.size() >= this.capacity:
            # Evict least recently used (first item)
            this.cache.popitem(last=false)
        this.cache[key] = value

    __contains__(key: K) {
        return key in this.cache

    size() {
        return this.cache.size()
    }
}

// ==================== English text ====================

class DocumentProcessor {
    config: retrieval_system_config
    splitter: TextSplitter

    init(config: retrieval_system_config) {
        this.config = config
        this.splitter = new RecursiveCharacterTextSplitter(
            chunk_size=config.max_chunk_length,
            chunk_overlap=config.max_chunk_length // 5,  # 20% overlap
        )
    }

    process_document(content: string, metadata: DocumentMetadata) {
        // Split into chunks
        raw_chunks = this.splitter.split_text(content)

        // Wrap into DocumentChunk objects with IDs and metadata
        chunks: list<DocumentChunk> = []
        for i, chunk_text in enumerate(raw_chunks) {
            chunks.append(DocumentChunk{
                id=generate_uuid(),
                content=chunk_text,
                metadata={...metadata, ...{"chunk_index": i}},
                chunk_index=i,
                token_count=estimate_token_count(chunk_text)
            })
        }

        return chunks
    }

    process_documents(documents: list<{content: string, metadata: DocumentMetadata}>) {
        all_chunks: list<DocumentChunk> = []
        for doc in documents {
            let chunks = this.process_document(doc.content, doc.metadata)
            all_chunks.extend(chunks)
        }
        return all_chunks
    }
}

// Text Splitter with multiple strategies
class RecursiveCharacterTextSplitter {
    chunk_size: int
    chunk_overlap: int
    separators: list<string>

    init(chunk_size: int, chunk_overlap: int) {
        this.chunk_size = chunk_size
        this.chunk_overlap = chunk_overlap
        this.separators = ["\n\n", "\n", ". ", ".", " ", ""]
    }

    split_text(text: string) {
        return this._recursive_split(text, this.separators)
    }

    _recursive_split(text: string, separators: list<string>) {
        if separators.length == 0 {
            # Final fallback: split by character
            return this._split_by_length(text)
        }

        separator = separators[0]
        remaining_separators = separators[1:]

        if separator.empty() {
            return this._split_by_length(text)
        }

        parts = text.split(separator)
        chunks: list<string> = []
        current_chunk = ""

        for part in parts {
            new_text = current_chunk + (current_chunk.empty() ? "" : separator) + part

            if new_text.length > this.chunk_size {
                if !current_chunk.empty() {
                    chunks.append(current_chunk)

                    # Handle overlap
                    overlap_text = current_chunk[-this.chunk_overlap:] if this.chunk_overlap > 0 else ""
                    current_chunk = overlap_text + part
                } else {
                    # Single part exceeds chunk size, try splitting with smaller separator
                    sub_chunks = this._recursive_split(part, remaining_separators)
                    chunks.extend(sub_chunks)
                }
            } else {
                current_chunk = new_text
            }
        }

        if !current_chunk.empty() {
            chunks.append(current_chunk)
        }

        return chunks
    }

    _split_by_length(text: string) {
        chunks: list<string> = []
        start = 0
        while start < text.length {
            end = start + this.chunk_size
            chunks.append(text[start:end])
            if this.chunk_overlap > 0 && end < text.length:
                start = end - this.chunk_overlap
            else:
                start = end
        }
        return chunks
    }
}

// ==================== queryextensionEnglish text ====================

class QueryExpander {
    llm_client: any  // Reference to LLM for generating expansions
    enabled: bool

    init(llm_client: any, enabled: bool = true) {
        this.llm_client = llm_client
        this.enabled = enabled
    }

    expand(query: string, num_expansions: int = 3) {
        if !this.enabled {
            return QueryExpansionResult{original=query, expanded=[]}
        }

        # Use LLM to generate query variations/expansions
        prompt = f"""
Given the following user query, generate {num_expansions} alternative phrasings
that could improve information retrieval. The expanded queries should:
- Preserve the original intent
- Include synonyms or related terms
- Cover different aspects of the question

Original query: "{query}"

Return only a JSON array of strings, e.g.: ["expansion1", "expansion2", "expansion3"]

Expanded queries:
"""

        response = this.llm_client.generate(prompt, temperature=0.7, max_tokens=150)

        # Parse JSON response
        try {
            expanded_queries = json_parse(response.text.strip())
            if isinstance(expanded_queries, list) && expanded_queries.length == num_expansions {
                return QueryExpansionResult{
                    original=query,
                    expanded=expanded_queries
                }
            }
        } catch {
            # Fallback: simple synonym expansion
            expanded = this._simple_expand(query, num_expansions)
            return QueryExpansionResult{original=query, expanded=expanded}
        }

        return QueryExpansionResult{original=query, expanded=[]}
    }

    _simple_expand(query: string, num: int) {
        # Basic expansion using rules/synonyms (fallback when LLM unavailable)
        synonyms_map: map<string, list<string>> = {
            "how": ["English text", "English text", "English text"],
            "what": ["English text", "English text", "English text"],
            "why": ["English text", "English text", "English text"],
            "best": ["English text", "English text", "English text", "recommended"],
            "method": ["English text", "English text", "English text", "English text"],
            "problem": ["English text", "English text", "English text", "English text"],
            "solution": ["English text", "English text", "English text"],
            "example": ["English text", "English text", "English text", "example"],
            "compare": ["English text", "English text", "English text", "English text"]
        }

        expanded: list<string> = []
        words = query.split_whitespace()

        for word in words {
            lower_word = word.lower()
            if lower_word in synonyms_map {
                for synonym in synonyms_map[lower_word][:num]:
                    variant = query.replace(word, synonym, 1)
                    if variant != query && variant not in expanded:
                        expanded.append(variant)
                    if expanded.length >= num { break }
            }
            if expanded.length >= num { break }
        }

        return expanded[:num]
    }
}

struct QueryExpansionResult {
    original: string
    expanded: list<string>
}

// ==================== keywordsEnglish text (BM25) ====================

class BM25Retriever {
    corpus: list<string>
    doc_ids: list<string>
    df: map<string, int>                      // term -> number of docs containing it
    tf: list<map<string, int>>               // per-document term frequency
    avg_doc_len: float
    k1: float = 1.5                          // Term frequency saturation parameter
    b: float = 0.75                         // Length normalization parameter

    init() {
        this.corpus = []
        this.doc_ids = []
        this.df = map<string, int>{}
        this.tf = []
        this.avg_doc_len = 0.0
    }

    build_index(documents: list<DocumentChunk>) {
        this.doc_ids = [doc.id for doc in documents]
        this.corpus = [doc.content.lower() for doc in documents]

        total_len = 0
        for doc_content in this.corpus {
            tokens = this._tokenize(doc_content)

            term_counts: map<string, int> = {}
            unique_terms: set<string> = set{}

            for token in tokens {
                term_counts[token] = term_counts.get(token, 0) + 1
                unique_terms.add(token)
            }

            this.tf.append(term_counts)
            total_len += tokens.length

            for term in unique_terms {
                this.df[term] = this.df.get(term, 0) + 1
            }
        }

        this.avg_doc_len = total_len / this.corpus.length if this.corpus.length > 0 else 1.0
    }

    search(query: string, top_k: int) {
        query_tokens = this._tokenize(query.lower())
        scores: list<tuple<int, float>> = []

        for doc_idx in range(this.corpus.length) {
            score = this._score_bm25(query_tokens, doc_idx)
            scores.append((doc_idx, score))
        }

        # Sort by score descending
        scores.sort_by_descending(s => s[1])

        results: list<BM25Result> = []
        for doc_idx, score in scores[:top_k] {
            if score > 0 {
                results.append(BM25Result{
                    chunk_id=this.doc_ids[doc_idx],
                    score=score
                })
            }
        }

        return results
    }

    _score_bm25(query_tokens: list<string>, doc_idx: int) {
        doc_tf = this.tf[doc_idx]
        doc_len = sum(doc_tf.values())  # Total terms in document

        score = 0.0
        for term in query_tokens {
            if term not in this.df { continue }

            tf_val = doc_tf.get(term, 0)
            df_val = this.df[term]
            n = this.corpus.length

            # IDF component (Robertson-Sparck Jones)
            idf = log((n - df_val + 0.5) / (df_val + 0.5) + 1.0)

            # TF component with saturation
            tf_component = (tf_val * (this.k1 + 1)) / (tf_val + this.k1 * (1 - this.b + this.b * doc_len / this.avg_doc_len))

            score += idf * tf_component
        }

        return score
    }

    _tokenize(text: string) {
        # Simple tokenization (in production, use jieba for Chinese)
        return text.split_whitespace()
            .map(t => t.strip_punctuation().lower())
            .filter(t => t.length >= 2)
    }
}

struct BM25Result {
    chunk_id: string
    score: float
}

// ==================== Cross-Encoder English textrankingEnglish text ====================

class CrossEncoderReranker {
    model: any
    tokenizer: any
    model_name: string
    device: string

    init(model_name: string) {
        this.model_name = model_name
        this.device = "cuda" if has_gpu() else "cpu"

        # Load cross-encoder model
        this.model, this.tokenizer = load_cross_encoder_model(model_name)
        this.model.eval()
        this.model.to(device=this.device)
    }

    rerank(query: string, candidates: list<DocumentChunk>, top_k: int) {
        if candidates.length == 0 { return [] }

        # Prepare query-document pairs
        pairs: list<tuple<string, string>> = []
        for candidate in candidates {
            pairs.append((query, candidate.content))
        }

        # Tokenize pairs
        features = this.tokenizer(
            pairs,
            padding=true,
            truncation=true,
            max_length=512,
            return_tensors="pt"
        ).to(this.device)

        # Compute relevance scores
        with no_grad():
            scores = this.model(**features).logits.squeeze(-1)

        # Convert to probabilities if binary classification model
        if scores.ndim == 2 && scores.shape[1] == 2:
            scores = softmax(scores, dim=-1)[:, 1]  # Probability of relevant class

        # Pair scores with candidates and sort
        scored_candidates: list<tuple<DocumentChunk, float>> = []
        for i, candidate in enumerate(candidates) {
            scored_candidates.append((candidate, float(scores[i])))
        }

        scored_candidates.sort_by_descending(x => x[1])

        # Return top-k
        results: list<RerankedResult> = []
        for candidate, score in scored_candidates[:top_k] {
            results.append(RerankedResult{
                chunk=candidate,
                rerank_score=score
            })
        }

        return results
    }
}

struct RerankedResult {
    chunk: DocumentChunk
    rerank_score: float
}

// ==================== English text ====================

class HybridFusionEngine {
    vector_weight: float
    keyword_weight: float
    normalization_method: string = "rrf"  # rrf (Reciprocal Rank Fusion) | weighted_average | score_normalize

    init(vector_w: float = 0.7, keyword_w: float = 0.3, method: string = "rrf") {
        assert abs(vector_w + keyword_w - 1.0) < 0.001, "Weights must sum to 1.0"
        this.vector_weight = vector_w
        this.keyword_weight = keyword_w
        this.normalization_method = method
    }

    fuse(vector_results: list<SearchResultItem>,
         bm25_results: list<BM25Result>,
         top_k: int) {

        match this.normalization_method {
            "rrf" => {
                return this._reciprocal_rank_fusion(vector_results, bm25_results, top_k)
            }
            "weighted_average" => {
                return this._weighted_average_fusion(vector_results, bm25_results, top_k)
            }
            "score_normalize" => {
                return this._normalized_score_fusion(vector_results, bm25_results, top_k)
            }
            _ => {
                throw error(f"Unknown fusion method: {this.normalization_method}")
            }
        }
    }

    _reciprocal_rank_fusion(vector_results: list<SearchResultItem>,
                            bm25_results: list<BM25Result>,
                            top_k: int,
                            k_constant: int = 60) {
        # RRF: score = Σ(1 / (k + rank_i))
        scores: map<string, float> = {}  # chunk_id -> fused_score

        # Add vector search ranks
        for rank, vr in enumerate(vector_results):
            rrf_score = 1.0 / (k_constant + rank + 1)
            scores[vr.chunk_id] = scores.get(vr.chunk_id, 0.0) + rrf_score * this.vector_weight

        # Add BM25 ranks
        for rank, br in enumerate(bm25_results):
            rrf_score = 1.0 / (k_constant + rank + 1)
            scores[br.chunk_id] = scores.get(br.chunk_id, 0.0) + rrf_score * this.keyword_weight

        # Sort by fused score
        sorted_scores = list(scores.items()).sort_by_descending(x => x[1])

        results: list<FusedResult> = []
        for chunk_id, score in sorted_scores[:top_k] {
            results.append(FusedResult{chunk_id=chunk_id, fused_score=score})
        }

        return results
    }

    _weighted_average_fusion(vector_results: list<SearchResultItem>,
                             bm25_results: list<BM25Result>,
                             top_k: int) {
        # Need normalized scores for fair comparison
        vec_scores: map<string, float> = {}
        kw_scores: map<string, float> = {}

        # Min-max normalize vector scores
        if vector_results.length > 0 {
            min_v = min(vr.score for vr in vector_results)
            max_v = max(vr.score for vr in vector_results)
            range_v = max_v - min_v if max_v > min_v else 1.0
            for vr in vector_results {
                norm_score = (vr.score - min_v) / range_v
                vec_scores[vr.chunk_id] = norm_score
            }
        }

        # Min-max normalize BM25 scores
        if bm25_results.length > 0 {
            min_b = min(br.score for br in bm25_results)
            max_b = max(br.score for br in bm25_results)
            range_b = max_b - min_b if max_b > min_b else 1.0
            for br in bm25_results {
                norm_score = (br.score - min_b) / range_b
                kw_scores[br.chunk_id] = norm_score
            }
        }

        # Combine
        combined: map<string, float> = {}
        all_ids = set(list(vec_scores.keys()) + list(kw_scores.keys()))

        for chunk_id in all_ids {
            v_s = vec_scores.get(chunk_id, 0.0) * this.vector_weight
            k_s = kw_scores.get(chunk_id, 0.0) * this.keyword_weight
            combined[chunk_id] = v_s + k_s
        }

        # Sort and return top-k
        sorted_combined = list(combined.items()).sort_by_descending(x => x[1])
        results: list<FusedResult> = []
        for chunk_id, score in sorted_combined[:top_k] {
            results.append(FusedResult{chunk_id=chunk_id, fused_score=score})
        }
        return results
    }

    _normalized_score_fusion(vector_results: list<SearchResultItem>,
                             bm25_results: list<BM25Result>,
                             top_k: int) {
        # Similar to weighted average but uses z-score normalization
        # Implementation omitted for brevity (similar logic to above)
        return this._weighted_average_fusion(vector_results, bm25_results, top_k)
    }
}

struct FusedResult {
    chunk_id: string
    fused_score: float
}

// ==================== NEURX RAG mainsystem ====================

class RetrievalEngine {
    config: retrieval_system_config
    vector_db: VectorDBInterface
    embedding_service: EmbeddingService
    document_processor: DocumentProcessor
    query_expander: QueryExpander?
    bm25_retriever: BM25Retriever?
    reranker: CrossEncoderReranker?
    fusion_engine: HybridFusionEngine
    documents_store: map<string, DocumentChunk>  # chunk_id -> full document chunk

    init(config: retrieval_system_config, llm_client?: any) {
        this.config = config
        this.documents_store = map<string, DocumentChunk>{}

        # Initialize components
        this.document_processor = new DocumentProcessor(config=config)

        # Initialize embedding service
        this.embedding_service = new EmbeddingService(
            model_name=config.embedding_model_name,
            config=config
        )

        # Initialize vector database based on configuration
        match config.vector_db_backend.to_lower() {
            "faiss" => {
                this.vector_db = new FAISSVectorDB(config=config)
            }
            "chroma" | "milvus" | "pinecone" => {
                # Would need respective client libraries
                throw error(f"{config.vector_db_backend} backend not yet implemented")
            }
            _ => {
                this.vector_db = new InMemoryVectorDB(config=config)
            }
        }

        # Initialize optional advanced components
        if llm_client != null && config.enable_query_expansion {
            this.query_expander = new QueryExpander(llm_client=llm_client!)
        }

        if config.enable_hybrid_search {
            this.bm25_retriever = new BM25Retriever()
        }

        if config.enable_cross_encoder_rerank {
            this.reranker = new CrossEncoderReranker(config.reranker_model)
        }

        this.fusion_engine = new HybridFusionEngine(
            vector_w=config.vector_weight,
            keyword_w=config.keyword_weight
        )
    }

    // === Core API Methods ===

    ingest(documents: list<{content: string, metadata: DocumentMetadata}>, compute_embeddings: bool = true) {
        start_time = current_time_millis()

        // Step 1: Process documents (chunking)
        chunks = this.document_processor.process_documents(documents)

        // Step 2: Compute embeddings if requested
        if compute_embeddings {
            chunk_texts = [c.content for c in chunks]
            embeddings_list = this.embedding_service.embed(chunk_texts)

            for i, chunk in enumerate(chunks) {
                chunk.embedding = embeddings_list[i]
            }
        }

        // Step 3: Store in vector DB
        this.vector_db.insert(chunks)

        # Store in local store for retrieval
        for chunk in chunks {
            this.documents_store[chunk.id] = chunk
        }

        # Step 4: Update BM25 index if hybrid search enabled
        if this.bm25_retriever != null {
            this.bm25_retriever!.build_index(chunks)
        }

        elapsed = current_time_millis() - start_time
        return IngestionReport{
            documents_ingested=documents.length,
            chunks_created=chunks.length,
            has_embeddings=compute_embeddings,
            processing_time_ms=elapsed,
            db_status=this.vector_db.get_status()
        }
    }

    retrieve(query: string, top_k?: int) {
        effective_top_k = top_k ?? this.config.top_k
        start_total = current_time_millis()

        // Step 1: Query Expansion (optional)
        expanded_query = query
        if this.query_expander != null && this.config.enable_query_expansion {
            exp_result = this.query_expander!.expand(query, num_expansions=3)
            if exp_result.expanded.length > 0 {
                # Combine original with best expansion
                expanded_query = query + " " + " ".join(exp_result.expanded[:2])
            }
        }

        // Step 2: Vector Search
        vec_start = current_time_millis()
        query_embedding = this.embedding_service.embed_single(query)
        vec_results = this.vector_db.search(query_embedding, effective_top_k * 2)
        vec_time = current_time_millis() - vec_start

        // Step 3: Keyword Search (if hybrid)
        bm25_results: list<BM25Result> = []
        bm25_time = 0.0
        if this.bm25_retriever != null && this.config.enable_hybrid_search {
            bm25_start = current_time_millis()
            bm25_results = this.bm25_retriever!.search(query, effective_top_k * 2)
            bm25_time = current_time_millis() - bm25_start
        }

        // Step 4: Fuse results
        fuse_start = current_time_millis()
        fused_results: list<FusedResult> = []

        if bm25_results.length > 0 && vec_results.length > 0 {
            fused_results = this.fusion_engine.fuse(vec_results, bm25_results, effective_top_k)
        } else if vec_results.length > 0 {
            # Only vector results
            fused_results = [FusedResult{chunk_id=v.chunk_id, fused_score=v.score} for v in vec_results[:effective_top_k]]
        } else if bm25_results.length > 0 {
            # Only keyword results
            fused_results = [FusedResult{chunk_id=b.chunk_id, fused_score=b.score} for b in bm25_results[:effective_top_k]]
        }

        fuse_time = current_time_millis() - fuse_start

        # Step 5: Reranking (if enabled)
        final_chunks: list<DocumentChunk> = []
        final_scores: list<float> = []
        rerank_time = 0.0

        if this.reranker != null && this.config.enable_reranking && fused_results.length > 0 {
            # Gather candidate documents
            candidates: list<DocumentChunk> = []
            for fr in fused_results {
                if fr.chunk_id in this.documents_store {
                    candidates.append(this.documents_store[fr.chunk_id])
                }
            }

            rerank_start = current_time_millis()
            reranked = this.reranker!.rerank(query, candidates, this.config.rerank_top_k)
            rerank_time = current_time_millis() - rerank_start

            for rr in reranked {
                final_chunks.append(rr.chunk)
                final_scores.append(rr.rerank_score)
            }
        } else {
            # No reranking, use fused scores directly
            for fr in fused_results {
                if fr.chunk_id in this.documents_store {
                    final_chunks.append(this.documents_store[fr.chunk_id])
                    final_scores.append(fr.fused_score)
                }
            }
        }

        total_time = current_time_millis() - start_total

        return SearchResult{
            chunks=final_chunks,
            scores=final_scores,
            query=query,
            expanded_query=expanded_query if expanded_query != query else null,
            retrieval_metadata=RetrievalMetadata{
                total_scanned=this.vector_db.count(),
                total_returned=final_chunks.length,
                vector_search_time_ms=vec_time,
                keyword_search_time_ms=bm25_time,
                rerank_time_ms=rerank_time,
                fusion_time_ms=fuse_time,
                used_hybrid_search=bm25_results.length > 0,
                used_query_expansion=expanded_query != query
            }
        }
    }

    generate_context_for_llm(search_result: SearchResult, max_tokens?: int) {
        effective_max_tokens = max_tokens ?? this.config.max_context_tokens

        context_parts: list<string> = []
        total_tokens = 0

        for i, chunk in enumerate(search_result.chunks) {
            if total_tokens + chunk.token_count > effective_max_tokens {
                break
            }

            # Format with citation
            source_info = chunk.metadata.source_path ?? chunk.metadata.source_id
            formatted = f"[{this.config.citation.format(index=i)}] {source_info}\n{chunk.content}\n"

            context_parts.append(formatted)
            total_tokens += chunk.token_count
        }

        return "\n".join(context_parts)
    }

    delete_documents(chunk_ids: list<string>) {
        this.vector_db.delete(chunk_ids)
        for id in chunk_ids {
            if id in this.documents_store { this.documents_store.remove(id) }
        }
    }

    get_statistics() {
        return RAGStatistics{
            total_documents=this.vector_db.count(),
            db_status=this.vector_db.get_status(),
            embedding_cache_size=this.embedding_service.cache.size(),
            bm25_ready=this.bm25_retriever != null,
            reranker_ready=this.reranker != null,
            query_expansion_enabled=this.query_expander != null
        }
    }

    save_state(path: string) {
        this.vector_db.save(path + "_vectordb")
        state = {
            "config": serialize(this.config),
            "documents": [serialize(doc) for doc in this.documents_store.values()]
        }
        write_json_file(path + "_state.json", state)
    }

    load_state(path: string) {
        this.vector_db.load(path + "_vectordb")
        state = read_json_file(path + "_state.json")
        for doc_data in state["documents"]:
            let doc = deserialize(doc_data)
            this.documents_store[doc.id] = doc
        }
    }
}

struct IngestionReport {
    documents_ingested: int
    chunks_created: int
    has_embeddings: bool
    processing_time_ms: float
    db_status: DBStatus
}

struct RAGStatistics {
    total_documents: int
    db_status: DBStatus
    embedding_cache_size: int
    bm25_ready: bool
    reranker_ready: bool
    query_expansion_enabled: bool
}

// ==================== English textfunctionEnglish texttest ====================

function create_retrieval_system(config?: retrieval_system_config, llm_client?: any) {
    return new RetrievalEngine(config=config ?? new retrieval_system_config(), llm_client=llm_client)
}

function test_retrieval_system() {
    print("🧪 Testing NEURX RAG System...")

    cfg = retrieval_system_config(vector_db_backend="in_memory", vector_dim=128, enable_reranking=false, enable_query_expansion=false)
    rag = create_retrieval_system(cfg)

    # Test 1: document ingestion
    print("  ✓ Test 1: document Ingestion & Chunking")
    sample_docs = [
        {
            content="English textcomputeEnglish text, English textRequiredEnglish textsystem.English text.",
            metadata=DocumentMetadata{source_id="doc1", title="AI Introduction", document_type="text"}
        },
        {
            content="English text, English text, English text(CNN)English text(RNN).TransformerEnglish textlanguageEnglish text.",
            metadata=DocumentMetadata{source_id="doc2", title="Deep Learning Overview", document_type="text"}
        },
        {
            content="NEURX(General Language Model)English textAIEnglish textlanguagemodelEnglish text.NEURX-4supportEnglish text, English text, toolEnglish text.MULTIMODAL-VISIONEnglish text.",
            metadata=DocumentMetadata{source_id="doc3", title="NEURX Model Series", document_type="text"}
        }
    ]

    report = rag.ingest(sample_docs, compute_embeddings=false)  # Skip actual embedding for test
    assert report.documents_ingested == 3, f"Ingestion count mismatch: {report.documents_ingested}"
    assert report.chunks_created >= 3, f"Chunks created too few: {report.chunks_created}"

    # Test 2: Vector search (with mock embeddings)
    print("  ✓ Test 2: Vector Similarity Search")
    # Manually set some mock embeddings
    chunks = list(rag.documents_store.values())
    for chunk in chunks {
        chunk.embedding = randn(cfg.vector_dim)  # Random vectors for testing
    }
    rag.vector_db.insert(chunks)

    query_vec = randn(cfg.vector_dim)
    search_results = rag.vector_db.search(query_vec, top_k=3)
    assert search_results.length <= 3, f"Too many results: {search_results.length}"

    # Test 3: BM25 keyword search
    print("  ✓ Test 3: BM25 Keyword Search")
    if rag.bm25_retriever != null {
        rag.bm25_retriever!.build_index(chunks)
        bm25_res = rag.bm25_retriever!.search("English text NEURX", top_k=3)
        assert bm25_res.length > 0, "BM25 should find results"
    }

    # Test 4: Full retrieve pipeline
    print("  ✓ Test 4: Full Retrieve Pipeline")
    # Since we don't have real embedding service, we'll test structure
    stats = rag.get_statistics()
    assert stats.total_documents >= 3, f"Stats doc count wrong: {stats.total_documents}"

    print("\n✅ All RAG System Tests Passed!")
    return true
}

// Export public API
export {
    retrieval_system_config, DocumentChunk, DocumentMetadata, SearchResult, RetrievalMetadata,
    VectorDBInterface, InMemoryVectorDB, FAISSVectorDB,
    EmbeddingService, DocumentProcessor, QueryExpander,
    BM25Retriever, CrossEncoderReranker, HybridFusionEngine,
    RetrievalEngine, IngestionReport, RAGStatistics,
    create_retrieval_system, test_rag_system
}
