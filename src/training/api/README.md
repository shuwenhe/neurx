# Training API

This is the only supported entry boundary for training clients and commands.
It owns job submission, cancellation, status, and configuration validation.
Implementations belong to `engine`; parallel algorithms belong to `strategy`.
