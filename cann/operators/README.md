# CANN operator wrappers

This directory owns ACLNN/ATB/Graph Engine wrappers and shape/workspace
selection. A production shared library implements `operator_abi.h`, exports ABI
version 1 plus prefill/decode launchers, and preserves asynchronous execution on
the supplied ACL stream.

The launcher receives the loaded `Nxtrfmv2Model` through `batch.model` and the
worker `PagedKvCache` through `batch.kv_cache`. It populates `batch.logits`
without synchronizing the whole device.
