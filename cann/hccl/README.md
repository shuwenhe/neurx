# HCCL communication backend

`hccl_dynamic.h` provides a deployment-time HCCL loader for tensor-parallel all-reduce, all-gather and reduce-scatter. It keeps non-Ascend development hosts buildable while returning an explicit error when `libhccl` is absent.

Communicator creation belongs to the distributed launcher because rank tables and device topology are deployment inputs. The inference adapter receives the resulting opaque communicator and ACL stream.

The Ascend310P3 serving configuration uses independent single-card replicas and
does not put HCCL on the inference path. This loader is retained for supported
training devices and for separately validated distributed deployments.
