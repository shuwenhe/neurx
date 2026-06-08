import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtQuick.Window 6.2
import NeurXCode

// ── EditorPanel ──────────────────────────────────────────────────────────────
//  Center editor for the currently opened local file.

Item {
    id: root

    required property var agent

    property var pendingCloseQueue: []
    property bool continuePendingCloseAfterDialog: false
    property int pendingCloseIndex: -1
    property string pendingCloseName: ""
    property string pendingClosePath: ""
    property bool syncingEditorFromAgent: false
    property bool previewMode: false
    property bool diffMode: false
    property string originalContent: ""
    property bool isMarkdown: agent.currentFilePath ? agent.currentFilePath.endsWith(".md") : false
    property bool autoSave: false
    property bool autoClosingPairs: true
    property bool autoIndent: true
    property bool autoHighlightBrackets: true
    property bool wordWrap: false
    property int cursorLine: 1
    property int cursorColumn: 1
    property int lineCount: Math.max(1, agent.currentFileContent.length > 0 ? agent.currentFileContent.split("\n").length : 1)
    property int gutterDigits: Math.max(2, String(root.lineCount).length)
    property int gutterWidth: Math.max(48, Math.ceil(editorFontMetrics.averageCharacterWidth * gutterDigits) + 18)

    property var bracketHighlightPos: null
    property string hoverContent: ""

    function syncFromAgent(resetView) {
        if (editorArea && (editorArea.text !== agent.currentFileContent || resetView)) {
            syncingEditorFromAgent = true
            editorArea.text = agent.currentFileContent
            if (resetView) {
                editorArea.cursorPosition = 0
                // editorArea is hosted inside a ScrollView; reset the ScrollView's content offsets
                // ScrollView exposes its internal flickable as `contentItem`.
                // Use contentItem.contentX/contentY to manipulate scroll offsets.
                const flickable = editorFlickable()
                if (flickable) {
                    flickable.contentX = 0
                    flickable.contentY = 0
                }
            }
            syncingEditorFromAgent = false
        }
        updateCursorMetrics()
    }

    function updateCursorMetrics() {
        if (!editorArea)
            return

        const cursorText = editorArea.text.slice(0, editorArea.cursorPosition)
        const parts = cursorText.split("\n")
        root.cursorLine = Math.max(1, parts.length)
        root.cursorColumn = Math.max(1, parts[parts.length - 1].length + 1)
    }

    function lineFromIndex(text, position) {
        const prefix = text.slice(0, Math.max(0, position))
        return Math.max(1, prefix.split("\n").length)
    }

    function editorCursorY() {
        if (!agent.currentFilePath || !editorArea)
            return 0

        const rect = editorArea.positionToRectangle(editorArea.cursorPosition)
        return rect.y
    }

    function editorFlickable() {
        return editorScrollView && editorScrollView.contentItem ? editorScrollView.contentItem : null
    }

    function syncSelectionToAgent() {
        if (!agent.currentFilePath || !editorArea) {
            agent.clearCurrentSelection()
            return
        }

        const hasSelection = editorArea.selectedText && editorArea.selectedText.length > 0
        if (!hasSelection) {
            agent.clearCurrentSelection()
            return
        }

        const startLine = root.lineFromIndex(editorArea.text, editorArea.selectionStart)
        const endLine = root.lineFromIndex(editorArea.text, editorArea.selectionEnd)
        agent.setCurrentSelection(
            agent.currentFilePath,
            editorArea.selectedText,
            startLine,
            Math.max(startLine, endLine)
        )
    }

    Connections {
        target: agent
        function onCurrentFilePathChanged() { root.syncFromAgent(true) }
        function onCurrentFileContentChanged() { root.syncFromAgent() }
        function onOpenFilesChanged() {
            if (agent.currentFilePath)
                root.syncFromAgent()
        }
    }

    Shortcut {
        sequence: StandardKey.Save
        context: Qt.WindowShortcut
        enabled: !!agent.currentFilePath
        onActivated: saveCurrentFile()
    }

    Shortcut {
        sequence: "Ctrl+Shift+\\"
        context: Qt.WindowShortcut
        enabled: !!agent.currentFilePath
        onActivated: root.jumpToMatchingBracket()
    }

    Shortcut {
        sequence: "Ctrl+Delete"
        context: Qt.WindowShortcut
        enabled: !!agent.currentFilePath
        onActivated: root.deleteWordForward()
    }

    Shortcut {
        sequence: "Ctrl+Backspace"
        context: Qt.WindowShortcut
        enabled: !!agent.currentFilePath
        onActivated: root.deleteWordBackward()
    }

    Shortcut {
        sequence: "Ctrl+Shift+U"
        context: Qt.WindowShortcut
        enabled: !!agent.currentFilePath
        onActivated: root.transformSelection(0)
    }

    Shortcut {
        sequence: "Ctrl+Shift+L"
        context: Qt.WindowShortcut
        enabled: !!agent.currentFilePath
        onActivated: root.transformSelection(1)
    }

    Shortcut {
        sequence: "Ctrl+/"
        context: Qt.WindowShortcut
        enabled: !!agent.currentFilePath
        onActivated: root.toggleComment()
    }

    function toggleComment() {
        if (!editorArea || !commentManager)
            return false

        const range = currentSelectionRange()
        const startLine = range ? root.lineFromIndex(editorArea.text, range.start) : root.cursorLine
        const endLine = range ? root.lineFromIndex(editorArea.text, range.end) : root.cursorLine

        // Use a default language if unknown
        const lang = agent.currentFilePath ? agent.currentFilePath.split('.').pop() : "cpp"
        commentManager.toggleLineComment(startLine - 1, endLine - 1, lang)

        // The commentManager usually triggers a signal that syncs back,
        // but let's make sure we refresh if needed.
        return true
    }

    function saveCurrentFile() {
        if (!agent.currentFilePath)
            return
        agent.currentFileContent = editorArea.text
        agent.saveCurrentFile()
        root.syncFromAgent()
    }

    function writeCurrentFileWithCodex() {
        if (!agent.currentFilePath)
            return
        agent.writeFileWithCodex(agent.currentFilePath, editorArea.text)
    }

    Timer {
        id: autoSaveTimer
        interval: 2000
        running: root.autoSave && agent.currentFileDirty
        repeat: true
        onTriggered: {
            if (agent.currentFileDirty && !agent.busy) {
                saveCurrentFile()
            }
        }
    }

    function findInFile(pattern) {
        if (!editorArea || !pattern) return
        const index = editorArea.text.indexOf(pattern, editorArea.cursorPosition)
        if (index !== -1) {
            editorArea.cursorPosition = index
            editorArea.select(index, index + pattern.length)
            editorArea.forceActiveFocus()
        } else {
            // Wrap around
            const index2 = editorArea.text.indexOf(pattern, 0)
            if (index2 !== -1) {
                editorArea.cursorPosition = index2
                editorArea.select(index2, index2 + pattern.length)
                editorArea.forceActiveFocus()
            }
        }
    }

    function goToLine(line) {
        if (!agent.currentFilePath || !editorArea)
            return

        const lines = editorArea.text.split("\n")
        let position = 0
        const targetLine = Math.max(1, Math.min(line, lines.length))
        for (let i = 0; i < targetLine - 1; i++) {
            position += lines[i].length + 1 // +1 for newline
        }

        editorArea.cursorPosition = position
        editorArea.forceActiveFocus()

        // Ensure the line is visible
        const rect = editorArea.positionToRectangle(position)
        const flickable = editorFlickable()
        if (flickable) {
            const viewportHeight = flickable.height
            const targetY = rect.y - viewportHeight / 2
            flickable.contentY = Math.max(0, Math.min(targetY, flickable.contentHeight - viewportHeight))
        }
    }

    function closeDiff() {
        if (!root.diffMode)
            return
        root.diffMode = false
        root.originalContent = ""
    }

    function highlightBrackets() {
        if (!editorArea || !bracketMatcher || !root.autoHighlightBrackets) {
            root.bracketHighlightPos = null
            return
        }

        const candidates = [
            { line: root.cursorLine - 1, column: root.cursorColumn - 1 },
            { line: root.cursorLine - 1, column: root.cursorColumn - 2 }
        ]

        for (let i = 0; i < candidates.length; ++i) {
            const pos = candidates[i]
            if (pos.line < 0 || pos.column < 0)
                continue

            const info = bracketMatcher.matchingBracketAt(editorArea.text, pos.line, pos.column)
            if (info && info.hasMatch) {
                const openIndex = indexFromLineColumn(editorArea.text, info.openLine, info.openColumn)
                const closeIndex = indexFromLineColumn(editorArea.text, info.closeLine, info.closeColumn)
                root.bracketHighlightPos = [openIndex, closeIndex]
                bracketHighlightTimer.restart()
                return
            }
        }

        root.bracketHighlightPos = null
    }

    function indexFromLineColumn(text, line, column) {
        const lines = text.split("\n")
        if (lines.length === 0)
            return 0
        const clampedLine = Math.max(0, Math.min(line, lines.length - 1))
        let index = 0
        for (let i = 0; i < clampedLine; ++i)
            index += lines[i].length + 1
        return index + Math.max(0, Math.min(column, lines[clampedLine].length))
    }

    function currentLineColumn0Based() {
        return {
            line: Math.max(0, root.cursorLine - 1),
            column: Math.max(0, root.cursorColumn - 1)
        }
    }

    function showHover(line, column) {
        if (!editorArea || !agent || !agent.currentFilePath) {
            root.hoverContent = ""
            hoverPopup.close()
            return
        }

        const hover = agent.requestHover(agent.currentFilePath, line, column)
        if (!hover) {
            root.hoverContent = ""
            hoverPopup.close()
            return
        }

        const parts = []
        if (hover.contents)
            parts.push(hover.contents)
        if (hover.markedString)
            parts.push(hover.markedString)

        root.hoverContent = parts.length > 0 ? parts.join("\n\n") : ""
        if (root.hoverContent.length > 0) {
            hoverPopup.open()
        } else {
            hoverPopup.close()
        }
    }

    function currentSelectionRange() {
        if (!editorArea || !editorArea.selectedText || editorArea.selectedText.length === 0)
            return null
        const start = Math.min(editorArea.selectionStart, editorArea.selectionEnd)
        const end = Math.max(editorArea.selectionStart, editorArea.selectionEnd)
        return { start, end }
    }

    function currentWordRange() {
        if (!editorArea || !wordOperations)
            return null

        const pos = currentLineColumn0Based()
        const bounds = wordOperations.wordBoundsAt(editorArea.text, pos.line, pos.column)
        if (!bounds || !bounds.hasWord)
            return null

        const start = indexFromLineColumn(editorArea.text, bounds.startLine, bounds.startColumn)
        const end = indexFromLineColumn(editorArea.text, bounds.endLine, bounds.endColumn)
        if (end <= start)
            return null
        return { start, end }
    }

    function currentEditableRange() {
        return currentSelectionRange() || currentWordRange()
    }

    function replaceRange(start, end, replacement) {
        if (!editorArea || start < 0 || end < start)
            return false

        const boundedStart = Math.max(0, Math.min(start, editorArea.text.length))
        const boundedEnd = Math.max(boundedStart, Math.min(end, editorArea.text.length))
        editorArea.remove(boundedStart, boundedEnd)
        if (replacement && replacement.length > 0)
            editorArea.insert(boundedStart, replacement)
        editorArea.cursorPosition = boundedStart + replacement.length
        editorArea.forceActiveFocus()
        Qt.callLater(() => root.syncSelectionToAgent())
        return true
    }

    function transformSelection(styleId) {
        if (!editorArea || !caseConverter)
            return false

        const range = currentEditableRange()
        if (!range)
            return false

        const original = editorArea.text.slice(range.start, range.end)
        const converted = caseConverter.convertText(original, styleId)
        if (converted === original)
            return false

        return replaceRange(range.start, range.end, converted)
    }

    function formatDocument() {
        if (!agent.currentFilePath || !editorArea)
            return

        const edits = agent.formatDocument(agent.currentFilePath, {"tabSize": 4, "insertSpaces": true})
        if (edits && edits.length > 0) {
            // Edits usually come ordered from end to start to avoid index shifts,
            // but let's assume they might not be and sort them descending by offset
            const sortedEdits = [...edits].sort((a, b) => b.offset - a.offset)

            // If the provider returns standard LSP TextEdits (range/newText),
            // we'd need more logic. But if it's simpler edits...
            // Let's check what m_formatDocumentProvider->execute(ctx) returns.
        } else {
            // If the provider directly modified the file or returns nothing,
            // we just reload. Most simple implementation:
            agent.saveCurrentFile() // Ensure current changes are on disk
            // Call the formatter (which might change the file on disk or just return text)
            // For now, let's assume it might have changed the file or we need to sync.
            root.syncFromAgent(true)
        }
    }

    function goToReferences() {
        if (!agent.currentFilePath || !editorArea)
            return

        const pos = currentLineColumn0Based()
        const results = agent.findAllReferences(agent.currentFilePath, pos.line + 1, pos.column + 1)

        if (results && results.length > 0) {
            // Bridge to search panel
            if (typeof searchPanel !== "undefined") {
                agentTabs.currentIndex = 1 // Switch to search tab
                searchPanel.searchText = "References"
                searchPanel.results = results.map(res => ({
                    file: res.file,
                    line: res.line,
                    content: res.lineText || "Reference",
                    fullPath: res.file.startsWith("/") ? res.file : agent.workspacePath + "/" + res.file
                }))
            }
        } else {
            agent.notifyInfo("No references found.")
        }
    }

    function executeEditorCommand(commandId) {
        if (!editorArea || !editorCommandBridge)
            return false

        const pos = currentLineColumn0Based()
        editorCommandBridge.executeCommand(commandId, editorArea.text, pos.line + 1, pos.column + 1)
        return true
    }

    Connections {
        target: editorCommandBridge
        function onCommandResultReady(commandId, result) {
            if (result.changedText !== undefined && result.changedText !== editorArea.text) {
                const oldCursorPos = editorArea.cursorPosition
                editorArea.text = result.changedText

                // Try to restore cursor position or move it if the command specifies
                if (result.cursorLine !== undefined && result.cursorColumn !== undefined) {
                    editorArea.cursorPosition = indexFromLineColumn(result.changedText, result.cursorLine - 1, result.cursorColumn - 1)
                } else {
                    editorArea.cursorPosition = Math.min(oldCursorPos, result.changedText.length)
                }

                editorArea.forceActiveFocus()
                Qt.callLater(() => root.syncSelectionToAgent())
            }
        }
    }

    function deleteWordForward() {
        if (!editorArea || !wordOperations)
            return false
        const nextText = wordOperations.deleteWordForward(editorArea.text, root.cursorLine - 1, root.cursorColumn - 1)
        if (nextText === editorArea.text)
            return false
        editorArea.text = nextText
        editorArea.forceActiveFocus()
        Qt.callLater(() => root.syncSelectionToAgent())
        return true
    }

    function deleteWordBackward() {
        if (!editorArea || !wordOperations)
            return false
        const nextText = wordOperations.deleteWordBackward(editorArea.text, root.cursorLine - 1, root.cursorColumn - 1)
        if (nextText === editorArea.text)
            return false
        editorArea.text = nextText
        editorArea.forceActiveFocus()
        Qt.callLater(() => root.syncSelectionToAgent())
        return true
    }

    function jumpToMatchingBracket() {
        if (!editorArea || !bracketMatcher)
            return false

        const candidates = [
            { line: root.cursorLine - 1, column: root.cursorColumn - 1 },
            { line: root.cursorLine - 1, column: root.cursorColumn - 2 }
        ]

        for (let i = 0; i < candidates.length; ++i) {
            const pos = candidates[i]
            if (pos.line < 0 || pos.column < 0)
                continue

            const info = bracketMatcher.matchingBracketAt(editorArea.text, pos.line, pos.column)
            if (info && info.hasMatch) {
                const openIndex = indexFromLineColumn(editorArea.text, info.openLine, info.openColumn)
                const closeIndex = indexFromLineColumn(editorArea.text, info.closeLine, info.closeColumn)
                root.bracketHighlightPos = [openIndex, closeIndex]
                return
            }
        }
        root.bracketHighlightPos = null
    }

    function activateTab(index) {
        agent.setCurrentEditorIndex(index)
        root.syncFromAgent()
    }

    function closeTab(index) {
        agent.closeEditorTab(index)
        root.syncFromAgent()
    }

    function requestCloseTab(index) {
        requestCloseTabs([index])
    }

    // Close a single tab immediately without confirmation.
    function closeTabImmediate(index) {
        if (index < 0 || index >= agent.openFiles.length) return
        agent.forceCloseEditorTab(index)
        root.syncFromAgent()
    }

    function requestCloseOtherTabs(index) {
        const indices = []
        for (let i = 0; i < agent.openFiles.length; ++i) {
            if (i !== index)
                indices.push(i)
        }
        requestCloseTabs(indices)
    }

    // Close other tabs immediately (no per-tab confirmation).
    // Mirrors VSCode "Close Others" behavior by closing other tabs directly.
    function closeOtherTabsImmediate(index) {
        // iterate from end to start so indices remain valid while closing
        for (let i = agent.openFiles.length - 1; i >= 0; --i) {
            if (i === index) continue
            if (i < 0 || i >= agent.openFiles.length) continue
            agent.forceCloseEditorTab(i)
        }
        root.syncFromAgent()
    }

    function requestCloseSavedTabs() {
        const indices = []
        for (let i = 0; i < agent.openFiles.length; ++i) {
            if (!agent.openFiles[i].dirty)
                indices.push(i)
        }
        requestCloseTabs(indices)
    }

    function requestCloseTabs(indices) {
        pendingCloseQueue = indices
            .filter(index => index >= 0 && index < agent.openFiles.length)
            .sort((left, right) => right - left)

        continuePendingCloseQueue()
    }

    function continuePendingCloseQueue() {
        continuePendingCloseAfterDialog = false

        while (pendingCloseQueue.length > 0) {
            const index = pendingCloseQueue[0]
            if (index < 0 || index >= agent.openFiles.length) {
                pendingCloseQueue.shift()
                continue
            }

            const tab = agent.openFiles[index]
            if (tab.active && agent.currentFileContent !== editorArea.text)
                agent.currentFileContent = editorArea.text

            const shouldConfirm = tab.dirty || (tab.active && agent.currentFileDirty)
            if (!shouldConfirm) {
                root.closeTab(index)
                pendingCloseQueue.shift()
                continue
            }

            pendingCloseIndex = index
            pendingCloseName = tab.name || "Untitled"
            pendingClosePath = tab.path || ""
            closeTabDialog.open()
            return
        }

        resetPendingCloseState()
    }

    function finishPendingCloseStep(shouldContinue) {
        continuePendingCloseAfterDialog = shouldContinue
        if (shouldContinue && pendingCloseQueue.length > 0)
            pendingCloseQueue.shift()

        closeTabDialog.close()
    }

    function handleCloseDialogClosed() {
        const shouldContinue = continuePendingCloseAfterDialog
        continuePendingCloseAfterDialog = false
        resetPendingCloseState()

        if (!shouldContinue) {
            pendingCloseQueue = []
            return
        }

        Qt.callLater(continuePendingCloseQueue)
    }

    function openTabContextMenu(menu, host) {
        const popupPos = host.mapToItem(null, 0, host.height)
        menu.x = popupPos.x
        menu.y = popupPos.y
        menu.open()
    }

    function tabCanClose(index) {
        if (index < 0 || index >= agent.openFiles.length)
            return false
        return !!agent.openFiles[index]
    }

    function confirmSaveAndClose() {
        if (pendingCloseIndex < 0 || pendingCloseIndex >= agent.openFiles.length) {
            closeTabDialog.close()
            return
        }

        if (!agent.openFiles[pendingCloseIndex].active)
            root.activateTab(pendingCloseIndex)

        agent.saveCurrentFile()
        agent.closeEditorTab(pendingCloseIndex)
        root.syncFromAgent()
        finishPendingCloseStep(true)
    }

    function discardAndCloseTab() {
        if (pendingCloseIndex < 0 || pendingCloseIndex >= agent.openFiles.length) {
            closeTabDialog.close()
            return
        }

        agent.forceCloseEditorTab(pendingCloseIndex)
        root.syncFromAgent()
        finishPendingCloseStep(true)
    }

    function resetPendingCloseState() {
        pendingCloseIndex = -1
        pendingCloseName = ""
        pendingClosePath = ""
    }

    Menu {
        id: editorContextMenu
        MenuItem {
            text: "Copy"
            onTriggered: editorArea.copy()
        }
        MenuItem {
            text: "Cut"
            onTriggered: editorArea.cut()
        }
        MenuItem {
            text: "Paste"
            onTriggered: editorArea.paste()
        }
        MenuSeparator {}
        MenuItem {
            text: "Format Document"
            onTriggered: root.formatDocument()
        }
        MenuSeparator {}
        MenuItem {
            text: "Go to Definition"
            onTriggered: {
                // Simplified: use search to find definitions in current or other files
                // For now just triggered Go to Symbol
                goToSymbolPopup.open()
            }
        }
        MenuItem {
            text: "Go to References"
            onTriggered: root.goToReferences()
        }
        MenuItem {
            text: "Go to Line..."
            onTriggered: goToLinePopup.open()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.color: Theme.border

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                height: 30
                color: Theme.surfaceAlt
                border.color: Theme.border
                border.width: 0

                Flickable {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    contentWidth: tabsRow.implicitWidth
                    contentHeight: tabsRow.implicitHeight
                    clip: true
                    interactive: contentWidth > width

                    Row {
                        id: tabsRow
                        spacing: 1
                        height: parent.height

                        Repeater {
                            model: agent.openFiles

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                property bool hovered: tabHoverHandler.hovered
                                property bool showCloseButton: hovered
                                property color tabFillColor: modelData.active
                                                               ? (hovered ? Theme.surfaceAlt : Theme.surface)
                                                               : (hovered ? Theme.surface : Theme.surfaceAlt)
                                property color closeButtonHoverColor: modelData.active ? Theme.surfaceAlt : Theme.border
                                property color closeButtonIconColor: modelData.active ? Theme.textPrimary : Theme.textMuted

                                width: Math.max(112, tabLabel.implicitWidth + 40)
                                height: 22
                                radius: Theme.radius
                                y: 4
                                color: tabFillColor
                                border.color: modelData.active ? Theme.surfaceAlt : "transparent"
                                border.width: 1

                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        bottom: parent.bottom
                                        right: parent.right
                                        topMargin: 4
                                        bottomMargin: 4
                                    }
                                    width: 1
                                    color: (!modelData.active && !hovered) ? Theme.border : "transparent"
                                }

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                    }
                                    height: 2
                                    radius: 1
                                    color: modelData.active ? Theme.accent : "transparent"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 7
                                    spacing: 5

                                    Label {
                                        id: tabLabel
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: modelData.active ? Theme.textPrimary : Theme.textMuted
                                        font.pixelSize: Math.max(11, Theme.fontXs - 1)
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 20
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: modelData.dirty && !showCloseButton
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.active ? Theme.textPrimary : Theme.textMuted
                                        implicitWidth: 8
                                        implicitHeight: 8
                                    }

                                    ToolButton {
                                        visible: showCloseButton
                                        text: "×"
                                        Layout.preferredWidth: 20
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        font.pixelSize: Theme.fontSm
                                        padding: 0
                                        hoverEnabled: true
                                        background: Rectangle {
                                            radius: 4
                                            color: parent.hovered ? closeButtonHoverColor : "transparent"
                                        }
                                        contentItem: Label {
                                            text: parent.text
                                            color: parent.hovered ? Theme.textPrimary : closeButtonIconColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: parent.font.pixelSize
                                        }
                                        onClicked: root.closeTabImmediate(index)
                                    }
                                }

                                HoverHandler {
                                    id: tabHoverHandler
                                }

                                TapHandler {
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    onTapped: eventPoint => {
                                        if (eventPoint.button === Qt.MiddleButton) {
                                            root.closeTabImmediate(index)
                                            return
                                        }
                                        root.activateTab(index)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            editorContextMenu.x = mouse.x
                                            editorContextMenu.y = mouse.y
                                            editorContextMenu.open()
                                        }
                                    }
                                    propagateComposedEvents: true
                                    onPressed: mouse => mouse.accepted = false // let TextArea handle it too
                                    onReleased: mouse => mouse.accepted = false
                                }

                                Menu {
                                    id: tabMenu

                                    MenuItem {
                                        text: "Close"
                                        enabled: root.tabCanClose(index)
                                        onTriggered: root.closeTabImmediate(index)
                                    }

                                    MenuItem {
                                        text: "Close Others"
                                        enabled: agent.openFiles.length > 1
                                        onTriggered: root.closeOtherTabsImmediate(index)
                                    }

                                    MenuItem {
                                        text: "Close Saved"
                                        enabled: agent.openFiles.some(tab => !tab.dirty)
                                        onTriggered: root.requestCloseSavedTabs()
                                    }
                                }
                            }
                        }

                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: Theme.surfaceAlt
                border.color: Theme.border
                border.width: 0

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            text: agent.currentFilePath
                                  ? (agent.currentFileDirty ? "Modified" : "Saved")
                                  : "No file selected"
                            color: agent.currentFileDirty ? Theme.warning : Theme.textMuted
                            font.pixelSize: Theme.fontXs
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Label {
                        text: agent.currentFilePath && root.cursorLine > 0
                              ? ("Ln " + root.cursorLine + ", Col " + root.cursorColumn)
                              : ""
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                    }

                    Button {
                        text: "Reload"
                        enabled: !!agent.currentFilePath
                        topPadding: 3
                        bottomPadding: 3
                        leftPadding: 8
                        rightPadding: 8
                        font.pixelSize: Theme.fontXs
                        flat: true
                        background: Rectangle {
                            radius: 4
                            color: parent.down ? Theme.border : (parent.hovered ? Theme.surface : "transparent")
                            border.color: parent.hovered ? Theme.border : "transparent"
                            border.width: 1
                        }
                        onClicked: root.syncFromAgent()
                    }

                    Button {
                        text: "Save"
                        visible: !!agent.currentFilePath && agent.currentFileDirty
                        enabled: !!agent.currentFilePath && agent.currentFileDirty
                        topPadding: 3
                        bottomPadding: 3
                        leftPadding: 8
                        rightPadding: 8
                        font.pixelSize: Theme.fontXs
                        flat: true
                        background: Rectangle {
                            radius: 4
                            color: parent.enabled
                                   ? (parent.down ? Theme.border : (parent.hovered ? Theme.surface : "transparent"))
                                   : "transparent"
                            border.color: parent.enabled && parent.hovered ? Theme.border : "transparent"
                            border.width: 1
                        }
                        onClicked: root.saveCurrentFile()
                    }

                    Button {
                        text: "Codex Write"
                        enabled: !!agent.currentFilePath && !agent.busy
                        topPadding: 3
                        bottomPadding: 3
                        leftPadding: 8
                        rightPadding: 8
                        font.pixelSize: Theme.fontXs
                        flat: true
                        background: Rectangle {
                            radius: 4
                            color: parent.down ? Theme.border : (parent.hovered ? Theme.surface : "transparent")
                            border.color: parent.hovered ? Theme.border : "transparent"
                            border.width: 1
                        }
                        onClicked: root.writeCurrentFileWithCodex()
                    }

                    Button {
                        text: "Send to Agent"
                        enabled: !!agent.currentFilePath
                        topPadding: 3
                        bottomPadding: 3
                        leftPadding: 8
                        rightPadding: 8
                        font.pixelSize: Theme.fontXs
                        flat: true
                        background: Rectangle {
                            radius: 4
                            color: parent.down ? Theme.border : (parent.hovered ? Theme.surface : "transparent")
                            border.color: parent.hovered ? Theme.border : "transparent"
                            border.width: 1
                        }
                        onClicked: {
                            const hasSelection = editorArea.selectedText && editorArea.selectedText.length > 0
                            const payload = hasSelection ? editorArea.selectedText : editorArea.text
                            const startLine = hasSelection ? root.lineFromIndex(editorArea.text, editorArea.selectionStart) : 1
                            const endLine = hasSelection ? root.lineFromIndex(editorArea.text, editorArea.selectionEnd) : root.lineFromIndex(editorArea.text, editorArea.text.length)
                            agent.injectSelection(agent.currentFilePath, payload, startLine, Math.max(startLine, endLine))
                        }
                    }

                    Button {
                        text: root.previewMode ? "Close Preview" : "Open Preview"
                        visible: root.isMarkdown
                        topPadding: 3
                        bottomPadding: 3
                        leftPadding: 8
                        rightPadding: 8
                        font.pixelSize: Theme.fontXs
                        flat: true
                        background: Rectangle {
                            radius: 4
                            color: parent.down ? Theme.border : (parent.hovered ? Theme.surface : "transparent")
                            border.color: parent.hovered ? Theme.border : "transparent"
                            border.width: 1
                        }
                        onClicked: root.previewMode = !root.previewMode
                    }
                }
            }

            // ── Breadcrumbs (VS Code style) ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: Theme.surface
                border.color: Theme.border
                border.width: 0
                visible: !!agent.currentFilePath && !diffMode

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 4

                    Repeater {
                        model: {
                            if (!agent.currentFilePath) return []
                            const ws = agent.workspacePath || ""
                            let path = agent.currentFilePath
                            const parts = []

                            // Build path increments
                            let current = ws
                            const relative = path.startsWith(ws) ? path.slice(ws.length).replace(/^\/+/, "") : path
                            const pathParts = relative.split("/")

                            parts.push({ name: ws.split("/").pop() || "root", path: ws })
                            let cummulative = ws
                            for (let i = 0; i < pathParts.length; i++) {
                                if (pathParts[i] === "") continue
                                cummulative += "/" + pathParts[i]
                                parts.push({ name: pathParts[i], path: cummulative })
                            }
                            return parts
                        }

                        delegate: RowLayout {
                            spacing: 4
                            Label {
                                text: modelData.name
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.color = Theme.textPrimary
                                    onExited: parent.color = Theme.textMuted
                                    onClicked: {
                                        // Open directory popup for the parent of this part,
                                        // or if it's a file, the directory it's in.
                                        const parts = modelData.path.split("/")
                                        parts.pop()
                                        breadcrumbPopup.path = parts.join("/")
                                        const globalPos = parent.mapToItem(null, 0, parent.height)
                                        breadcrumbPopup.x = globalPos.x
                                        breadcrumbPopup.y = globalPos.y
                                        breadcrumbPopup.open()
                                    }
                                }
                            }
                            Label {
                                text: ">"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                                opacity: index < (parent.parent.count - 1) ? 0.5 : 0
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
                    opacity: 0.5
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                StackLayout {
                    anchors.fill: parent
                    currentIndex: diffMode ? 1 : 0

                    SplitView {
                        orientation: Qt.Horizontal

                        Item {
                            SplitView.fillWidth: true
                            SplitView.fillHeight: true
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.bg
                            }

                            Rectangle {
                                id: gutter
                                width: root.gutterWidth
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                color: Theme.surfaceAlt
                                border.color: Theme.border
                                border.width: 0

                                Item {
                                    id: gutterClip
                                    anchors.fill: parent
                                    clip: true

                                    Item {
                                        width: parent.width
                                        height: root.lineCount * editorFontMetrics.lineSpacing
                                        // editorArea is placed inside a ScrollView (editorScrollView); use its contentItem.contentY
                                        y: (editorScrollView && editorScrollView.contentItem) ? -editorScrollView.contentItem.contentY : 0

                                        Repeater {
                                            model: root.lineCount
                                            delegate: Text {
                                                x: 0
                                                y: index * editorFontMetrics.lineSpacing
                                                width: gutter.width - 10
                                                height: editorFontMetrics.lineSpacing
                                                text: (index + 1).toString()
                                                horizontalAlignment: Text.AlignRight
                                                verticalAlignment: Text.AlignVCenter
                                                font: Theme.monoFont
                                                color: (index + 1) === root.cursorLine ? Theme.accentHover : Theme.textMuted
                                                opacity: agent.currentFilePath ? 1.0 : 0.55
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors {
                                    left: gutter.right
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                color: "transparent"
                                visible: !!agent.currentFilePath

                                Rectangle {
                                    x: 0
                                    // Use the ScrollView's contentItem for its contentY
                                    y: Math.max(0, root.editorCursorY() - (editorScrollView && editorScrollView.contentItem ? editorScrollView.contentItem.contentY : 0))
                                    width: parent.width
                                    height: editorFontMetrics.lineSpacing
                                    color: Theme.accent
                                    opacity: 0.08
                                    visible: agent.currentFileContent.length > 0
                                }

                                ScrollView {
                                    id: editorScrollView
                                    anchors {
                                        fill: parent
                                        leftMargin: 12
                                        rightMargin: 6
                                        topMargin: 10
                                        bottomMargin: 10
                                    }
                                    clip: true
                                    contentWidth: -1
                                    ScrollBar.vertical: CustomScrollBar {
                                        collapsedWidth: 6
                                        hoveredWidth: 7
                                        thumbWidth: 4
                                        thumbHeight: 24
                                        inactiveOpacity: 0.18
                                        activeOpacity: 0.78
                                        backgroundOpacity: 0.05
                                        thumbColor: "#3a3a3a"
                                        hoverThumbColor: "#5f5f5f"
                                        pressedThumbColor: "#8f8f8f"
                                    }
                                    ScrollBar.horizontal: CustomScrollBar {
                                        collapsedWidth: 6
                                        hoveredWidth: 7
                                        thumbWidth: 4
                                        thumbHeight: 24
                                        inactiveOpacity: 0.18
                                        activeOpacity: 0.78
                                        backgroundOpacity: 0.05
                                        thumbColor: "#3a3a3a"
                                        hoverThumbColor: "#5f5f5f"
                                        pressedThumbColor: "#8f8f8f"
                                        policy: ScrollBar.AsNeeded
                                    }

                                    TextArea {
                                        id: editorArea
                                        objectName: "editorInput"
                                        width: parent.width
                                        text: agent.currentFileContent
                                        font: Theme.monoFont
                                        color: Theme.textPrimary
                                        selectionColor: Theme.accent
                                        selectedTextColor: "white"
                                        background: null
                                        renderType: Text.NativeRendering
                                        selectByMouse: true
                                        persistentSelection: true
                                        wrapMode: root.wordWrap ? TextArea.Wrap : TextArea.NoWrap

                                        function getLineText(lineIndex) {
                                            const lines = text.split("\n")
                                            if (lineIndex >= 0 && lineIndex < lines.length)
                                                return lines[lineIndex]
                                            return ""
                                        }

                                        Keys.onPressed: function(event) {
                                            if (event.key === Qt.Key_F && event.modifiers === Qt.ControlModifier) {
                                                findPopup.open()
                                                findInput.forceActiveFocus()
                                                event.accepted = true
                                                return
                                            }

                                            if (root.autoClosingPairs) {
                                                const pairs = {
                                                    '(': ')',
                                                    '[': ']',
                                                    '{': '}',
                                                    '"': '"',
                                                    "'": "'"
                                                }
                                                const openChars = Object.keys(pairs)
                                                const typedChar = event.text
                                                if (typedChar.length === 1 && openChars.includes(typedChar)) {
                                                    const pos = cursorPosition
                                                    // Check if we are typing a closing quote that is already there
                                                    if ((typedChar === '"' || typedChar === "'") && text.charAt(pos) === typedChar) {
                                                        cursorPosition = pos + 1
                                                        event.accepted = true
                                                        return
                                                    }

                                                    insert(pos, pairs[typedChar])
                                                    cursorPosition = pos // Move back so the typed char lands before the pair
                                                    // Let the default handler insert the opening char
                                                } else if (typedChar.length === 1 && Object.values(pairs).includes(typedChar)) {
                                                    // User typed a closing char, check if it's already there
                                                    const pos = cursorPosition
                                                    if (text.charAt(pos) === typedChar) {
                                                        cursorPosition = pos + 1
                                                        event.accepted = true
                                                        return
                                                    }
                                                }
                                            }

                                            if (root.autoIndent && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                                const pos = cursorPosition
                                                const lineIndex = root.cursorLine - 1
                                                const currentLine = getLineText(lineIndex)
                                                const indentMatch = currentLine.match(/^\s*/)
                                                let indent = indentMatch ? indentMatch[0] : ""

                                                const trimmedLine = currentLine.trim()
                                                if (trimmedLine.endsWith("{") || trimmedLine.endsWith(":") || trimmedLine.endsWith("[")) {
                                                    indent += "    " // Add 4 spaces for new block
                                                }

                                                insert(pos, "\n" + indent)
                                                event.accepted = true
                                                return
                                            }
                                        }

                                        onCursorPositionChanged: {
                                            root.updateCursorMetrics()
                                            if (root.autoHighlightBrackets) {
                                                root.highlightBrackets()
                                            }
                                            // Request hover on cursor move (optional, or use a timer)
                                            hoverTimer.restart()
                                        }

                                        onSelectedTextChanged: root.syncSelectionToAgent()

                                        Component.onCompleted: {
                                            root.syncFromAgent(true)
                                            if (agent.currentFilePath)
                                                forceActiveFocus()
                                        }
                                    }

                                    SyntaxHighlighter {
                                        textDocument: editorArea.textDocument
                                        language: {
                                            if (!agent.currentFilePath) return ""
                                            var parts = agent.currentFilePath.split('.')
                                            return parts.length > 1 ? parts[parts.length - 1].toLowerCase() : ""
                                        }
                                    }

                                    Repeater {
                                        model: root.bracketHighlightPos || []
                                        delegate: Rectangle {
                                            property rect r: editorArea.positionToRectangle(modelData)
                                            x: r.x
                                            y: r.y
                                            width: r.width || 8
                                            height: r.height || editorFontMetrics.lineSpacing
                                            color: "transparent"
                                            border.color: Theme.accent
                                            border.width: 1
                                            opacity: 0.8
                                        }
                                    }
                                }

                                // Minimap
                                Rectangle {
                                    id: minimap
                                    width: 60
                                    anchors {
                                        right: parent.right
                                        top: parent.top
                                        bottom: parent.bottom
                                        rightMargin: 12
                                    }
                                    color: Theme.surfaceAlt
                                    opacity: 0.3
                                    border.color: Theme.border
                                    visible: !!agent.currentFilePath && agent.currentFileContent.length > 100

                                    Flickable {
                                        anchors.fill: parent
                                        contentWidth: width
                                        contentHeight: minimapText.height
                                        interactive: false
                                        clip: true

                                        Text {
                                            id: minimapText
                                            width: parent.width
                                            text: editorArea.text
                                            font.family: Theme.monoFont.family
                                            font.pixelSize: 1
                                            lineHeight: 1.2
                                            color: Theme.textMuted
                                            wrapMode: Text.NoWrap
                                        }

                                        // Visible viewport indicator
                                        Rectangle {
                                            width: parent.width
                                            height: Math.max(10, (editorScrollView.height / Math.max(1, editorArea.height)) * minimapText.height)
                                        y: ((editorScrollView && editorScrollView.contentItem ? editorScrollView.contentItem.contentY : 0) / Math.max(1, editorArea.height)) * minimapText.height
                                            color: Theme.accent
                                            opacity: 0.2
                                            border.color: Theme.accent
                                            border.width: 1
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: (mouse) => {
                                            const ratio = mouse.y / height
                                            if (editorScrollView && editorScrollView.contentItem) {
                                                editorScrollView.contentItem.contentY = ratio * editorArea.height - editorScrollView.height / 2
                                            }
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed) {
                                                const ratio = mouse.y / height
                                                if (editorScrollView && editorScrollView.contentItem) {
                                                    editorScrollView.contentItem.contentY = ratio * editorArea.height - editorScrollView.height / 2
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MarkdownPreview {
                            visible: root.previewMode && root.isMarkdown
                            SplitView.preferredWidth: parent.width / 2
                            SplitView.fillHeight: true
                            markdownText: editorArea.text
                            filePath: agent.currentFilePath || ""
                        }
                    }

                    DiffView {
                        originalText: root.originalContent
                        modifiedText: agent.currentFileContent
                        fileName: agent.currentFilePath ? agent.currentFilePath.split("/").pop() : ""
                    }
                }
            }
        }
    }

    FontMetrics {
        id: editorFontMetrics
        font: Theme.monoFont
    }

    Timer {
        id: bracketHighlightTimer
        interval: 1000
        onTriggered: root.bracketHighlightPos = null
    }

    Timer {
        id: hoverTimer
        interval: 1000
        repeat: false
        onTriggered: root.showHover(root.cursorLine, root.cursorColumn)
    }

    Popup {
        id: hoverPopup
        width: Math.min(400, hoverLabel.implicitWidth + 20)
        height: hoverLabel.implicitHeight + 20
        padding: 10
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceAlt
            radius: 4
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Label {
            id: hoverLabel
            text: root.hoverContent
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSm
            wrapMode: Text.WordWrap
            textFormat: Text.MarkdownText
        }
    }

    Popup {
        id: findPopup
        width: 320
        height: 100
        x: parent.width - width - 20
        y: 40
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border
            border.width: 1
            layer.enabled: true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                spacing: 8
                TextField {
                    id: findInput
                    Layout.fillWidth: true
                    placeholderText: "Find..."
                    font.pixelSize: Theme.fontSm
                    onAccepted: root.findInFile(text)
                }
                ToolButton {
                    text: "↓"
                    onClicked: root.findInFile(findInput.text)
                    ToolTip.text: "Find Next"
                }
            }

            RowLayout {
                spacing: 8
                TextField {
                    id: replaceInput
                    Layout.fillWidth: true
                    placeholderText: "Replace..."
                    font.pixelSize: Theme.fontSm
                }
                ToolButton {
                    text: "ab"
                    onClicked: {
                        if (editorArea.selectedText === findInput.text && findInput.text !== "") {
                            const pos = editorArea.selectionStart
                            editorArea.remove(editorArea.selectionStart, editorArea.selectionEnd)
                            editorArea.insert(pos, replaceInput.text)
                            root.findInFile(findInput.text)
                        } else {
                            root.findInFile(findInput.text)
                        }
                    }
                    ToolTip.text: "Replace"
                }
                ToolButton {
                    text: "all"
                    onClicked: {
                        if (findInput.text === "") return
                        const newText = editorArea.text.split(findInput.text).join(replaceInput.text)
                        editorArea.text = newText
                    }
                    ToolTip.text: "Replace All"
                }
            }
        }
    }

    Popup {
        id: closeTabDialog

        anchors.centerIn: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        padding: 20
        implicitWidth: 420
        onClosed: root.handleCloseDialogClosed()

        background: Rectangle {
            color: Theme.surfaceAlt
            radius: Theme.radius
            border.color: Theme.border
        }

        contentItem: ColumnLayout {
            spacing: 0

            Label {
                text: "Close unsaved tab?"
                font.pixelSize: Theme.fontMd
                font.bold: true
                color: Theme.textPrimary
            }

            Item { height: 10 }

            Label {
                Layout.fillWidth: true
                text: "Save changes to " + root.pendingCloseName + " before closing?"
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }

            Item { height: 8 }

            Label {
                Layout.fillWidth: true
                text: root.pendingClosePath
                color: Theme.textMuted
                font.pixelSize: Theme.fontXs
                elide: Text.ElideMiddle
            }

            Item { height: 18 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: closeTabDialog.close()
                }

                Button {
                    text: "Discard"
                    onClicked: root.discardAndCloseTab()
                }

                Button {
                    text: "Save"
                    onClicked: root.confirmSaveAndClose()
                    background: Rectangle {
                        radius: Theme.radius
                        color: Theme.accent
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    BreadcrumbPopup {
        id: breadcrumbPopup
        onItemClicked: (filePath, isDir) => {
            if (isDir) {
                // Could highlight in tree or do nothing for now
            } else {
                agent.openEditorFile(filePath)
            }
        }
    }
}
