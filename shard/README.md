# NeurX Shard Module

This directory contains all data sharding-related utilities for the NeurX training pipeline.

## File Organization

### Python Implementation
- **shard_wikipedia_enwiki.py** - Main Wikipedia sharding script (processes Wikipedia dumps into JSONL shards)

### S Language Implementations
- **shard_wikipedia.s** - S language version of Wikipedia sharding (faster startup, lower memory)
- **shard_enwiki.s** - Alternative S implementation for enwiki processing
- **shard_manager.s** - Shard management utilities
- **data_shard.s** - Data shard generation from cleaned datasets
- **test_shard.s** - Testing utilities for shard validation
- **verify_shards.s** - Shard verification and validation

### Shell Scripts
- **generate_shards.sh** - Legacy shell script for shard generation (delegates to make)
- **load_shards.sh** - Utilities for loading shard metadata
- **shard_enwiki.sh** - Shell script wrapper for Wikipedia sharding

## Usage

### From Makefile

```bash
# Python-based sharding
make shard

# S language-based sharding
make shard-enwiki
make shard-s

# Full data pipeline
make data-pipeline-s
```

### Direct Execution

```bash
# Python
python3 shard/shard_wikipedia_enwiki.py \
  --input dataset/pretrain/raw/enwiki-latest-pages-articles.xml.bz2 \
  --output-dir dataset/pretrain/shard \
  --manifest dataset/pretrain/manifest.json \
  --docs-per-shard 5000

# S language (if compiled)
./artifacts/build/shard/shard_wikipedia \
  --input dataset/pretrain/raw/enwiki-latest-pages-articles.xml.bz2 \
  --output-dir dataset/pretrain/shard \
  --docs-per-shard 5000
```

## Configuration

### Environment Variables

For all sharding operations:
- `NEURX_HOME` - Project root directory
- `ENWIKI_BZ2_FILE` - Path to Wikipedia dump (default: `$NEURX_HOME/dataset/pretrain/raw/enwiki-latest-pages-articles.xml.bz2`)
- `ENWIKI_SHARD_DIR` - Output directory for shards (default: `$NEURX_HOME/dataset/pretrain/shard`)
- `ENWIKI_MANIFEST_FILE` - Output manifest file (default: `$NEURX_HOME/dataset/pretrain/manifest.json`)
- `DOCS_PER_SHARD` - Documents per shard file (default: 5000)
- `MAX_PAGES` - Optional test limit for pages to process (default: 0 = unlimited)

## Output Format

### Shard Files
```
dataset/pretrain/shard/shard_00000.jsonl
dataset/pretrain/shard/shard_00001.jsonl
...
```

Each line is a JSON record with:
```json
{
  "title": "Article Title",
  "page_id": "12345",
  "text": "Article text content...",
  "source": "enwiki-latest-pages-articles.xml.bz2"
}
```

### Manifest File
```json
{
  "dataset_name": "neurx-pretrain-wikipedia",
  "version": "1.0",
  "created_at": "2026-07-09T00:00:00Z",
  "source_file": "path/to/enwiki-latest-pages-articles.xml.bz2",
  "total_shards": 42,
  "total_documents": 210000,
  "total_size_bytes": 5368709120,
  "average_docs_per_shard": 5000,
  "shards": [
    {
      "shard_id": "shard_00000",
      "file_path": "path/to/shard_00000.jsonl",
      "num_documents": 5000,
      "size_bytes": 128000000
    }
  ]
}
```

## Performance Characteristics

### Python Implementation (shard_wikipedia_enwiki.py)
- Startup time: 1-2 seconds
- Memory usage: ~350MB
- Processing speed: ~1000 pages/second

### S Language Implementation (shard_wikipedia.s)
- Startup time: 50-100ms
- Memory usage: ~80MB
- Processing speed: ~5000 pages/second (when compiled)
- Compilation time: 2-3 seconds

## Development Notes

### Adding New Sharding Strategies
1. Create new S or Python file in this directory
2. Implement the sharding logic
3. Update Makefile with new target if needed
4. Add documentation in this README

### Testing
```bash
# Test shard generation with subset
make shard MAX_PAGES=1000

# Verify generated shards
./artifacts/build/s_runner ./artifacts/build/data_scripts/verify.ir
```

## See Also
- [S_IMPLEMENTATION_GUIDE.md](../S_IMPLEMENTATION_GUIDE.md) - General S language implementation info
- [MAKE_TRAIN_QUICKSTART.md](../MAKE_TRAIN_QUICKSTART.md) - Quick start guide
