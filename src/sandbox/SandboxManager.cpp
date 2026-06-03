#include "SandboxManager.h"

// The destructor and signals require a translation unit for MOC.
// SandboxManager::~SandboxManager() is defined as = default in the header,
// but having this .cpp file ensures the vtable and signals are emitted.
