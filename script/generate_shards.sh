#!/bin/bash
set -e

# Data Shard Generator Script
# Generates distributed training shards from training_data.jsonl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
SOURCE_FILE="$DATA_DIR/training_data.jsonl"
SHARD_DIR="$DATA_DIR/training_data_shards"
MANIFEST_FILE="$SHARD_DIR/manifest.json"

# Configuration
SHARD_SIZE="${SHARD_SIZE:-1024}"  # Records per shard
NUM_WORKERS="${NUM_WORKERS:-10}"

echo "════════════════════════════════════════════════════════════════"
echo "📊 Data Shard Generator"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Step 1: Verify source file
echo "▶ Checking source data file..."
if [ ! -f "$SOURCE_FILE" ]; then
    echo "✗ Source file not found: $SOURCE_FILE"
    exit 1
fi

TOTAL_RECORDS=$(wc -l < "$SOURCE_FILE")
echo "✓ Source file found: $SOURCE_FILE"
echo "  Total records: $TOTAL_RECORDS"
echo ""

# Step 2: Create shard directory
echo "▶ Setting up shard directory..."
mkdir -p "$SHARD_DIR"
echo "✓ Shard directory: $SHARD_DIR"
echo ""

# Step 3: Generate shards
echo "▶ Generating shards..."
echo "  Shard size: $SHARD_SIZE records"
echo "  Number of shards: $NUM_WORKERS"
echo ""

# Split source file into shards
split -l $SHARD_SIZE "$SOURCE_FILE" "$SHARD_DIR/shard_tmp_"

SHARD_INDEX=0
for shard_file in $(ls "$SHARD_DIR"/shard_tmp_* | sort); do
    SHARD_NUM=$(printf "%05d" $SHARD_INDEX)
    SHARD_NAME="training_data-${SHARD_NUM}.jsonl.gz"
    SHARD_PATH="$SHARD_DIR/$SHARD_NAME"
    
    # Compress shard
    gzip -c "$shard_file" > "$SHARD_PATH"
    
    # Count records in shard
    SHARD_RECORDS=$(wc -l < "$shard_file")
    
    echo "  ✓ Shard $SHARD_NUM: $SHARD_NAME ($SHARD_RECORDS records)"
    
    # Cleanup temp file
    rm "$shard_file"
    
    SHARD_INDEX=$((SHARD_INDEX + 1))
done

TOTAL_SHARDS=$SHARD_INDEX
echo "✓ Generated $TOTAL_SHARDS shards"
echo ""

# Step 4: Generate manifest.json
echo "▶ Generating manifest.json..."

# Create manifest
cat > "$MANIFEST_FILE" << EOF
{
  "dataset_name": "training_data",
  "source_path": "$SOURCE_FILE",
  "output_dir": "$SHARD_DIR",
  "total_records": $TOTAL_RECORDS,
  "shard_count": $TOTAL_SHARDS,
  "shard_size_target": $SHARD_SIZE,
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "shards": [
EOF

# Add shard entries
SHARD_INDEX=0
CURRENT_RECORD=0
for shard_file in $(ls "$SHARD_DIR"/training_data-*.jsonl.gz | sort); do
    SHARD_NAME=$(basename "$shard_file")
    SHARD_RECORDS=$(gzip -cd "$shard_file" | wc -l)
    START_RECORD=$CURRENT_RECORD
    END_RECORD=$((CURRENT_RECORD + SHARD_RECORDS - 1))
    
    # Calculate SHA256
    SHA256=$(sha256sum "$shard_file" | awk '{print $1}')
    
    # Add comma if not last entry
    if [ $SHARD_INDEX -lt $((TOTAL_SHARDS - 1)) ]; then
        COMMA=","
    else
        COMMA=""
    fi
    
    cat >> "$MANIFEST_FILE" << EOF
    {
      "file": "$SHARD_NAME",
      "records": $SHARD_RECORDS,
      "start_record": $START_RECORD,
      "end_record": $END_RECORD,
      "sha256": "$SHA256"
    }$COMMA
EOF
    
    CURRENT_RECORD=$((CURRENT_RECORD + SHARD_RECORDS))
    SHARD_INDEX=$((SHARD_INDEX + 1))
done

cat >> "$MANIFEST_FILE" << EOF
  ]
}
EOF

echo "✓ Manifest created: $MANIFEST_FILE"
echo ""

# Step 5: Verification
echo "▶ Verification..."
echo "  Source records: $TOTAL_RECORDS"
echo "  Shards created: $TOTAL_SHARDS"
echo "  Total sharded records: $CURRENT_RECORD"

if [ "$TOTAL_RECORDS" -eq "$CURRENT_RECORD" ]; then
    echo "  ✓ Record count matches"
else
    echo "  ⚠ Warning: Record count mismatch!"
    echo "    Expected: $TOTAL_RECORDS, Got: $CURRENT_RECORD"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Shard generation complete!"
echo "  Location: $SHARD_DIR"
echo "════════════════════════════════════════════════════════════════"
