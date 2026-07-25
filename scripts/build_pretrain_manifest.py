#!/usr/bin/env python3
import os, json, glob
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
shard_dir = os.environ.get('NEURX_PRETRAIN_SHARD_DIR', os.path.join(root, 'dataset', 'pretrain', 'shard'))
manifest_file = os.environ.get('NEURX_PRETRAIN_MANIFEST', os.path.join(root, 'dataset', 'pretrain', 'manifest.json'))
shards = sorted(glob.glob(os.path.join(shard_dir, 'shard_*.jsonl')))
if not shards:
    print('no shards found in', shard_dir)
    exit(1)
shard_entries = []
total_docs = 0
total_bytes = 0
for p in shards:
    try:
        with open(p, 'rb') as f:
            lines = sum(1 for _ in f)
            size = os.path.getsize(p)
    except Exception as e:
        print('skipping', p, 'error', e)
        continue
    shard_entries.append({
        'shard_id': os.path.basename(p),
        'file_path': p,
        'num_documents': lines,
        'size_bytes': size,
    })
    total_docs += lines
    total_bytes += size
manifest = {
    'dataset_name': 'neurx-pretrain-wikipedia',
    'version': '1.0',
    'source_dir': shard_dir,
    'shards': shard_entries,
    'total_shards': len(shard_entries),
    'total_documents': total_docs,
    'total_size_bytes': total_bytes,
    'average_docs_per_shard': (total_docs // len(shard_entries)) if shard_entries else 0,
}
os.makedirs(os.path.dirname(manifest_file), exist_ok=True)
with open(manifest_file, 'w') as f:
    json.dump(manifest, f, indent=2)
print('wrote manifest', manifest_file)
