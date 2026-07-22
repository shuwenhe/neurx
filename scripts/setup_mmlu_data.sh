#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${NEURX_ROOT:-.}"
DATA_ROOT="${NEURX_MMLU_DATA_ROOT:${PROJECT_ROOT}/data/mmlu}"
MMLU_HF_REPO="cais/mmlu"
SPLIT_MODE="${1:-standard}"

echo "========================================="
echo "MMLU Dataset Downloader"
echo "========================================="
echo ""
echo "Configuration:"
echo "  Project root: ${PROJECT_ROOT}"
echo "  Data root: ${DATA_ROOT}"
echo "  HF repo: ${MMLU_HF_REPO}"
echo "  Split mode: ${SPLIT_MODE}"
echo ""

echo "[Step 1] Creating data directories..."
mkdir -p "${DATA_ROOT}/test"
mkdir -p "${DATA_ROOT}/dev"
mkdir -p "${DATA_ROOT}/validation"
mkdir -p "${DATA_ROOT}/auxiliary"
echo "  ✓ Directories created"
echo ""

echo "[Step 2] Downloading MMLU dataset from HuggingFace..."

if ! command -v python3 &> /dev/null; then
    echo "  ✗ Python 3 not found. Please install Python 3 and huggingface-hub."
    exit 1
fi

python3 << 'EOF'
import os
import sys
from pathlib import Path

try:
    from datasets import load_dataset
except ImportError:
    print("  ! Installing huggingface-hub and datasets...")
    os.system("pip install -q huggingface-hub datasets")
    from datasets import load_dataset

data_root = os.environ.get('DATA_ROOT', './data/mmlu')
Path(data_root).mkdir(parents=True, exist_ok=True)

print("  Downloading MMLU from HuggingFace...")
print("")

tasks = [

    "abstract_algebra", "anatomy", "astronomy", "biology", "chemistry",
    "computer_science", "formal_logic", "high_school_biology", "high_school_chemistry",
    "high_school_computer_science", "high_school_mathematics", "high_school_physics",
    "high_school_statistics", "machine_learning", "mathematics", "medical_genetics",
    "physics", "professional_medicine", "virology",

    "econometrics", "high_school_geography", "high_school_government_and_politics",
    "high_school_macroeconomics", "high_school_microeconomics", "high_school_psychology",
    "human_sexuality", "international_law", "jurisprudence", "logical_fallacies",
    "management", "marketing", "moral_disputes",

    "ancient_greek", "art_history", "high_school_european_history",
    "high_school_us_history", "literature_in_english", "world_religions",

    "business_ethics", "clinical_knowledge", "college_biology", "college_chemistry",
    "college_computer_science", "college_mathematics", "college_medicine",
    "college_physics", "conceptual_physics", "prehistory", "professional_accounting",
    "professional_law", "public_relations", "security_studies", "sociology",
    "us_foreign_policy", "virology"
]

for task in tasks:
    try:

        dataset = load_dataset("cais/mmlu", task, split=None)

        if "test" in dataset:
            test_df = dataset["test"].to_pandas()
            test_path = os.path.join(data_root, "test", f"{task}.csv")
            test_df.to_csv(test_path, index=False)
            print(f"  ✓ {task}: test ({len(test_df)} items)")

        if "dev" in dataset:
            dev_df = dataset["dev"].to_pandas()
            dev_path = os.path.join(data_root, "dev", f"{task}.csv")
            dev_df.to_csv(dev_path, index=False)
            print(f"         dev ({len(dev_df)} items)")

        if "validation" in dataset:
            val_df = dataset["validation"].to_pandas()
            val_path = os.path.join(data_root, "validation", f"{task}.csv")
            val_df.to_csv(val_path, index=False)

    except Exception as e:
        print(f"  ! Warning: Failed to download {task}: {e}")
        continue

print("")
print("  ✓ Download complete")
EOF

echo ""

