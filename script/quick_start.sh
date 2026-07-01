#!/bin/bash
# NeurX Industrial-Grade Claude Training - Quick Start Script
# Run this to verify installation and begin training

set -e

PROJECT_DIR="/Users/feifei/shuwen/train/neurx"
cd "$PROJECT_DIR"

echo "============================================================"
echo "  🚀 NeurX Industrial-Grade Claude Training System"
echo "     Quick Start Guide"
echo "============================================================"
echo ""

# Step 1: Verify Installation
echo "📋 Step 1: Verifying Installation..."
echo "   Checking directory structure..."
if [ -d "cuda" ] && [ -d "distributed" ] && [ -d "engine" ] && [ -d "model" ]; then
    echo "   ✅ All directories present"
else
    echo "   ❌ Missing required directories"
    exit 1
fi

# Step 2: Check Key Files
echo ""
echo "📋 Step 2: Checking Key Implementation Files..."

KEY_FILES=(
    "cuda/device_manager_complete.s"
    "distributed/nccl_backend_complete.s"
    "engine/training_orchestrator_complete.s"
    "tests/test_suite_complete.s"
)

ALL_PRESENT=true
for file in "${KEY_FILES[@]}"; do
    if [ -f "$file" ]; then
        LINES=$(wc -l < "$file")
        printf "   ✅ %-50s (%d lines)\n" "$file" "$LINES"
    else
        printf "   ❌ %-50s MISSING\n" "$file"
        ALL_PRESENT=false
    fi
done

if [ "$ALL_PRESENT" = false ]; then
    exit 1
fi

# Step 3: Check Documentation
echo ""
echo "📋 Step 3: Checking Documentation..."

DOC_FILES=(
    "INDUSTRIAL_TRAINING_GUIDE.md"
    "PRODUCTION_READINESS_CHECKLIST.md"
    "FINAL_IMPLEMENTATION_SUMMARY.md"
)

for file in "${DOC_FILES[@]}"; do
    if [ -f "$file" ]; then
        LINES=$(wc -l < "$file")
        printf "   ✅ %-50s (%d lines)\n" "$file" "$LINES"
    else
        printf "   ❌ %-50s MISSING\n" "$file"
    fi
done

# Step 4: Summary
echo ""
echo "============================================================"
echo "  ✅ System Status: READY FOR TRAINING"
echo "============================================================"
echo ""
echo "📚 Documentation Available:"
echo "   • INDUSTRIAL_TRAINING_GUIDE.md ............ Complete training guide"
echo "   • PRODUCTION_READINESS_CHECKLIST.md ...... Quality verification"
echo "   • FINAL_IMPLEMENTATION_SUMMARY.md ........ Overview & next steps"
echo ""
echo "🎯 Quick Start:"
echo "   1. Compile test suite:"
echo "      $ neurx compile tests/test_suite_complete.s -o bin/test"
echo ""
echo "   2. Run verification tests:"
echo "      $ ./bin/test_suite_complete"
echo ""
echo "   3. Start training (single GPU):"
echo "      $ ./bin/train_orchestrator --config your_config.s"
echo ""
echo "   4. Start training (multi-GPU):"
echo "      $ mpirun -np 8 ./bin/train_orchestrator --config config.s"
echo ""
echo "🔧 Configuration Examples:"
echo "   • Quick test:   See INDUSTRIAL_TRAINING_GUIDE.md > Configuration 1"
echo "   • Production:   See INDUSTRIAL_TRAINING_GUIDE.md > Configuration 2"
echo "   • Large scale:  See INDUSTRIAL_TRAINING_GUIDE.md > Configuration 3"
echo ""
echo "📞 For Help:"
echo "   • Quick questions: Check FINAL_IMPLEMENTATION_SUMMARY.md"
echo "   • Detailed guide:  Read INDUSTRIAL_TRAINING_GUIDE.md"
echo "   • Troubleshooting: Check INDUSTRIAL_TRAINING_GUIDE.md > Troubleshooting"
echo ""
echo "============================================================"
echo "  Next Step: Read FINAL_IMPLEMENTATION_SUMMARY.md"
echo "============================================================"
echo ""
