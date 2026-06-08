#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Editor File Synchronization Test
# 测试编辑器文件同步功能
# ═══════════════════════════════════════════════════════════════════════════

TEST_FILE="/tmp/editor-sync-test.cc"

echo "═══════════════════════════════════════════════════════════════════════════"
echo "Editor File Synchronization Test"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Step 1: Create test file
echo "Step 1: Creating test file..."
cat > "$TEST_FILE" << 'EOF'
#include <iostream>

int main() {
    std::cout << "Original content" << std::endl;
    return 0;
}
EOF

echo "✓ Test file created: $TEST_FILE"
echo ""

# Step 2: Show initial content
echo "Step 2: Initial file content:"
echo "─────────────────────────────────────────────────────────────────"
cat "$TEST_FILE"
echo "─────────────────────────────────────────────────────────────────"
echo ""

# Step 3: Modify file externally (simulating WriteTool)
echo "Step 3: Simulating external modification (WriteTool)..."
echo "Adding a new function to the file..."
cat >> "$TEST_FILE" << 'EOF'

void displayMessage() {
    std::cout << "Modified by external tool" << std::endl;
}
EOF

echo "✓ File modified externally"
echo ""

# Step 4: Show updated content
echo "Step 4: Updated file content:"
echo "─────────────────────────────────────────────────────────────────"
cat "$TEST_FILE"
echo "─────────────────────────────────────────────────────────────────"
echo ""

# Step 5: File statistics
echo "Step 5: File Statistics:"
echo "  • File size: $(du -h "$TEST_FILE" | cut -f1)"
echo "  • Line count: $(wc -l < "$TEST_FILE")"
echo "  • Last modified: $(stat -f '%Sm' "$TEST_FILE" 2>/dev/null || stat --format='%y' "$TEST_FILE" 2>/dev/null)"
echo ""

echo "═══════════════════════════════════════════════════════════════════════════"
echo "Test Summary"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "When integrated into neurx-code:"
echo ""
echo "1. User opens $TEST_FILE in editor"
echo "   → FileWatcher starts monitoring the file"
echo ""
echo "2. External tool modifies the file"
echo "   → FileWatcher detects the modification"
echo ""
echo "3. File modification is detected"
echo "   → onWatchedFileModified() reloads content"
echo ""
echo "4. Editor automatically updates"
echo "   → currentFileContentChanged() signal emitted"
echo "   → EditorPanel.qml syncFromAgent() triggered"
echo "   → User sees updated content"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "✓ Test Complete"
echo "═══════════════════════════════════════════════════════════════════════════"

# Cleanup
rm -f "$TEST_FILE"

