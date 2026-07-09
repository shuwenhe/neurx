#!/bin/bash
# quick_data_acquisition.sh
# 快速数据获取脚本 - 一键下载多个高质量数据源

set -e

DATA_ROOT="${1:-.}/data/pretrain_dataset/raw"
mkdir -p "$DATA_ROOT"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        🌍 高质量数据快速获取脚本                               ║"
echo "║     (High-Quality Data Acquisition Script)                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 函数: 下载并解析
download_source() {
    local name=$1
    local command=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📥 获取数据源: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    eval "$command" && echo "✅ $name 完成" || echo "⚠️  $name 失败 (跳过)"
}

# 选项菜单
echo "选择要下载的数据源 (支持多选, 用空格分隔):"
echo ""
echo "1️⃣  Common Crawl (750GB, 0.75质量) - 推荐"
echo "2️⃣  Wikipedia (80GB, 0.95质量) - 强烈推荐"
echo "3️⃣  The Pile (800GB, 0.85质量) - 推荐"
echo "4️⃣  GitHub Code (1.3TB, 0.80质量) - 可选"
echo "5️⃣  ArXiv Papers (200GB, 0.92质量) - 推荐"
echo "6️⃣  All (全部下载)"
echo ""
read -p "输入选择 [1-6 或组合]: " selection

case "$selection" in
    1|"1 "*|*" 1"*|*" 1 "*|6)
        echo ""
        echo "⚠️  Common Crawl 数据很大，需要 AWS 账户和 750GB 存储空间"
        read -p "是否继续? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            download_source "Common Crawl" "
                pip install warc3-wet >/dev/null 2>&1
                echo '下载 CC-100 样本 (仅前 100 文件)...'
                cd '$DATA_ROOT'
                aws s3 ls s3://commoncrawl/crawl-data/CC-MAIN-2024-01/ --no-sign-request 2>/dev/null | \
                    grep -E 'wet\.paths' | head -1 | awk '{print \$4}' | \
                    xargs -I {} aws s3 cp s3://commoncrawl/{} . --no-sign-request
                echo '✓ Downloaded'
            "
        fi
        ;;
esac

case "$selection" in
    2|"2 "*|*" 2"*|*" 2 "*|6)
        download_source "Wikipedia" "
            cd '$DATA_ROOT' && \
            python3 << 'WIKI_EOF'
from datasets import load_dataset
import json

print('📚 Downloading Wikipedia...')
for lang_code in ['en', 'zh']:
    configs_to_try = [f'20220301.{lang_code}', '20220301', lang_code, 'default']
    dataset = None
    for cfg in configs_to_try:
        try:
            dataset = load_dataset('wikipedia', cfg, split='train', streaming=True)
            print(f'  Using config: {cfg}')
            break
        except Exception:
            continue

    if dataset is None:
        print(f'✗ No usable config for language {lang_code}, skipping.')
        continue

    output_file = f'wikipedia_{lang_code}.jsonl'
    count = 0
    with open(output_file, 'w') as f:
        for doc in dataset:
            text = doc.get('text') if isinstance(doc, dict) else str(doc)
            title = doc.get('title') if isinstance(doc, dict) else ''
            output = {
                'text': text,
                'title': title,
                'language': lang_code,
                'source': 'wikipedia'
            }
            f.write(json.dumps(output, ensure_ascii=False) + '\n')
            count += 1

            if count % 10000 == 0:
                print(f'  [{lang_code}] {count} documents...')

            if count >= 500000:  # 限制 50 万条用于演示
                break

    print(f'✓ Wikipedia {lang_code}: {count} documents saved')
WIKI_EOF
        "
        ;;
esac

case "$selection" in
    3|"3 "*|*" 3"*|*" 3 "*|6)
        download_source "The Pile" "
            cd '$DATA_ROOT' && \
            python3 << 'PILE_EOF'
from datasets import load_dataset
import json

