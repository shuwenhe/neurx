# neurx-train

Stable training executable boundary. It validates `src/training/api` contracts
and launches the compatible pretrain or posttrain target from validated
environment configuration.

Start from `configs/training/train.example`; inject secrets through the runtime
environment rather than committed configuration.
