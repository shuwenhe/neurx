# CANN runtime

The runtime layer owns ACL initialization, devices, contexts, streams, events and memory pools. `acl_dynamic.h` supplies the minimal dynamically loaded lifecycle used by the inference adapter; production builds may replace it with the matching vendor headers and link libraries.
