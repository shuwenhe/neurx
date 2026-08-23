# Training Engine

Owns the training state machine, step lifecycle, evaluation cadence, checkpoint
coordination, and failure recovery. It may use strategies, optimizers, data, and
runtime services, but must not depend on serving.
