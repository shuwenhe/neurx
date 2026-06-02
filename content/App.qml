import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtQuick.Dialogs
import NeurXCode

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    visibility: Window.FullScreen
    visible: true
    title: "NeurX Code — " + (agentCtx ? agentCtx.workspacePath || "No workspace" : "No workspace")
    color: Theme.bg

    // Capture C++ context property so child bindings don't create a loop
    readonly property var agentCtx: agent

    // ── Zoom ──────────────────────────────────────────────────────────────
    property real zoomFactor: 1.0

    Shortcut { sequence: "Ctrl+=";        onActivated: zoomFactor = Math.min(zoomFactor + 0.1, 3.0) }
    Shortcut { sequence: "Ctrl++";        onActivated: zoomFactor = Math.min(zoomFactor + 0.1, 3.0) }
    Shortcut { sequence: "Ctrl+-";        onActivated: zoomFactor = Math.max(zoomFactor - 0.1, 0.4) }
    Shortcut { sequence: "Ctrl+0";        onActivated: zoomFactor = 1.0 }

    Shortcut {
        sequence: "F2"
        enabled: root.shortcutsEnabled
        onActivated: {
            if (agentCtx.currentFilePath)
                fileTree.openRenameDialog(agentCtx.currentFilePath)
        }
    }

    Shortcut {
        sequence: "Del"
        enabled: root.shortcutsEnabled
        onActivated: {
            if (agentCtx.currentFilePath)
                fileTree.openDeleteDialog(agentCtx.currentFilePath)
        }
    }

    Shortcut {
        sequence: "Ctrl+N"
        enabled: root.shortcutsEnabled
        onActivated: {
            const dirPath = agentCtx.currentFilePath
                          ? fileTree.currentDirForPath(agentCtx.currentFilePath)
                          : (agentCtx.workspacePath || "")
            fileTree.openCreateDialog(dirPath, false)
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+N"
        enabled: root.shortcutsEnabled
        onActivated: {
            const dirPath = agentCtx.currentFilePath
                          ? fileTree.currentDirForPath(agentCtx.currentFilePath)
                          : (agentCtx.workspacePath || "")
            fileTree.openCreateDialog(dirPath, true)
        }
    }

    // ── Layout: Explorer | Editor | Agent ─────────────────────────────────
    Item {
        anchors.fill: parent

        Item {
            id: contentScaler
            width: parent.width / root.zoomFactor
            height: parent.height / root.zoomFactor
            scale: root.zoomFactor
            transformOrigin: Item.TopLeft

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Left: file tree + workspace controls
                FileTreePanel {
                    id: fileTree
                    Layout.preferredWidth: sidebarVisible ? root.explorerWidth : 0
                    Layout.minimumWidth: sidebarVisible ? root.minExplorerWidth : 0
                    Layout.maximumWidth: sidebarVisible ? root.explorerWidth : 0
                    Layout.fillHeight: true
                    agent: agentCtx
                    visible: sidebarVisible
                    onFileClicked: path => agentCtx.openEditorFile(path)
                }

                // Divider
                Rectangle {
                    width: sidebarVisible ? root.splitterWidth : 0
                    Layout.fillHeight: true
                    color: hovered ? Theme.accentHover : Theme.border
                    visible: sidebarVisible

                    property bool hovered: false

                    DragHandler {
                        id: explorerDrag
                        target: null
                        acceptedButtons: Qt.LeftButton

                        onActiveChanged: {
                            if (active)
                                root.explorerDragStartWidth = root.explorerWidth
                        }

                        onTranslationChanged: {
                            if (!active || !sidebarVisible)
                                return
                            const maxWidth = root.explorerMaxWidth()
                            root.explorerWidth = root.clamp(
                                root.explorerDragStartWidth + translation.x,
                                root.minExplorerWidth,
                                maxWidth
                            )
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                    }
                }

                // Centre: editor
                EditorPanel {
                    id: editorPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: root.minCenterWidth
                    agent: agentCtx
                }

                // Divider
                Rectangle {
                    width: root.splitterWidth
                    Layout.fillHeight: true
                    color: hovered ? Theme.accentHover : Theme.border

                    property bool hovered: false

                    DragHandler {
                        id: agentDrag
                        target: null
                        acceptedButtons: Qt.LeftButton

                        onActiveChanged: {
                            if (active)
                                root.agentDragStartWidth = root.agentWidth
                        }

                        onTranslationChanged: {
                            if (!active)
                                return
                            const maxWidth = root.agentMaxWidth()
                            root.agentWidth = root.clamp(
                                root.agentDragStartWidth - translation.x,
                                root.minAgentWidth,
                                maxWidth
                            )
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                    }
                }

                // Right: agent
                ChatPanel {
                    id: agentPanel
                    Layout.preferredWidth: root.agentWidth
                    Layout.minimumWidth: root.minAgentWidth
                    Layout.maximumWidth: root.agentWidth
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: agentCtx.chatModel
                    busy: agentCtx.busy
                    streamingText: agentCtx.streamingText
                    onSendMessage: text => agentCtx.sendMessage(text)
                    onInterrupt: agentCtx.interrupt()
                    onClearHistory: agentCtx.clearHistory()
                }
            }
        }
    }

    // ── Top toolbar ───────────────────────────────────────────────────────
    header: ToolBar {
        height: 44
        background: Rectangle { color: Theme.surface; border.color: Theme.border; border.width: 1 }

        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 6

            // Sidebar toggle
            ToolButton {
                text: sidebarVisible ? "⟨" : "⟩"
                font.pixelSize: Theme.fontLg
                onClicked: sidebarVisible = !sidebarVisible
                ToolTip.text: "Toggle file tree"
                ToolTip.visible: hovered
            }

            // Workspace button
            ToolButton {
                text: agentCtx.workspacePath ? "📁 " + agentCtx.workspacePath.split("/").pop()
                                               : "Open Workspace…"
                font.pixelSize: Theme.fontMd
                onClicked: workspacePicker.open()
                ToolTip.text: agentCtx.workspacePath || "No workspace selected"
                ToolTip.visible: hovered
            }

            Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 220
                    Layout.maximumWidth: 260
                    height: 34
                    radius: Theme.radius + 2
                    color: Theme.surfaceAlt
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Label {
                            text: "Workspace"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                        }

                        Label {
                            Layout.fillWidth: true
                            text: agentCtx.workspacePath ? agentCtx.workspacePath.split("/").pop() : "Open Workspace"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSm
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: workspacePicker.open()
                    }
                }

                Rectangle {
                    height: 34
                    radius: Theme.radius + 2
                    color: Theme.surfaceAlt
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        Label {
                            text: "Provider"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                        }

                        ComboBox {
                            id: providerCombo
                            model: agentCtx.providers
                            currentIndex: model.indexOf(agentCtx.currentProvider)
                            onActivated: agentCtx.currentProvider = currentText
                            font.pixelSize: Theme.fontSm
                            implicitWidth: 118
                        }
                    }
                }

                Rectangle {
                    height: 34
                    radius: Theme.radius + 2
                    color: Theme.surfaceAlt
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        Label {
                            text: "Model"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                        }

                        ComboBox {
                            id: modelCombo
                            model: agentCtx.models
                            currentIndex: model.indexOf(agentCtx.currentModel)
                            onActivated: agentCtx.currentModel = currentText
                            font.pixelSize: Theme.fontSm
                            implicitWidth: 190
                        }
                    }
                }

            // Settings button
            ToolButton {
                text: "⚙"
                font.pixelSize: Theme.fontLg
                onClicked: settingsDrawer.open()
            }
        }
    }

    // ── Settings drawer ───────────────────────────────────────────────────
    Drawer {
        id: settingsDrawer
        width: 320
        height: root.height
        edge: Qt.RightEdge

        SettingsPanel {
            anchors.fill: parent
            agent: agentCtx
        }
    }

    // ── Tool approval dialog ──────────────────────────────────────────────
    ToolApprovalDialog {
        id: approvalDialog
        anchors.centerIn: parent
        onApproved: callId => agentCtx.approveTool(callId)
        onRejected: callId => agentCtx.rejectTool(callId)
    }

    CheckpointRestoreDialog {
        id: checkpointRestoreDialog
        anchors.centerIn: parent
        onConfirmed: checkpointId => agentCtx.rollbackCheckpoint(checkpointId)
    }

    // ── File picker (uses native dialog via QML FileDialog) ───────────────
    FolderDialog {
        id: workspacePicker
        onAccepted: agentCtx.workspacePath = selectedFolder.toString().replace("file://", "")
    }

    // ── State ─────────────────────────────────────────────────────────────
    property bool sidebarVisible: true
    property real explorerWidth: 260
    property real agentWidth: 560
    property real splitterWidth: 8
    property real minExplorerWidth: 180
    property real minAgentWidth: 300
    property real minCenterWidth: 380
    property real explorerDragStartWidth: explorerWidth
    property real agentDragStartWidth: agentWidth
    property bool shortcutsEnabled: !root.textEditingFocusActive
                                  && !fileTree.entryDialogVisible
                                  && !fileTree.deleteDialogVisible
                                  && !checkpointRestoreDialog.visible
                                  && !settingsDrawer.opened

    function clamp(value, minValue, maxValue) {
        return Math.min(Math.max(value, minValue), maxValue)
    }

    property bool textEditingFocusActive: {
        const item = root.activeFocusItem
        if (!item)
            return false
        const name = item.objectName || ""
        return name === "editorInput"
            || name === "chatInput"
            || name === "treeFilterField"
            || name === "treeNameField"
    }

    Connections {
        target: agentCtx
        function onToolApprovalRequired(callId, toolName, summary) {
            approvalDialog.show(callId, toolName, summary)
        }
        function onErrorOccurred(message) {
            errorBanner.showError(message)
        }
        function onSuccessOccurred(message) {
            errorBanner.showSuccess(message)
        }
    }

    function explorerMaxWidth() {
        const available = contentScaler.width
        const reserved = (sidebarVisible ? root.splitterWidth : 0) + root.agentWidth + root.minCenterWidth + root.splitterWidth
        return Math.max(root.minExplorerWidth, available - reserved)
    }

    function agentMaxWidth() {
        const available = contentScaler.width
        const reserved = root.explorerWidth + root.minCenterWidth + root.splitterWidth + (sidebarVisible ? root.splitterWidth : 0)
        return Math.max(root.minAgentWidth, available - reserved)
    }

    // ── Error banner ──────────────────────────────────────────────────────
    ErrorBanner {
        id: errorBanner
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
    }
}
