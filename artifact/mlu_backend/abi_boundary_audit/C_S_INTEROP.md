# C and S interoperability

The seed shared-library generator exports S `int` as C `int64_t` and emits a thread-local `s_abi_last_error` accessor. An execution failure in the generated wrapper returns zero. The adapter checks the accessor and validates status values before returning an ABI `int`. It never narrows an arbitrary S value. Calls through the adapter are serialized because the hosted interpreter resets its shared scheduler on entry. Direct calls to the companion's private S entry points are outside the supported interface.

The original S code declared `dlopen` as returning `int`. Inspection of the existing S runtime showed the hosted FFI interprets integer returns as signed 32-bit values after calling through a uintptr-based dispatcher. The original path could truncate a loader pointer on x86-64 and pass a corrupt value to `dlclose`.

The typed POSIX helper is the transport for the loader observation. Its `void*` stays entirely in C from `dlopen` to `dlclose`. S classifies the scalar outcome and owns the zero-availability and operation-rejection policy. C holds the callback table, lock, and static diagnostic strings. The helper resolves no vendor API symbols. There are no CNRT, CNNL, or CNCL function calls.

The current exporter cannot safely carry vendor pointers, output-parameter addresses, or function-pointer tables through hosted S integer FFI. A future vendor binding needs a typed interface before adding device resources. The private ELF symbol names and loader statuses are implementation details outside v1.