echo "[Step 3] Verifying data integrity..."

test_count=$(find "${DATA_ROOT}/test" -name "*.csv" | wc -l)
dev_count=$(find "${DATA_ROOT}/dev" -name "*.csv" | wc -l)

echo "  Test files: ${test_count}"
echo "  Dev files: ${dev_count}"

if [ ${test_count} -ge 50 ] && [ ${dev_count} -ge 50 ]; then
    echo "  ✓ Data integrity verified"
else
    echo "  ! Warning: Some data may be missing"
fi
echo ""

echo "[Step 4] Generating dataset statistics..."

python3 << 'EOF'
import os
import pandas as pd
from pathlib import Path

data_root = os.environ.get('DATA_ROOT', './data/mmlu')

stats = {
    "test": {"count": 0, "tasks": 0},
    "dev": {"count": 0, "tasks": 0}
}

for csv_file in Path(f"{data_root}/test").glob("*.csv"):
    try:
        df = pd.read_csv(csv_file)
        stats["test"]["count"] += len(df)
        stats["test"]["tasks"] += 1
    except:
        pass

for csv_file in Path(f"{data_root}/dev").glob("*.csv"):
    try:
        df = pd.read_csv(csv_file)
        stats["dev"]["count"] += len(df)
        stats["dev"]["tasks"] += 1
    except:
        pass

print(f"  Test set:  {stats['test']['count']:,} questions across {stats['test']['tasks']} tasks")
print(f"  Dev set:   {stats['dev']['count']:,} examples across {stats['dev']['tasks']} tasks")
print(f"  Total:     {stats['test']['count'] + stats['dev']['count']:,} items")
EOF

echo ""

echo "[Step 5] Creating dataset metadata..."

cat > "${DATA_ROOT}/METADATA.txt" << 'EOF'
MMLU Dataset
============

Downloaded from: https://huggingface.co/datasets/cais/mmlu

Task Coverage:
  - STEM (19 tasks): abstract_algebra, anatomy, astronomy, biology, chemistry,
                     computer_science, formal_logic, high_school_*, machine_learning,
                     mathematics, medical_genetics, physics, professional_medicine, virology

  - Social Science (13 tasks): econometrics, high_school_geography,
                               high_school_government_and_politics,
                               high_school_macro/microeconomics, high_school_psychology,
                               human_sexuality, international_law, jurisprudence,
                               logical_fallacies, management, marketing, moral_disputes

  - Humanities (8 tasks): ancient_greek, art_history, high_school_european_history,
                          high_school_us_history, literature_in_english, world_religions

  - Other (17 tasks): business_ethics, clinical_knowledge, college_*,
                      conceptual_physics, prehistory, professional_accounting,
                      professional_law, public_relations, security_studies,
                      sociology, us_foreign_policy, virology

Data Splits:
  - test/: Main evaluation set (~1K-5K questions per task)
  - dev/: Development/few-shot set (5 examples per task)
  - validation/: Auxiliary validation split

Citation:
  @article{hendrycks2020measuring,
    title={Measuring Massive Multitask Language Understanding},
    author={Hendrycks, Dan and Burns, Collin and Basart, Steven and Zou, Andy
            and Mazeika, Mantas and Song, Dawn and Steinhardt, Jacob},
    journal={arXiv preprint arXiv:2009.03300},
    year={2020}
  }
EOF

echo "  ✓ Metadata created"
echo ""

echo "========================================="
echo "MMLU Setup Complete"
echo "========================================="
echo ""
echo "Dataset location: ${DATA_ROOT}"
echo ""
echo "Next steps:"
echo "  1. Run MMLU evaluation:"
echo "     export NEURX_MMLU_DATA_ROOT='${DATA_ROOT}'"
echo "     s run eval/run_mmlu_benchmark.s"
echo ""
echo "  2. Integrate with training:"
echo "     See eval/README_MMLU.md for integration guide"
echo ""
