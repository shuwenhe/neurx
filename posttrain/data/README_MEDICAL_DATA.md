# Medical Data Processing Pipeline (neurx/posttrain/data/medical_data_pipeline.s)

## Overview

End-to-end pipeline for constructing high-quality medical instruction data for SFT training.

**Input**: Medical articles from MySQL `uptodate_data` table  
**Output**: `medical_instruct_sft_dataset.jsonl` (>1000 samples)

## 8-Layer Quality Control

### Layer 1: Source Filtering
- Filter to non-empty medical articles
- Verify content exists

### Layer 2: Metadata Cleanup
Remove:
- Author/editor/translator information
- Evidence review statements
- Publication metadata

### Layer 3: Citation Removal
Remove:
- Reference citations: [1], [2-3], [1,2]
- Figure/table references: (图1), (Table 2)
- Cross-references: (参见"...")

### Layer 4: Theme Extraction
Extract disease/condition terms from title + subtitle.

**Blacklist** (100+ terms to exclude):
- Generic concepts: 筛查, 诊断, 治疗, 管理
- Statistical measures: 患病率, 发病率, 死亡率
- Document types: 综述, 指南, 分析

**Fallback**: If no valid term extracted, use "健康问题"

### Layer 5: Question Generation
Use 7 seed templates:

```
1. 什么是{subject}?
2. {subject}的通俗解释是什么?
3. {subject}是怎么分型的?
4. {subject}是怎么分期的?
5. {subject}的诊断定义是什么?
6. {subject}的发病机制是什么?
7. {subject}的病理生理过程是什么?
```

Intent mapping:
- definition → "definition"
- 分型/分期 → "classification"
- 诊断 → "diagnosis"
- 机制 → "mechanism"

### Layer 6: Content Enhancement
Extract content relevant to question intent.

**Intent patterns**:
- **definition**: Match "定义", "概念", "是指", "是一种"
- **diagnosis**: Match "诊断", "确诊", "检查", "症状"
- **mechanism**: Match "机制", "原因", "病因", "病理"

**Limits**:
- Max 500 characters per answer
- Keep first 5 sentences if exceeds limit

### Layer 7: API Language Polish (Optional)
Call Qwen3.5-35B-A3B to:
- Remove third-person references
- Genericize patient cases
- Ensure logical clarity
- Verify medical accuracy

**Constraints** (8 rules):
1. No generic pronouns (本专题, 该病变)
2. Specific not vague questions
3. Skip if contains "学会指南链接"
4. No third-person patient cases
5. Focus on concepts, not cases
6. Clear logical flow
7. Accurate terminology
8. Answer only asked question

### Layer 8: Deduplication (SimHash)
- 64-bit SimHash algorithm
- Hamming distance < 8 → duplicate
- Remove content-level duplicates
- Strict question string matching

## Data Structures

### Input: Medical Article

```s
struct medical_article {
    string id
    string specialty_name     // "Cardiology", "Endocrinology"
    string category
    string title              // "Heart Failure Management"
    string subtitle
    string plain_content      // 2000+ characters
    []string keywords
}
```

### Output: Instruction Sample

```json
{
  "messages": [
    {
      "role": "user",
      "content": "什么是心衰?"
    },
    {
      "role": "assistant",
      "content": "心衰是指心脏无法提供足够的血流来满足身体需求..."
    }
  ]
}
```

## Processing Statistics

| Metric | Value |
|---|---|
| **Articles Read** | ~10,000 (from MySQL) |
| **Valid Articles** | ~9,500 (non-empty) |
| **Samples Generated** | >1,000 |
| **Duplicates Removed** | ~500 |
| **API Failures** | <50 |
| **Final Output** | medical_instruct_sft_dataset.jsonl |

## Quality Signals

Each sample tracks:
- Source domain (specialty_name)
- Question intent type
- Content length distribution
- Deduplication hash

## Usage Example

```s
[]medical_article articles = load_from_mysql(
    host: "127.0.0.1",
    database: "uptodate_db"
)

pipeline_stats stats = process_medical_articles(
    articles,
    output_file: "./data/medical_instruct_sft_dataset.jsonl"
)

// stats.samples_generated = 1247
// stats.duplicates_removed = 483
// stats.total_tokens_processed = 2,847,582
```

## Configuration

**MySQL Connection**:
```s
mysql_config cfg = mysql_config{
    host: "medical-db.internal",
    port: 3306,
    database: "uptodate_db",
    table: "uptodate_data"
}
```

**Constraints**:
```s
int MIN_SAMPLES = 1000
int MAX_CONTENT_LENGTH = 8000
int SIMHASH_HAMMING_THRESHOLD = 8
int MAX_TOKENS_PER_RESPONSE = 500
```

## Integration with SFT

After pipeline:

```bash
# 1. Generate base dataset
process_medical_articles(articles, "data/medical_instruct_sft_dataset.jsonl")

# 2. Split train/val
python extract_data.py

# 3. SFT training
bash Post_train/step1_Instruct_SFT/train.sh
```

## Related Files

- `neurx/posttrain/alignment/clinical_alignment.s` - Coordinator
- `train/medical_model/Post_train/step1_Instruct_SFT/data/export_jsonl_from_mysql_ANALYSIS.md` - Python reference
- `train/medical_model/Post_train/step1_Instruct_SFT/extract_data.py` - Train/val split
