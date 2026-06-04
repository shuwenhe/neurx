# CMake Build Integration for Codex File System
# Add to neurx-code/src/CMakeLists.txt

# File System Module - Codex-style implementation
set(NEURX_FILESYSTEM_SOURCES
    filesystem/ExecutorFileSystem.h
    filesystem/DirectFileSystem.h
    filesystem/DirectFileSystem.cpp
    filesystem/SandboxedFileSystem.h
    filesystem/SandboxedFileSystem.cpp
    filesystem/LocalFileSystem.h
    filesystem/LocalFileSystem.cpp
    filesystem/CODEX_FILE_SYSTEM_GUIDE.md
)

# Tools Module - Codex File System Tool
set(NEURX_CODEX_TOOLS_SOURCES
    tools/CodexFileSystemTool.h
    tools/CodexFileSystemTool.cpp
)

# Add to main neurx-code target
target_sources(neurx-code PRIVATE
    ${NEURX_FILESYSTEM_SOURCES}
    ${NEURX_CODEX_TOOLS_SOURCES}
)

# Link Qt modules
target_link_libraries(neurx-code
    Qt6::Core
    Qt6::Gui
    neurx_core
)

# Compiler flags for C++17 or later (required for std::pair structured bindings)
set_target_properties(neurx-code PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)

# Optional: Use C++20 for more features
# set_property(TARGET neurx-code PROPERTY CXX_STANDARD 20)
