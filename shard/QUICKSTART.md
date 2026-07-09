#!/usr/bin/env bash
# Quick Reference: NeurX Shard Module Organization
# ============================================================================

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                 NeurX Shard Module - Quick Reference                      ║
╚═══════════════════════════════════════════════════════════════════════════╝

📦 DIRECTORY STRUCTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  neurx/
    ├── shard/                      ← New: Dedicated shard module
    │   ├── shard.sh               ← New: Unified CLI (main entry)
    │   ├── README.md              ← New: Complete documentation
    │   ├── shard_wikipedia_enwiki.py
    │   ├── shard_enwiki.s/.sh
    │   ├── shard_manager.s
    │   ├── data_shard.s
    │   └── [other shard utilities]
    │
    ├── script/                    ← Contains other utilities
    ├── Makefile                   ← Updated to use shard/


🎯 QUICK START
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Via Makefile (Original):
  $ make shard                    # Python implementation
  $ make shard-enwiki            # S implementation
  $ make shard-s                 # Full S pipeline

Via Unified CLI (New):
  $ ./shard/shard.sh wikipedia   # Shard Wikipedia dump
  $ ./shard/shard.sh verify      # Verify shards
  $ ./shard/shard.sh list        # List shards
  $ ./shard/shard.sh clean       # Clean up
  $ ./shard/shard.sh help        # Show help


🔧 SHARD DIRECTORY CONTENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Core Implementations:
  ✓ shard_wikipedia_enwiki.py    Python - Main Wikipedia sharding
  ✓ shard_wikipedia.s            S language - High-performance version
  ✓ shard_enwiki.s/.sh          Alternative S/shell implementations

Management & Utilities:
  ✓ shard_manager.s              Shard management (size, metadata)
  ✓ data_shard.s                 Generate shards from datasets
  ✓ verify_shards.s              Validate shard integrity
  ✓ test_shard.s                 Testing utilities
  ✓ load_shards.sh               Load shard metadata
  ✓ generate_shards.sh           Legacy generation script

CLI & Documentation:
  ✓ shard.sh                     Main entry point (NEW!)
  ✓ README.md                    Complete documentation (NEW!)


📊 STATISTICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total Files:    12 files
  Python:          1 file (shard_wikipedia_enwiki.py)
  S Language:      7 files (*.s files)
  Shell Scripts:   3 files (*.sh files)
  Documentation:   2 files (README.md, this file)
  
  Total Size:     ~150 KB
  
  Commit:         6a7bb9a (feat: Create shard directory...)


🚀 USAGE EXAMPLES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Shard Wikipedia Dump:
   $ cd /home/shuwen/shuwen/train/neurx
   $ ./shard/shard.sh wikipedia --docs-per-shard 5000
   
   Or via Makefile:
   $ make shard

2. Verify Shards:
   $ ./shard/shard.sh verify
   
   Output:
   ✓ shard_00000.jsonl: 5000 documents
   ✓ shard_00001.jsonl: 5000 documents
   ...

3. List Shards:
   $ ./shard/shard.sh list
   
   Output:
   Shard File                 Lines       Size (MB)
   ────────────────────────── ───────────  ──────────────
   shard_00000.jsonl          5000         128
   shard_00001.jsonl          5000         131
   ...
   TOTAL                      42000        5368

4. Clean Shards:
   $ ./shard/shard.sh clean


📝 ENVIRONMENT VARIABLES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Required (optional with defaults):
  NEURX_HOME                  Project root (default: .)
  ENWIKI_BZ2_FILE             Wikipedia dump (default: ...)
  ENWIKI_SHARD_DIR            Output dir (default: ...)
  ENWIKI_MANIFEST_FILE        Manifest file (default: ...)
  
Optional:
  DOCS_PER_SHARD              Docs per shard (default: 5000)
  MAX_PAGES                   Max pages to process (default: 0=unlimited)


📖 DOCUMENTATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Full Documentation:
  $ cat shard/README.md                # Complete guide with examples
  $ ./shard/shard.sh help              # CLI help message

Source Files:
  $ cat shard/shard.sh                 # Main CLI implementation
  $ cat shard/shard_wikipedia_enwiki.py # Python sharding logic


✨ KEY IMPROVEMENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Organized:      All shard code in dedicated directory
✓ Discoverable:   Easy to find all shard utilities
✓ Unified CLI:    Single entry point for all operations
✓ Well-Documented: Comprehensive README with examples
✓ Backward Compatible: Makefile still works as before
✓ Easy Maintenance: Clear separation of concerns
✓ Extensible:     Easy to add new shard strategies


🔗 RELATED RESOURCES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Documentation:
  shard/README.md                 Complete module documentation
  ../README.md                    Main project README
  ../S_IMPLEMENTATION_GUIDE.md    S language implementation guide
  ../MAKE_TRAIN_QUICKSTART.md     Training quick start

Makefile Targets:
  make shard                      Shard Wikipedia (Python)
  make shard-enwiki               Shard Wikipedia (Shell/S)
  make shard-s                    Full S pipeline
  make data-pipeline-s            Complete data pipeline

EOF
