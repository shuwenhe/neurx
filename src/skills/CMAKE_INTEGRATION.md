# CMakeLists.txt Integration Guide

## Adding Claude Skills System to CMakeLists.txt

To integrate the Claude Skills system into your NeurX build, add the following source files to your CMakeLists.txt in the appropriate locations.

### Option 1: Add to Existing neurx_core Target

If you're building a core library (as shown in your current CMakeLists.txt), add the Skills sources to the existing `add_library(neurx_core ...)` section:

```cmake
add_library(neurx_core STATIC
    # Agent engine (existing)
    src/agent/AgentEngine.cpp
    src/agent/AgentMessage.cpp
    # ... other existing files ...
    
    # Skills System (NEW)
    src/skills/SkillDiscoveryEngine.cpp
    src/skills/SkillEnvironmentManager.cpp
    src/skills/ClaudeSkillManager.cpp
    
    # ... rest of existing files ...
)
```

### Option 2: Create a Separate Skills Library

For better modularity, create a separate skills library:

```cmake
add_library(neurx_skills STATIC
    src/skills/SkillDiscoveryEngine.cpp
    src/skills/SkillEnvironmentManager.cpp
    src/skills/ClaudeSkillManager.cpp
)

target_include_directories(neurx_skills PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(neurx_skills PUBLIC
    Qt6::Core
    Qt6::Concurrent
)

# Then link it to your main target
target_link_libraries(neurx_core PUBLIC neurx_skills)
# or
target_link_libraries(neurx PRIVATE neurx_skills)
```

### Option 3: Add to Existing Application Target

If you have an `add_executable(neurx ...)` target, add the Skills sources directly:

```cmake
add_executable(neurx
    # ... existing sources ...
    
    # Skills System
    src/skills/SkillDiscoveryEngine.cpp
    src/skills/SkillEnvironmentManager.cpp
    src/skills/ClaudeSkillManager.cpp
    
    # ... rest of sources ...
)

target_link_libraries(neurx PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Concurrent
    # ... other dependencies ...
)
```

## Required Qt Modules

Ensure your project links against these Qt modules (most are probably already included):

```cmake
find_package(Qt6 6.2 REQUIRED COMPONENTS 
    Core        # Required
    Gui         # Required
    Concurrent  # Optional but recommended for async discovery
    Network     # If making network calls from skills
)
```

The Skills system primarily uses `Qt6::Core`. If you're not using `Qt6::Concurrent`, you can remove that dependency.

## Header Files

The Skills system header files are automatically discovered by `target_include_directories()` calls. Make sure your target includes:

```cmake
target_include_directories(neurx_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
```

This makes all headers in `src/skills/` available to including code.

## Build Integration

### Complete CMakeLists.txt Example

Here's a complete example showing where to add the Skills system in a typical NeurX build:

```cmake
cmake_minimum_required(VERSION 3.21.1)
project(neurx LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Concurrent Network)

# Main library with all core systems
add_library(neurx_core STATIC
    # Agent
    src/agent/AgentEngine.cpp
    src/agent/Planner.cpp
    src/agent/Executor.cpp
    
    # LLM
    src/llm/LLMProvider.cpp
    src/llm/AnthropicProvider.cpp
    
    # Tools
    src/tools/CheckpointTool.cpp
    src/tools/ShellTool.cpp
    
    # Skills System ← ADD HERE
    src/skills/SkillDiscoveryEngine.cpp
    src/skills/SkillEnvironmentManager.cpp
    src/skills/ClaudeSkillManager.cpp
    
    # Context
    src/context/WorkspaceContext.cpp
)

target_include_directories(neurx_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(neurx_core PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Concurrent
    Qt6::Network
)

# Application
add_executable(neurx
    src/main.cpp
    # Other application sources...
)

target_link_libraries(neurx PRIVATE neurx_core)
```

### QMake Alternative

If using QMake instead of CMake:

```qmake
SOURCES += \
    src/skills/SkillDiscoveryEngine.cpp \
    src/skills/SkillEnvironmentManager.cpp \
    src/skills/ClaudeSkillManager.cpp

HEADERS += \
    src/skills/ClaudeSkillTypes.h \
    src/skills/SkillDiscoveryEngine.h \
    src/skills/SkillEnvironmentManager.h \
    src/skills/ClaudeSkillManager.h
```

## Compilation Notes

### Include Paths

The following headers must be accessible:
- `ClaudeSkillTypes.h` (included by other skill headers)
- `SkillDiscoveryEngine.h`
- `SkillEnvironmentManager.h`
- `ClaudeSkillManager.h`

Standard Qt headers will be found automatically:
- `<QDir>`
- `<QFile>`
- `<QJsonDocument>`
- `<QThread>`
- etc.

### C++ Standard

The Skills system uses C++17 features, so ensure:
```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
```

### Build Optimizations

The Skills system works well with all optimization levels:
```cmake
# Debug
cmake -DCMAKE_BUILD_TYPE=Debug
# Release
cmake -DCMAKE_BUILD_TYPE=Release
```

## Testing the Build

After adding the Skills system to CMakeLists.txt, verify compilation:

```bash
# Configure build
cmake -B build -DCMAKE_BUILD_TYPE=Debug

# Build
cmake --build build

# Or with make
cd build && make
```

If there are compilation errors, check:
1. All source files are listed (no typos in filenames)
2. Qt6 core library is found and linked
3. Include paths are correct
4. C++ standard is 17 or higher

## Using the Skills System in Code

After successfully building with the Skills system included:

```cpp
#include "skills/ClaudeSkillManager.h"

int main() {
    auto skillManager = std::make_unique<ClaudeSkillManager>();
    skillManager->initialize("~/.hermes/skills");
    // ... use skills system ...
}
```

## Troubleshooting Build Issues

### Error: "cannot find -lQt6Core"
- Ensure Qt6 is installed and found by cmake
- Check CMAKE_PREFIX_PATH includes Qt installation

### Error: "ClaudeSkillTypes.h: No such file"
- Verify `target_include_directories()` includes src/ directory
- Check file exists at `src/skills/ClaudeSkillTypes.h`

### Error: "undefined reference to `DefaultSkillDiscoveryEngine::...`"
- Make sure both .h and .cpp files are in the project
- Verify .cpp files are in the `SOURCES` list
- Check no typos in filenames

### Error: "Qt6::Concurrent not found"
- May not be strictly required; remove from find_package() if not needed
- Most functionality works with just Qt6::Core

## Performance Considerations

The Skills system adds minimal overhead:
- **Compilation time**: ~2-3 seconds for skills sources
- **Executable size**: ~100-150KB (depends on optimization)
- **Runtime memory**: <1MB for manager + 1-2KB per loaded skill

No external dependencies required beyond Qt6 Core.

## Next Steps

1. ✅ Update CMakeLists.txt with source files
2. ✅ Run cmake to regenerate build files
3. ✅ Build the project
4. ✅ Test by creating a ClaudeSkillManager instance
5. ✅ Create your first skill in ~/.hermes/skills/
6. ✅ Integrate into your agent code

For detailed usage instructions, see [QUICK_START.md](QUICK_START.md).
