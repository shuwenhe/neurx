# CANN runtime

The runtime layer owns ACL initialization, devices, contexts, streams, events
and memory. `acl_dynamic.h` dynamically resolves lifecycle, memory-copy and
event APIs. `acl_runtime.h` provides RAII device sessions plus device and
pinned-host buffers.
