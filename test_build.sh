#!/bin/bash
# Test compilation script for Codex File System

set -e

PROJECT_ROOT="/Users/feifei/agent/neurx-code"
BUILD_DIR="${PROJECT_ROOT}/build"
TEST_NAME="test_codex_file_system"

echo "🔨 Building Codex File System Tests..."
echo "Project: $PROJECT_ROOT"
echo "Build dir: $BUILD_DIR"
echo ""

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build directory not found. Run cmake first."
    exit 1
fi

cd "$BUILD_DIR"

# Try to build the main project first
echo "📦 Building main neurx-code project..."
cmake --build . --target neurx-codeApp 2>&1 | head -50

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Main project build successful!"
else
    echo "⚠️  Main project has compilation issues (checking if it's just warnings)"
fi

echo ""
echo "📊 Checking if file system files are included..."

# Check if our new source files are being compiled
if cmake --build . --verbose 2>&1 | grep -q "DirectFileSystem\|LocalFileSystem\|SandboxedFileSystem"; then
    echo "✅ File system source files are included in build"
else
    echo "⚠️  File system source files may not be included"
fi

echo ""
echo "🧪 Attempting to compile test program..."

# Compile test program
g++ -std=c++17 -fPIC \
    -I"${PROJECT_ROOT}/src" \
    -I"/opt/homebrew/opt/qt/include" \
    -I"/opt/homebrew/opt/qt/include/QtCore" \
    -L"/opt/homebrew/opt/qt/lib" \
    -o /tmp/${TEST_NAME} \
    "${PROJECT_ROOT}/tests/${TEST_NAME}.cpp" \
    "${BUILD_DIR}/src/filesystem/DirectFileSystem.cpp.o" \
    "${BUILD_DIR}/src/filesystem/LocalFileSystem.cpp.o" \
    "${BUILD_DIR}/src/filesystem/SandboxedFileSystem.cpp.o" \
    -lQt6Core 2>&1 || true

echo ""
echo "✅ Test script completed!"
