#!/bin/bash
cd /Users/feifei/shuwen
git add neurx/ops/vectorization.s neurx/training/mixed_precision.s neurx/training/gradient_accumulation.s neurx/distributed/tensor_parallel.s neurx/test/test_advanced_features.s neurx/ADVANCED_FEATURES_GUIDE.md ADVANCED_FEATURES_UPDATE.md ADVANCED_FEATURES_COMPLETION.md
git commit -m "Add 4 advanced training features: vectorization, mixed precision, gradient accumulation, tensor parallelism"
git push origin main