print('📦 Downloading The Pile (sample)...')
try:
    dataset = load_dataset('the_pile', split='train', streaming=True)
    output_file = 'the_pile.jsonl'
    count = 0
    
    with open(output_file, 'w') as f:
        for doc in dataset:
            output = {
                'text': doc['text'],
                'meta': doc.get('meta', {}),
                'source': 'the_pile'
            }
            f.write(json.dumps(output, ensure_ascii=False) + '\n')
            count += 1
            
            if count % 50000 == 0:
                print(f'  {count} documents...')
            
            if count >= 500000:  # 50 万条用于演示
                break
    
    print(f'✓ The Pile: {count} documents saved')
except Exception as e:
    print(f'✗ The Pile: {e}')
PILE_EOF
        "
        ;;
esac

case "$selection" in
    4|"4 "*|*" 4"*|*" 4 "*|6)
        download_source "GitHub Code" "
            cd '$DATA_ROOT' && \
            python3 << 'CODE_EOF'
from datasets import load_dataset
import json

print('💻 Downloading GitHub Code (sample)...')
try:
    dataset = load_dataset('code_search_net', 'python', split='train', streaming=True)
    output_file = 'github_code_python.jsonl'
    count = 0
    
    with open(output_file, 'w') as f:
        for doc in dataset:
            output = {
                'text': doc['whole_func_string'],
                'language': 'python',
                'source': 'github'
            }
            f.write(json.dumps(output, ensure_ascii=False) + '\n')
            count += 1
            
            if count % 10000 == 0:
                print(f'  {count} functions...')
            
            if count >= 100000:  # 10 万条用于演示
                break
    
    print(f'✓ GitHub Code: {count} functions saved')
except Exception as e:
    print(f'✗ GitHub Code: {e}')
CODE_EOF
        "
        ;;
esac

case "$selection" in
    5|"5 "*|*" 5"*|*" 5 "*|6)
        download_source "ArXiv Papers" "
            cd '$DATA_ROOT' && \
            python3 << 'ARXIV_EOF'
import requests
import json
from time import sleep

print('📖 Downloading ArXiv papers...')

categories = ['cs.AI', 'cs.LG', 'math.CO', 'physics.QM', 'stat.ML']
papers = []

for category in categories:
    url = 'http://export.arxiv.org/api/query'
    params = {
        'search_query': f'cat:{category}',
        'start': 0,
        'max_results': 10000,
        'sortBy': 'submittedDate',
        'sortOrder': 'descending'
    }
    
    try:
        print(f'  Fetching {category}...')
        response = requests.get(url, params=params, timeout=30)
        
        for entry in response.entries[:5000]:  # 每类 5000 篇
            paper = {
                'title': entry.title,
                'summary': entry.summary,
                'text': f'{entry.title}\n\n{entry.summary}',
                'category': category,
                'source': 'arxiv'
            }
            papers.append(paper)
        
        print(f'    ✓ {len(papers)} papers so far')
    except Exception as e:
        print(f'    ✗ Error: {e}')
    
    sleep(3)  # 遵守 API 速率限制

with open('arxiv_papers.jsonl', 'w') as f:
    for paper in papers:
        f.write(json.dumps(paper, ensure_ascii=False) + '\n')

print(f'✓ ArXiv Papers: {len(papers)} papers saved')
ARXIV_EOF
        "
        ;;
esac

# 总结
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 数据获取统计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

total_files=$(find "$DATA_ROOT" -name "*.jsonl" 2>/dev/null | wc -l)
total_size=$(du -sh "$DATA_ROOT" 2>/dev/null | cut -f1)
total_lines=$(find "$DATA_ROOT" -name "*.jsonl" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')

echo ""
echo "✅ 完成统计:"
echo "  JSONL 文件数: $total_files"
echo "  总大小: $total_size"
echo "  总行数: $(printf '%d' "$total_lines")"
echo "  预估 tokens: $(( total_lines * 4 / 1000000000 ))B"
echo ""
echo "📁 数据位置: $DATA_ROOT"
echo ""
echo "👉 下一步:"
echo "  1. 运行质量检查: bash script/clean_data.sh"
echo "  2. 生成分片: make shard"
echo "  3. 启动训练: make train"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
