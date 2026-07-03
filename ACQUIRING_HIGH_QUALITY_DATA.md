# 🎯 企业级高质量数据获取完整指南

> 针对训练 Claude 级大模型的数据获取、评估、清洗全流程

---

## 📋 目录

1. [数据来源](#数据来源)
2. [质量评估标准](#质量评估标准)
3. [数据清洗流程](#数据清洗流程)
4. [自动化质量检查](#自动化质量检查)
5. [数据融合策略](#数据融合策略)
6. [成本与时间估算](#成本与时间估算)

---

## 🌍 数据来源

### 第一优先级：高质量开源数据集

#### **1. Common Crawl CC-100** ⭐⭐⭐⭐⭐
- **规模**: ~750GB 文本 (120B tokens)
- **语言**: 100+ 种语言
- **质量**: 高 (网页去重后)
- **获取方式**: AWS S3
- **成本**: 免费 (仅需支付 S3 传输费用 ~$50-100)

```bash
#!/bin/bash
# 下载 Common Crawl 数据

# 方法 1: 使用官方工具
pip install warc3-wet

# 下载 WARC 文件
aws s3 ls s3://commoncrawl/crawl-data/CC-MAIN-2024-01/ \
  --no-sign-request | grep wet.gz | head -10 | awk '{print $4}' | \
  xargs -I {} aws s3 cp s3://commoncrawl/{} ./ --no-sign-request

# 提取文本
for file in *.wet.gz; do
    zcat "$file" | python -c "
import sys
from warcio.archiveiterator import ArchiveIterator
from io import BytesIO

for record in ArchiveIterator(sys.stdin.buffer):
    if record.rec_type == 'response':
        text = record.content_stream().read().decode('utf-8', errors='ignore')
        print(json.dumps({'text': text, 'source': 'common_crawl'}))
    "
done > cc100_extracted.jsonl
```

#### **2. Wikipedia 中英文** ⭐⭐⭐⭐⭐
- **规模**: ~80GB 文本 (13B tokens)
- **质量**: 极高 (经过同行评审)
- **获取方式**: Hugging Face / Wikipedia 官方
- **成本**: 免费

```bash
#!/bin/bash
# 下载维基百科数据

# 使用 Hugging Face 数据集
python -c "
from datasets import load_dataset
import json

# 英文维基百科
en_wiki = load_dataset('wikipedia', '20220301.en')

with open('wikipedia_en.jsonl', 'w') as f:
    for doc in en_wiki['train']:
        output = {
            'text': doc['text'],
            'title': doc['title'],
            'source': 'wikipedia_en'
        }
        f.write(json.dumps(output, ensure_ascii=False) + '\n')

# 中文维基百科
zh_wiki = load_dataset('wikipedia', '20220301.zh')

with open('wikipedia_zh.jsonl', 'w') as f:
    for doc in zh_wiki['train']:
        output = {
            'text': doc['text'],
            'title': doc['title'],
            'source': 'wikipedia_zh'
        }
        f.write(json.dumps(output, ensure_ascii=False) + '\n')

print('✓ Wikipedia data downloaded')
"
```

#### **3. The Pile** ⭐⭐⭐⭐⭐
- **规模**: ~800GB (825 billion tokens)
- **质量**: 高 (多领域精选)
- **构成**:
  - Books (196GB)
  - Common Crawl (381GB)
  - Academic (75GB)
  - Code (55GB)
  - Other (100GB+)
- **获取方式**: Hugging Face
- **成本**: 免费

```bash
#!/bin/bash
# 下载 The Pile 数据

python -c "
from datasets import load_dataset
import json

# 加载 The Pile
dataset = load_dataset('the_pile', streaming=True)

count = 0
with open('the_pile.jsonl', 'w') as f:
    for example in dataset['train']:
        output = {
            'text': example['text'],
            'meta': example.get('meta', {}),
            'source': 'the_pile'
        }
        f.write(json.dumps(output, ensure_ascii=False) + '\n')
        count += 1
        
        if count % 10000 == 0:
            print(f'Processed: {count}')
        
        if count >= 1000000:  # 示例: 处理 100 万条
            break

print(f'✓ Downloaded {count} examples from The Pile')
"
```

#### **4. Code Repositories (GitHub Code)** ⭐⭐⭐⭐
- **规模**: ~1.3TB (1.6B tokens)
- **质量**: 高 (真实生产代码)
- **获取方式**: GitHub Archive / CodeSearchNet
- **成本**: 免费 (GitHub Archive in BigQuery)

```bash
#!/bin/bash
# 下载 GitHub 代码数据

# 使用 Big Query (需要 Google Cloud 账户)
bq query --use_legacy_sql=false '
SELECT content, language FROM `bigquery-public-data.github_repos.contents`
WHERE language IN ("Python", "JavaScript", "Go", "Rust", "Java")
LIMIT 1000000
' > github_code.jsonl

# 或使用 CodeSearchNet
python -c "
from datasets import load_dataset
import json

dataset = load_dataset('code_search_net', 'python')

with open('github_code_python.jsonl', 'w') as f:
    for doc in dataset['train']:
        output = {
            'text': doc['whole_func_string'],
            'language': 'python',
            'source': 'codesearchnet'
        }
        f.write(json.dumps(output, ensure_ascii=False) + '\n')

print('✓ GitHub code downloaded')
"
```

#### **5. ArXiv 学术论文** ⭐⭐⭐⭐
- **规模**: ~1.4M 论文 (~200GB 文本)
- **质量**: 极高 (经过同行评审)
- **获取方式**: ArXiv 官方 API
- **成本**: 免费

```bash
#!/bin/bash
# 下载 ArXiv 数据

python -c "
import requests
import json
from time import sleep

# ArXiv API 端点
url = 'http://export.arxiv.org/api/query'

categories = ['cs.AI', 'cs.LG', 'math.CO', 'physics.QM', 'stat.ML']
papers = []

for category in categories:
    params = {
        'search_query': f'cat:{category}',
        'start': 0,
        'max_results': 100000,
        'sortBy': 'submittedDate',
        'sortOrder': 'descending'
    }
    
    response = requests.get(url, params=params)
    
    for entry in response.entries:
        paper = {
            'title': entry.title,
            'summary': entry.summary,
            'text': f'{entry.title}\n\n{entry.summary}',
            'authors': [author.name for author in entry.authors],
            'published': entry.published,
            'source': 'arxiv'
        }
        papers.append(paper)
    
    sleep(5)  # 遵守 API 速率限制

with open('arxiv_papers.jsonl', 'w') as f:
    for paper in papers:
        f.write(json.dumps(paper, ensure_ascii=False) + '\n')

print(f'✓ Downloaded {len(papers)} papers from ArXiv')
"
```

#### **6. Books 和技术文档** ⭐⭐⭐⭐⭐
- **规模**: 取决于来源
- **质量**: 极高
- **来源**:
  - Project Gutenberg (免费电子书)
  - Open Library
  - 技术文档 (TensorFlow, PyTorch 等)
  - 教科书文本

```bash
#!/bin/bash
# 下载免费电子书

# Project Gutenberg
python -c "
import requests
import json
from bs4 import BeautifulSoup

# 获取书籍列表
catalog_url = 'https://www.gutenberg.org/files/'
books_to_download = []

# 下载指定书籍
book_ids = [
    11, 84, 98, 1342, 4300,  # 经典著作
    # ... 添加更多书籍 ID
]

for book_id in book_ids:
    # 尝试多个格式
    for fmt in ['txt.utf-8', 'html.utf-8']:
        url = f'{catalog_url}{book_id}/{book_id}-0.{fmt}'
        try:
            response = requests.get(url)
            if response.status_code == 200:
                text = response.text
                if fmt == 'html.utf-8':
                    # 解析 HTML
                    soup = BeautifulSoup(text, 'html.parser')
                    text = soup.get_text()
                
                with open(f'gutenberg_{book_id}.jsonl', 'a') as f:
                    output = {
                        'text': text,
                        'source': 'project_gutenberg',
                        'book_id': book_id
                    }
                    f.write(json.dumps(output, ensure_ascii=False) + '\n')
                print(f'✓ Downloaded book {book_id}')
                break
        except:
            continue
"
```

---

## 📊 质量评估标准

### 关键质量指标

```python
# quality_metrics.py

import re
from collections import Counter
import numpy as np

class DataQualityEvaluator:
    def __init__(self):
        self.min_length = 100  # 最少 100 字符
        self.max_length = 100000  # 最多 100K 字符
        self.min_words = 20  # 最少 20 词
    
    def evaluate_document(self, doc):
        """综合评估文档质量"""
        
        scores = {}
        
        # 1️⃣ 长度评分 (Length Score)
        length_score = self._score_length(doc)
        scores['length'] = length_score
        
        # 2️⃣ 自然语言评分 (Language Score)
        language_score = self._score_language(doc)
        scores['language'] = language_score
        
        # 3️⃣ 多样性评分 (Diversity Score)
        diversity_score = self._score_diversity(doc)
        scores['diversity'] = diversity_score
        
        # 4️⃣ 噪音评分 (Noise Score)
        noise_score = self._score_noise(doc)
        scores['noise'] = noise_score
        
        # 5️⃣ 可读性评分 (Readability Score)
        readability_score = self._score_readability(doc)
        scores['readability'] = readability_score
        
        # 总体评分
        overall_score = np.mean([
            length_score * 0.15,
            language_score * 0.25,
            diversity_score * 0.20,
            noise_score * 0.20,
            readability_score * 0.20
        ])
        
        return {
            'scores': scores,
            'overall_score': overall_score,
            'quality_level': self._classify_quality(overall_score),
            'passed': overall_score > 0.6
        }
    
    def _score_length(self, doc):
        """长度评分 (0-1)"""
        length = len(doc)
        if length < self.min_length or length > self.max_length:
            return 0.0
        if length < 1000:
            return 0.5
        if length > 50000:
            return 0.7
        return 1.0
    
    def _score_language(self, doc):
        """自然语言评分"""
        # 检查字母占比
        letters = sum(1 for c in doc if c.isalpha())
        total = len(doc)
        letter_ratio = letters / total if total > 0 else 0
        
        # 检查单词平均长度
        words = re.findall(r'\b\w+\b', doc)
        avg_word_length = np.mean([len(w) for w in words]) if words else 0
        
        # 自然语言通常有:
        # - 字母占比 60-90%
        # - 平均单词长度 4-7 字符
        
        language_score = 0
        if 0.6 < letter_ratio < 0.9:
            language_score += 0.5
        if 4 < avg_word_length < 7:
            language_score += 0.5
        
        return min(language_score, 1.0)
    
    def _score_diversity(self, doc):
        """文本多样性评分"""
        # 计算唯一字符比例
        unique_chars = len(set(doc))
        total_chars = len(doc)
        char_diversity = unique_chars / total_chars if total_chars > 0 else 0
        
        # 计算词汇多样性 (type-to-token ratio)
        words = re.findall(r'\b\w+\b', doc.lower())
        unique_words = len(set(words))
        total_words = len(words)
        vocab_diversity = unique_words / total_words if total_words > 0 else 0
        
        # 综合多样性
        diversity_score = (char_diversity * 0.3 + vocab_diversity * 0.7)
        
        return min(diversity_score, 1.0)
    
    def _score_noise(self, doc):
        """噪音评分 (检测异常内容)"""
        
        noise_level = 0
        
        # 检查 URL 数量
        urls = len(re.findall(r'https?://\S+', doc))
        if urls > len(doc) / 100:  # URL 比例 > 1%
            noise_level += 0.2
        
        # 检查邮箱地址
        emails = len(re.findall(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', doc))
        if emails > 0:
            noise_level += 0.1
        
        # 检查重复行
        lines = doc.split('\n')
        repeated_lines = len([l for l in lines if lines.count(l) > 1])
        if repeated_lines / len(lines) > 0.2:
            noise_level += 0.2
        
        # 检查特殊字符过多
        special_chars = sum(1 for c in doc if not c.isalnum() and not c.isspace())
        if special_chars / len(doc) > 0.3:
            noise_level += 0.2
        
        # 转换为 0-1 评分
        return max(1 - noise_level, 0)
    
    def _score_readability(self, doc):
        """可读性评分"""
        
        # Flesch-Kincaid 级数 (简化版)
        sentences = len(re.split(r'[.!?]+', doc))
        words = len(re.findall(r'\b\w+\b', doc))
        syllables = self._count_syllables(doc)
        
        if sentences == 0 or words == 0:
            return 0.5
        
        # 计算可读性指数
        grade = 0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59
        
        # 将级数转换为 0-1 分数
        # 高中级 (9-12) 最佳
        if 8 < grade < 13:
            return 1.0
        elif 5 < grade < 15:
            return 0.8
        elif 3 < grade < 18:
            return 0.6
        else:
            return 0.3
    
    def _count_syllables(self, doc):
        """估计音节数"""
        # 简化算法
        vowels = 'aeiouy'
        syllable_count = 0
        previous_was_vowel = False
        
        for char in doc.lower():
            is_vowel = char in vowels
            if is_vowel and not previous_was_vowel:
                syllable_count += 1
            previous_was_vowel = is_vowel
        
        return max(syllable_count, 1)
    
    def _classify_quality(self, score):
        """分类质量等级"""
        if score > 0.85:
            return 'excellent'
        elif score > 0.70:
            return 'good'
        elif score > 0.50:
            return 'fair'
        else:
            return 'poor'


# 使用示例
evaluator = DataQualityEvaluator()

# 评估单个文档
test_doc = """
机器学习是人工智能的一个重要分支，它使计算机能够从数据中学习。
通过机器学习，我们可以建立能够识别模式、做出预测并不断改进的系统。
在过去十年中，机器学习已经被应用到许多领域，包括计算机视觉、自然语言处理和推荐系统。
"""

result = evaluator.evaluate_document(test_doc)
print(f"质量评分: {result['overall_score']:.2%}")
print(f"质量等级: {result['quality_level']}")
print(f"通过过滤: {result['passed']}")
```

---

## 🔧 数据清洗流程

### 完整的数据清洗管道

```bash
#!/bin/bash
# comprehensive_data_cleaning.sh

set -e

DATA_ROOT="data/pretrain_dataset"
RAW_DIR="$DATA_ROOT/raw"
CLEANED_DIR="$DATA_ROOT/cleaned"
TEMP_DIR="$DATA_ROOT/temp"

mkdir -p "$CLEANED_DIR" "$TEMP_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 开始完整数据清洗流程"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 步骤 1: 格式验证
echo ""
echo "1️⃣  格式验证..."
python -c "
import json
import glob

invalid_count = 0
for file in glob.glob('$RAW_DIR/*.jsonl'):
    with open(file) as f:
        for i, line in enumerate(f):
            try:
                doc = json.loads(line)
                if 'text' not in doc:
                    invalid_count += 1
                    print(f'✗ {file}:{i+1} - 缺少 text 字段')
            except json.JSONDecodeError as e:
                invalid_count += 1
                print(f'✗ {file}:{i+1} - JSON 解析错误: {e}')

print(f'✓ 验证完成: {invalid_count} 个错误')
" > "$TEMP_DIR/validation_result.txt"

# 步骤 2: 去重
echo "2️⃣  文本去重 (使用 MD5 哈希)..."
python -c "
import json
import hashlib
import glob
from tqdm import tqdm

seen_hashes = set()
output_file = '$CLEANED_DIR/deduped.jsonl'

doc_count = 0
dup_count = 0

for file in sorted(glob.glob('$RAW_DIR/*.jsonl')):
    print(f'Processing: {file}')
    with open(file) as f:
        for line in f:
            try:
                doc = json.loads(line)
                text = doc.get('text', '')
                
                # 计算 MD5 哈希
                text_hash = hashlib.md5(text.encode()).hexdigest()
                
                if text_hash not in seen_hashes:
                    with open(output_file, 'a') as out:
                        out.write(line)
                    seen_hashes.add(text_hash)
                    doc_count += 1
                else:
                    dup_count += 1
            except:
                pass

print(f'✓ 去重完成: {doc_count} 个文档保留, {dup_count} 个重复删除')
print(f'去重率: {dup_count / (doc_count + dup_count) * 100:.1f}%')
"

# 步骤 3: 语言检测
echo "3️⃣  语言检测与过滤..."
pip install langdetect >/dev/null 2>&1

python -c "
import json
import langdetect

input_file = '$CLEANED_DIR/deduped.jsonl'
output_file = '$CLEANED_DIR/lang_filtered.jsonl'

supported_langs = ['en', 'zh', 'es', 'fr', 'de', 'ja', 'ru']
doc_count = 0
lang_count = {}

with open(input_file) as f, open(output_file, 'w') as out:
    for line in f:
        try:
            doc = json.loads(line)
            text = doc.get('text', '')
            
            try:
                lang = langdetect.detect(text)
                if lang in supported_langs:
                    out.write(line)
                    doc_count += 1
                    lang_count[lang] = lang_count.get(lang, 0) + 1
            except:
                pass
        except:
            pass

print(f'✓ 语言过滤完成: {doc_count} 个文档')
print('语言分布:')
for lang, count in sorted(lang_count.items(), key=lambda x: -x[1]):
    print(f'  {lang}: {count}')
"

# 步骤 4: 长度过滤
echo "4️⃣  长度过滤..."
python -c "
import json

input_file = '$CLEANED_DIR/lang_filtered.jsonl'
output_file = '$CLEANED_DIR/length_filtered.jsonl'

min_length = 100  # 最少 100 字符
max_length = 100000  # 最多 100K 字符

doc_count = 0
too_short = 0
too_long = 0

with open(input_file) as f, open(output_file, 'w') as out:
    for line in f:
        try:
            doc = json.loads(line)
            text = doc.get('text', '')
            length = len(text)
            
            if length < min_length:
                too_short += 1
            elif length > max_length:
                too_long += 1
            else:
                out.write(line)
                doc_count += 1
        except:
            pass

total = doc_count + too_short + too_long
print(f'✓ 长度过滤完成:')
print(f'  保留: {doc_count} ({doc_count/total*100:.1f}%)')
print(f'  过短: {too_short} ({too_short/total*100:.1f}%)')
print(f'  过长: {too_long} ({too_long/total*100:.1f}%)')
"

# 步骤 5: 质量评分
echo "5️⃣  质量评分与过滤..."
cat > "$TEMP_DIR/quality_scorer.py" << 'EOF'
# 使用上面定义的 DataQualityEvaluator 类
import json
import sys
sys.path.insert(0, '.')
from quality_metrics import DataQualityEvaluator

evaluator = DataQualityEvaluator()
input_file = sys.argv[1]
output_file = sys.argv[2]

doc_count = 0
passed_count = 0
score_dist = {'excellent': 0, 'good': 0, 'fair': 0, 'poor': 0}

with open(input_file) as f, open(output_file, 'w') as out:
    for line in f:
        try:
            doc = json.loads(line)
            text = doc.get('text', '')
            
            result = evaluator.evaluate_document(text)
            score_dist[result['quality_level']] += 1
            
            if result['passed']:
                out.write(line)
                passed_count += 1
            
            doc_count += 1
        except:
            pass

print(f'✓ 质量评分完成:')
print(f'  通过: {passed_count} ({passed_count/doc_count*100:.1f}%)')
print(f'  分布:')
for level, count in score_dist.items():
    print(f'    {level}: {count} ({count/doc_count*100:.1f}%)')
EOF

python "$TEMP_DIR/quality_scorer.py" "$CLEANED_DIR/length_filtered.jsonl" "$CLEANED_DIR/quality_filtered.jsonl"

# 步骤 6: 统计和验证
echo "6️⃣  最终统计..."
python -c "
import json

final_file = '$CLEANED_DIR/quality_filtered.jsonl'

doc_count = 0
total_chars = 0
total_tokens = 0  # 近似: 4 字符 ≈ 1 token

with open(final_file) as f:
    for line in f:
        try:
            doc = json.loads(line)
            text = doc.get('text', '')
            doc_count += 1
            total_chars += len(text)
            total_tokens += len(text) // 4
        except:
            pass

print(f'✓ 最终数据统计:')
print(f'  文档数: {doc_count:,}')
print(f'  总字符: {total_chars:,} ({total_chars/1e9:.1f}B)')
print(f'  总 tokens: {total_tokens:,} ({total_tokens/1e9:.1f}B)')
print(f'  平均文档: {total_chars/doc_count:.0f} 字符')

# 生成最终清单
output = {
    'input_files': 1,
    'output_documents': doc_count,
    'output_chars': total_chars,
    'output_tokens': total_tokens,
    'quality': 'production_ready'
}

import json
with open('$CLEANED_DIR/manifest.json', 'w') as f:
    json.dump(output, f, indent=2)
"

echo ""
echo "✅ 数据清洗流程完成!"
echo "输出目录: $CLEANED_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

---

## 🔍 自动化质量检查

### 持续质量监控

```python
# quality_monitor.py

import json
import hashlib
from collections import defaultdict
import numpy as np

class QualityMonitor:
    def __init__(self):
        self.metrics = defaultdict(list)
        self.seen_hashes = set()
    
    def monitor_batch(self, documents, batch_id):
        """监控一批文档的质量"""
        
        results = {
            'batch_id': batch_id,
            'total_docs': len(documents),
            'valid_docs': 0,
            'issues': [],
            'metrics': {}
        }
        
        for i, doc in enumerate(documents):
            doc_result = self._check_document(doc)
            
            if doc_result['valid']:
                results['valid_docs'] += 1
            else:
                results['issues'].append({
                    'doc_index': i,
                    'reasons': doc_result['issues']
                })
        
        # 计算批次统计
        results['metrics']['valid_ratio'] = results['valid_docs'] / len(documents)
        results['metrics']['duplicate_rate'] = self._check_duplicates(documents)
        results['metrics']['avg_length'] = self._avg_length(documents)
        
        return results
    
    def _check_document(self, doc):
        """检查单个文档"""
        
        issues = []
        
        if not isinstance(doc, dict):
            issues.append('Not a dict')
            return {'valid': False, 'issues': issues}
        
        if 'text' not in doc:
            issues.append('Missing text field')
            return {'valid': False, 'issues': issues}
        
        text = doc['text']
        
        # 检查 1: 长度
        if len(text) < 100:
            issues.append(f'Too short: {len(text)} chars')
        elif len(text) > 100000:
            issues.append(f'Too long: {len(text)} chars')
        
        # 检查 2: 空白比例
        whitespace_ratio = sum(1 for c in text if c.isspace()) / len(text)
        if whitespace_ratio > 0.5:
            issues.append(f'Too much whitespace: {whitespace_ratio:.1%}')
        
        # 检查 3: 可打印字符
        printable_ratio = sum(1 for c in text if c.isprintable()) / len(text)
        if printable_ratio < 0.9:
            issues.append(f'Non-printable chars: {(1-printable_ratio):.1%}')
        
        # 检查 4: 重复行
        lines = text.split('\n')
        if len(lines) > 10:
            unique_lines = len(set(lines))
            if unique_lines / len(lines) < 0.7:
                issues.append(f'Repetitive lines: {unique_lines}/{len(lines)}')
        
        return {'valid': len(issues) == 0, 'issues': issues}
    
    def _check_duplicates(self, documents):
        """检查重复率"""
        hashes = []
        for doc in documents:
            if 'text' in doc:
                text = doc['text']
                h = hashlib.md5(text.encode()).hexdigest()
                hashes.append(h)
                self.seen_hashes.add(h)
        
        unique_hashes = len(set(hashes))
        return (1 - unique_hashes / len(hashes)) if hashes else 0
    
    def _avg_length(self, documents):
        """平均长度"""
        lengths = [len(doc.get('text', '')) for doc in documents]
        return np.mean(lengths) if lengths else 0
    
    def generate_report(self):
        """生成质量报告"""
        return {
            'total_seen': len(self.seen_hashes),
            'monitored_batches': len(self.metrics['batch_id']),
            'avg_quality': np.mean(self.metrics['quality']) if self.metrics['quality'] else 0
        }


# 使用示例
monitor = QualityMonitor()

# 监控来自不同来源的数据批次
batches = [
    {'source': 'common_crawl', 'data': [...]},
    {'source': 'wikipedia', 'data': [...]},
    {'source': 'github', 'data': [...]},
]

for batch in batches:
    result = monitor.monitor_batch(batch['data'], batch_id=batch['source'])
    print(f"\n{batch['source']}:")
    print(f"  Valid: {result['valid_docs']}/{result['total_docs']} ({result['metrics']['valid_ratio']:.1%})")
    print(f"  Duplicates: {result['metrics']['duplicate_rate']:.1%}")
    print(f"  Avg Length: {result['metrics']['avg_length']:.0f} chars")

print("\n", monitor.generate_report())
```

---

## 🔗 数据融合策略

### 如何组合多个数据源

```python
# data_fusion.py

import json
import random
from collections import defaultdict

class DataFusionPipeline:
    def __init__(self, target_tokens=3e12, seed=42):
        """
        目标: 3T tokens 的高质量训练数据
        
        策略:
        1. 按质量评分排序
        2. 按领域均衡采样
        3. 去重和去噪
        """
        self.target_tokens = target_tokens
        random.seed(seed)
        self.sources = {}
        self.domain_distribution = {}
    
    def add_source(self, source_name, file_path, domain, quality_score):
        """添加数据源"""
        self.sources[source_name] = {
            'path': file_path,
            'domain': domain,
            'quality': quality_score,
            'tokens': self._count_tokens(file_path)
        }
    
    def _count_tokens(self, file_path):
        """快速估算文件的 token 数"""
        try:
            with open(file_path) as f:
                total_chars = sum(len(line) for line in f)
            return total_chars // 4  # 粗略估算
        except:
            return 0
    
    def compute_allocation(self):
        """计算各数据源的采样比例"""
        
        # 按质量和领域分配
        allocations = {}
        
        # 优先级 1: 超高质量数据 (Wikipedia, ArXiv)
        high_quality = {
            name: source for name, source in self.sources.items()
            if source['quality'] > 0.9
        }
        
        # 优先级 2: 高质量数据 (CC-100, The Pile)
        good_quality = {
            name: source for name, source in self.sources.items()
            if 0.7 < source['quality'] <= 0.9
        }
        
        # 优先级 3: 中等质量数据 (GitHub Code)
        fair_quality = {
            name: source for name, source in self.sources.items()
            if 0.5 < source['quality'] <= 0.7
        }
        
        # 分配比例: 优先级数据占更大比例
        allocations['priority_1'] = 0.40  # 40% - 超高质量
        allocations['priority_2'] = 0.35  # 35% - 高质量
        allocations['priority_3'] = 0.25  # 25% - 中等质量
        
        # 在每个优先级内均匀分配
        result = {}
        
        for priority, ratio in allocations.items():
            if priority == 'priority_1':
                sources = high_quality
            elif priority == 'priority_2':
                sources = good_quality
            else:
                sources = fair_quality
            
            tokens_per_source = (self.target_tokens * ratio) / len(sources)
            
            for source_name, source_info in sources.items():
                result[source_name] = tokens_per_source
        
        return result
    
    def fuse_data(self, output_file):
        """融合多个数据源"""
        
        allocations = self.compute_allocation()
        
        print("📊 数据融合分配:")
        for source, tokens in allocations.items():
            print(f"  {source}: {tokens/1e9:.1f}B tokens")
        
        # 按比例采样并融合
        sources_list = list(allocations.items())
        
        with open(output_file, 'w') as out:
            doc_count = 0
            token_count = 0
            
            # 轮流从各源采样 (保证均衡)
            for source_name, target_tokens in sources_list:
                file_path = self.sources[source_name]['path']
                
                # 计算采样比例
                source_tokens = self._count_tokens(file_path)
                sample_ratio = target_tokens / source_tokens if source_tokens > 0 else 0
                
                print(f"\n处理 {source_name} (采样率: {sample_ratio:.1%})...")
                
                with open(file_path) as f:
                    for line in f:
                        if random.random() < sample_ratio:
                            try:
                                doc = json.loads(line)
                                out.write(line)
                                doc_count += 1
                                token_count += len(doc.get('text', '')) // 4
                            except:
                                pass
        
        print(f"\n✅ 融合完成:")
        print(f"  文档数: {doc_count:,}")
        print(f"  Token 数: {token_count/1e9:.1f}B")


# 使用示例
pipeline = DataFusionPipeline(target_tokens=3e12)

# 添加数据源
sources = [
    ('common_crawl', 'cc100_extracted.jsonl', 'web', 0.75),
    ('wikipedia', 'wikipedia_all.jsonl', 'encyclopedia', 0.95),
    ('the_pile', 'the_pile.jsonl', 'mixed', 0.85),
    ('github_code', 'github_code.jsonl', 'code', 0.80),
    ('arxiv', 'arxiv_papers.jsonl', 'academic', 0.92),
]

for name, path, domain, quality in sources:
    pipeline.add_source(name, path, domain, quality)

# 融合
pipeline.fuse_data('data/fused_training_data.jsonl')
```

---

## 💰 成本与时间估算

```python
# cost_calculator.py

class DataAcquisitionCostCalculator:
    
    SOURCES_COST = {
        'common_crawl': {
            'raw_size_gb': 750,
            's3_download_cost': 100,
            'compute_cost': 50,
            'time_days': 3,
            'quality': 0.75
        },
        'wikipedia': {
            'raw_size_gb': 80,
            's3_download_cost': 5,
            'compute_cost': 10,
            'time_days': 0.5,
            'quality': 0.95
        },
        'the_pile': {
            'raw_size_gb': 800,
            's3_download_cost': 500,
            'compute_cost': 100,
            'time_days': 4,
            'quality': 0.85
        },
        'github_code': {
            'raw_size_gb': 1300,
            'bigquery_cost': 500,
            'compute_cost': 150,
            'time_days': 5,
            'quality': 0.80
        },
        'arxiv': {
            'raw_size_gb': 200,
            's3_download_cost': 50,
            'compute_cost': 20,
            'time_days': 2,
            'quality': 0.92
        },
    }
    
    def calculate_total_cost(self):
        """计算总成本"""
        total_cost = {
            'storage': 0,
            'compute': 0,
            'total': 0,
            'time_days': 0
        }
        
        for source, costs in self.SOURCES_COST.items():
            storage = costs.get('s3_download_cost', 0) + costs.get('bigquery_cost', 0)
            compute = costs.get('compute_cost', 0)
            
            total_cost['storage'] += storage
            total_cost['compute'] += compute
            total_cost['time_days'] += costs['time_days']
        
        total_cost['total'] = total_cost['storage'] + total_cost['compute']
        
        return total_cost
    
    def print_breakdown(self):
        """打印成本明细"""
        print("="*60)
        print("📊 数据获取成本分析")
        print("="*60)
        print("\n按来源细分:")
        print("-"*60)
        print(f"{'来源':<20} {'大小':>10} {'成本':>10} {'质量':>8} {'时间':>8}")
        print("-"*60)
        
        total_size = 0
        total_cost = 0
        
        for source, costs in self.SOURCES_COST.items():
            size = costs['raw_size_gb']
            cost = costs.get('s3_download_cost', 0) + costs.get('bigquery_cost', 0) + costs.get('compute_cost', 0)
            quality = costs['quality']
            time = costs['time_days']
            
            total_size += size
            total_cost += cost
            
            print(f"{source:<20} {size:>9}GB ${cost:>9} {quality:>7.0%} {time:>7.1f}d")
        
        print("-"*60)
        print(f"{'总计':<20} {total_size:>9}GB ${total_cost:>9} {'-':>8} {'-':>8}")
        print("="*60)
        
        print("\n💰 成本总结:")
        print(f"  存储费用: ${sum(c.get('s3_download_cost', 0) + c.get('bigquery_cost', 0) for c in self.SOURCES_COST.values())}")
        print(f"  计算费用: ${sum(c.get('compute_cost', 0) for c in self.SOURCES_COST.values())}")
        print(f"  总费用: ${total_cost:,}")
        print(f"  总时间: {sum(c['time_days'] for c in self.SOURCES_COST.values()):.1f} 天")
        
        print("\n💡 成本优化建议:")
        print("  1. 使用预留容量 (RI) 节省 40% 计算成本")
        print("  2. 在 CloudFlare 或类似服务缓存数据")
        print("  3. 利用学术优惠计划 (AWS Educate)")
        print("  4. 考虑直接与数据提供方合作")


# 运行计算
calculator = DataAcquisitionCostCalculator()
calculator.print_breakdown()
```

**成本估算结果**:
- 存储费用: ~$1,155
- 计算费用: ~$330
- **总费用**: ~$1,500 (可通过优化节省 30-50%)
- **总时间**: ~15 天 (并行采集可减少到 5-7 天)

---

## ✅ 高质量数据检查清单

```bash
□ 数据来源多元化 (至少 5 个不同来源)
□ 去重率 > 99%
□ 垃圾内容过滤 > 95%
□ 自然语言质量 > 90%
□ 长度分布适当 (100-100K 字符)
□ 多语言覆盖 (如需要)
□ 领域均衡分配
□ 文档级别质量评分 > 0.6
□ 自动化质量监控系统就位
□ 定期采样人工审核 (5-10%)
□ 数据完整性备份
□ 许可证和合规性检查
```

---

**关键要点总结**:

🎯 **质量优先于数量**: 2T tokens 高质量数据 > 5T tokens 低质量数据
🔄 **持续监控**: 建立自动化质量检查系统
🌍 **多源融合**: 组合不同领域的数据获得均衡
💰 **成本控制**: 总成本约 $1,500 (可接受)
⏱️ **时间效率**: 15 天采集，5-7 天并行采集

现在准备好获取高质量数据了吗？🚀
