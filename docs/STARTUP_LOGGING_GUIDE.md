# NeurX Startup Logging Guide

## Overview

The `make pretrain` command now provides **real-time progress feedback** during all startup phases. This prevents the appearance of the program "hanging" while initialization is in progress.

## Startup Phases and Log Markers

### Phase 1: Program Start & Configuration Loading
```
[STARTUP][runner] minimal_train.s started
[STARTUP][init] loading configuration...
[STARTUP][init] configuration loaded
[STARTUP][init] validating paths...
[STARTUP][init] initializing training parameters...
```

**What's happening:**
- Process has started and is loading environment variables
- Reading configuration from `.env` and NEURX config files
- Validating that required paths exist

**Expected output in ~1-2 seconds**

### Phase 2: Manifest Verification
```
[STARTUP][manifest] ✓ manifest found
```

**What's happening:**
- Checking that the training manifest file exists
- This is the index of all training shards

**Expected output in ~1 second**

### Phase 3: Shard Discovery & Scanning
```
[STARTUP][shard-scan] 📋 loading pre-generated shard list
[STARTUP][shard-scan] 🔍 shard list empty; scanning directory
[STARTUP][shard-scan] searching for shard files in: /path/to/shard
[STARTUP][shard-scan] directory scan complete
[STARTUP][shard-scan] 📊 analyzing shard list
[STARTUP][shard-scan] found 1234 total shards
```

**What's happening:**
- Loading the list of shard files from disk
- If pre-generated list doesn't exist, scanning the shard directory
- Counting total number of shards available

**Expected output in ~2-5 seconds** (depends on filesystem speed)

### Phase 4: Shard Validation
```
[STARTUP][shard-validate] 🔍 validating shard files
  [1/1234] ✓ /path/to/shard/shard_00000.jsonl
  [2/1234] ✓ /path/to/shard/shard_00001.jsonl
  [3/1234] ✓ /path/to/shard/shard_00002.jsonl
  [4/1234] ✓ /path/to/shard/shard_00003.jsonl
  [5/1234] ✓ /path/to/shard/shard_00004.jsonl
  [6/1234] ✓ /path/to/shard/shard_00005.jsonl
  ... (1228 more shards not shown)
[STARTUP][shard-validate] ✓ validation complete: 6/6 checked
```

**What's happening:**
- Checking that shard files are accessible (exists and readable)
- Shows first 6 shards as preview
- Verifies file permissions before training begins

**Expected output in ~1-2 seconds**

### Phase 5: Training Loop Entry
```
[STARTUP][training] 🚀 entering main training loop with 1234 shards
```

**What's happening:**
- All startup checks passed
- Now beginning the actual training loop
- You should start seeing shard processing logs immediately after this

**Total startup time: 5-10 seconds** depending on shard count and filesystem

## Real Training Logs

Once training begins, you'll see logs like:

```
🔹 [SHARD PROCESSING] Starting shard_00000
📥 [READING] shard_00000.jsonl (doc 0-100)
📊 [PROGRESS] shard_00000: token_count=51200
✅ [COMPLETE] shard_00000 - 100 docs, 51200 tokens
✓ Flushing checkpoint for shard_00000
```

See [SHARD_PROGRESS_QUICK_REFERENCE.md](SHARD_PROGRESS_QUICK_REFERENCE.md) for full log format details.

## Filtering Logs by Stage

To see only startup logs:
```bash
make pretrain 2>&1 | grep "\[STARTUP\]"
```

To see only shard processing logs:
```bash
make pretrain 2>&1 | grep "\[SHARD\|[READING]\|[PROGRESS]\|[COMPLETE]"
```

To see the full output with timestamps:
```bash
make pretrain 2>&1 | ts '[%H:%M:%S]'
```

## Troubleshooting Startup Issues

### "Hanging" at shard scan phase
- **Cause:** Large shard directory with slow filesystem
- **Solution:** Pre-generate shard list with `neurx/scripts/generate_shard_list.sh`

### "Many ✗ marks in validation phase"
- **Cause:** Missing or inaccessible shard files
- **Solution:** Check file permissions: `ls -la /path/to/shard/` and `df -h`

### No output appearing
- **Cause:** Buffered output, or shell not configured for real-time
- **Solution:** Use: `make pretrain 2>&1 | cat`

### Slow manifest or shard loading
- **Cause:** Network filesystem (NFS) latency
- **Solution:** 
  - Copy data to local SSD if possible
  - Increase timeout in `run_large_pretrain.sh`

## Configuration Environment Variables

These control startup behavior:

```bash
# Shard discovery
NEURX_PRETRAIN_SHARD_LIST_FILE    # Pre-generated list (optional)
NEURX_PRETRAIN_SHARD_DIR          # Location of shard files
NEURX_PRETRAIN_MANIFEST           # Manifest file path

# Output
NEURX_PRETRAIN_OUTPUT_DIR         # Where to save checkpoints
NEURX_PRETRAIN_LOG_INTERVAL       # How often to log progress
```

See [neurx.config.example.toml](neurx.config.example.toml) for full list.

## Log Output Destinations

- **Configuration & Stage Messages:** stdout (visible immediately)
- **Detailed Phase Logs:** stderr (via `>&2` redirection)
- **Training Progress:** Both stdout and log file
- **Full Log Archive:** `/path/to/run_large_pretrain_TIMESTAMP.log`

All log markers use color and emojis for quick visual scanning.
