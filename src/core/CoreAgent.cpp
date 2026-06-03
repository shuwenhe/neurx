#include "CoreAgent.h"

// The destructor serves as the key function for the vtable
// and provides a translation unit for MOC signals.
// CoreAgent::~CoreAgent() is already = default in header,
// but we define it here to ensure the vtable is emitted.
// Actually, let's just define a dummy virtual to be safe if needed,
// but signals are the main issue.
