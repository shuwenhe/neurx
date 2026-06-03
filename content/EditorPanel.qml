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
    property int cursorLine: 1
    property int cursorColumn: 1
    property int lineCount: Math.max(1, agent.currentFileContent.length > 0 ? agent.currentFileContent.split("\n").length : 1)
    property int gutterDigits: Math.max(2, String(root.lineCount).length)
    property int gutterWidth: Math.max(48, Math.ceil(editorFontMetrics.averageCharacterWidth * gutterDigits) + 18)

    function syncFromAgent(resetView) {
        if (editorArea && (editorArea.text !== agent.currentFileContent || resetView)) {
            syncingEditorFromAgent = true
            editorArea.text = agent.currentFileContent
            if (resetView) {
                editorArea.cursorPosition = 0
                // editorArea is hosted inside a ScrollView; reset the ScrollView's content offsets
                if (editorScrollView) {
                    editorScrollView.contentX = 0
                    editorScrollView.contentY = 0
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

    function saveCurrentFile() {
        if (!agent.currentFilePath)
            return
        agent.currentFileContent = editorArea.text
        agent.saveCurrentFile()
        root.syncFromAgent()
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
                                    onClicked: () => {
                                        root.openTabContextMenu(tabMenu, parent)
                                    }
                                    onPressAndHold: {
                                        root.openTabContextMenu(tabMenu, parent)
                                    }
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
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                            // editorArea is placed inside a ScrollView (editorScroll); use its contentY
                            y: editorScroll ? -editorScroll.contentY : 0

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
                        y: Math.max(0, root.editorCursorY() - (editorScrollView ? editorScrollView.contentY : 0))
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
                        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        TextArea {
                            id: editorArea
                            objectName: "editorInput"
                            text: agent.currentFileContent
                            wrapMode: TextArea.NoWrap
                            selectByMouse: true
                            persistentSelection: true
                            font: Theme.monoFont
                            color: Theme.textPrimary
                            background: Rectangle { color: "transparent" }
                            placeholderText: "Select a file from the explorer…"
                            tabStopDistance: 4 * editorFontMetrics.averageCharacterWidth
                            focus: !!agent.currentFilePath
                            cursorDelegate: Rectangle {
                                width: 1
                                color: Theme.accent
                                visible: editorArea.activeFocus
                            }

                            SyntaxHighlighter {
                                id: highlighter
                                textDocument: editorArea.textDocument
                                language: {
                                    const p = agent.currentFilePath
                                    if (!p) return ""
                                    const dot = p.lastIndexOf(".")
                                    return dot >= 0 ? p.slice(dot + 1).toLowerCase() : ""
                                }
                            }

                            onTextChanged: {
                                if (root.syncingEditorFromAgent)
                                    return
                                if (agent.currentFileContent !== text)
                                    agent.currentFileContent = text
                                Qt.callLater(() => root.syncSelectionToAgent())
                            }

                            onSelectionStartChanged: root.syncSelectionToAgent()
                            onSelectionEndChanged: root.syncSelectionToAgent()
                            onSelectedTextChanged: root.syncSelectionToAgent()
                            onCursorPositionChanged: root.updateCursorMetrics()
                            Component.onCompleted: {
                                root.syncFromAgent(true)
                                if (agent.currentFilePath)
                                    forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
    }

    FontMetrics {
        id: editorFontMetrics
        font: Theme.monoFont
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
}
