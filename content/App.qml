import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtQuick.Dialogs
import QtCore
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

    Settings {
        id: appSettings
        property string recentWorkspacesJson: "[]"
        property int lastAgentTabIndex: 0
        property bool sidebarVisible: true
        property real explorerWidth: 260
        property real agentWidth: 560
    }

    function addRecentWorkspace(path) {
        if (!path) return
        try {
            let recent = JSON.parse(appSettings.recentWorkspacesJson || "[]")
            if (!Array.isArray(recent)) recent = []
            recent = recent.filter(p => p !== path)
            recent.unshift(path)
            if (recent.length > 10) recent = recent.slice(0, 10)
            appSettings.recentWorkspacesJson = JSON.stringify(recent)
        } catch (e) {
            appSettings.recentWorkspacesJson = JSON.stringify([path])
        }
    }

    readonly property var recentWorkspaces: {
        try {
            return JSON.parse(appSettings.recentWorkspacesJson || "[]")
        } catch (e) {
            return []
        }
    }

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

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Activity Bar (Vertical icons on the far left)
                    Rectangle {
                        id: activityBar
                        Layout.fillHeight: true
                        Layout.preferredWidth: 48
                        color: Theme.surfaceAlt
                        border.color: Theme.border
                        border.width: 0

                        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.topMargin: 10
                            spacing: 15

                            ActivityBarButton {
                                icon: "💬"
                                active: agentTabs.currentIndex === 0
                                onClicked: {
                                    agentTabs.currentIndex = 0
                                    appSettings.lastAgentTabIndex = 0
                                    if (!sidebarVisible) {
                                        sidebarVisible = true
                                        appSettings.sidebarVisible = true
                                    }
                                }
                                toolTip: "AI Chat"
                            }
                            ActivityBarButton {
                                icon: "📂"
                                active: sidebarVisible
                                onClicked: {
                                    sidebarVisible = !sidebarVisible
                                    appSettings.sidebarVisible = sidebarVisible
                                }
                                toolTip: "Explorer"
                            }
                            ActivityBarButton {
                                icon: "🔍"
                                active: agentTabs.currentIndex === 1
                                onClicked: {
                                    agentTabs.currentIndex = 1
                                    appSettings.lastAgentTabIndex = 1
                                    if (!sidebarVisible) {
                                        sidebarVisible = true
                                        appSettings.sidebarVisible = true
                                    }
                                }
                                toolTip: "Search"
                            }
                            ActivityBarButton {
                                icon: "" // Outline icon
                                active: agentTabs.currentIndex === 2
                                onClicked: {
                                    agentTabs.currentIndex = 2
                                    appSettings.lastAgentTabIndex = 2
                                    if (!sidebarVisible) {
                                        sidebarVisible = true
                                        appSettings.sidebarVisible = true
                                    }
                                }
                                toolTip: "Outline"
                            }
                            ActivityBarButton {
                                icon: "⌨"
                                active: agentTabs.currentIndex === 3
                                onClicked: {
                                    agentTabs.currentIndex = 3
                                    appSettings.lastAgentTabIndex = 3
                                    if (!sidebarVisible) {
                                        sidebarVisible = true
                                        appSettings.sidebarVisible = true
                                    }
                                }
                                toolTip: "Terminal"
                            }
                            ActivityBarButton {
                                icon: ""
                                active: agentTabs.currentIndex === 8
                                onClicked: {
                                    agentTabs.currentIndex = 8
                                    appSettings.lastAgentTabIndex = 8
                                    if (!sidebarVisible) {
                                        sidebarVisible = true
                                        appSettings.sidebarVisible = true
                                    }
                                }
                                toolTip: "Source Control"
                            }
                            ActivityBarButton {
                                icon: "⚠"
                                active: agentTabs.currentIndex === 7
                                onClicked: { agentTabs.currentIndex = 7; if (!sidebarVisible) sidebarVisible = true; }
                                toolTip: "Problems"
                            }

                            Item { Layout.fillHeight: true }

                            ActivityBarButton {
                                icon: "⚙"
                                onClicked: settingsDrawer.open()
                                toolTip: "Settings"
                            }
                        }
                    }

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
                        onFindInFolderRequested: path => {
                            agentTabs.currentIndex = 1
                            searchPanel.searchPath = path
                            searchPanel.searchText = ""
                        }
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
                                appSettings.explorerWidth = root.explorerWidth
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
                                appSettings.agentWidth = root.agentWidth
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

                    // Right: agent workspace
                    ColumnLayout {
                        id: agentWorkspace
                        Layout.preferredWidth: root.agentWidth
                        Layout.minimumWidth: root.minAgentWidth
                        Layout.maximumWidth: root.agentWidth
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        TabBar {
                            id: agentTabs
                            Layout.fillWidth: true
                            currentIndex: appSettings.lastAgentTabIndex
                            onCurrentIndexChanged: appSettings.lastAgentTabIndex = currentIndex

                            TabButton { text: "Chat" }
                            TabButton { text: "Search" }
                            TabButton { text: "Outline" }
                            TabButton { text: "Terminal" }
                            TabButton { text: "Activity" }
                            TabButton { text: "CodeMagic" }
                            TabButton { text: "Tools" }
                            TabButton { text: "Problems" }
                            TabButton { text: "Git" }
                            TabButton { text: "History" }
                        }

                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: agentTabs.currentIndex

                            ChatPanel {
                                id: agentPanel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                                model: agentCtx.chatModel
                                busy: agentCtx.busy
                                streamingText: agentCtx.streamingText
                                onSendMessage: text => agentCtx.sendMessage(text)
                                onInterrupt: agentCtx.interrupt()
                                onClearHistory: agentCtx.clearHistory()
                                onAttachImageRequested: imagePicker.open()
                                onPasteImageRequested: agentCtx.attachImageFromClipboard()
                            }

                            SearchPanel {
                                id: searchPanel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                            }

                            OutlinePanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                            }

                            TerminalPanel {
                                id: terminalPanel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                            }

                            ActivityPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                executionTimeline: agentCtx.executionTimeline
                                currentThreadId: agentCtx.currentThreadId
                            }

                            CodeMagicPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                            }

                            ToolRegistryPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                            }

                            ProblemsPanel {
                                id: problemsPanel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                            }

                            SourceControlPanel {
                                id: gitPanel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                                onDiffRequested: (file, original, modified) => editorPanel.showDiff(original, modified)
                            }

                            GitHistoryPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                agent: agentCtx
                            }
                        }
                    }
                }

                // Status Bar
                StatusBar {
                    Layout.fillWidth: true
                    agent: agentCtx
                    cursorLine: editorPanel.cursorLine
                    cursorColumn: editorPanel.cursorColumn
                }
            }
        }

        // ── Quick Open Popup (VS Code style Ctrl+P) ───────────────────────
        Popup {
            id: quickOpen
            anchors.centerIn: parent
            width: 600
            height: 400
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            padding: 0

            background: Rectangle {
                color: Theme.surface
                radius: Theme.radius
                border.color: Theme.border
                border.width: 1

                layer.enabled: true
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        spacing: 10

                        Label {
                            text: "🔍"
                            font.pixelSize: 18
                        }

                        TextField {
                            id: quickOpenInput
                            Layout.fillWidth: true
                            placeholderText: "Search files by name..."
                            font.pixelSize: Theme.fontMd
                            color: Theme.textPrimary
                            background: Item {}
                            focus: quickOpen.visible
                            onTextChanged: {
                                if (text.length === 0) {
                                    quickOpen.quickOpenResultsModel = agentCtx.workspaceRecentFiles
                                } else {
                                    quickOpenTimer.restart()
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Down) {
                                    quickOpenList.currentIndex = (quickOpenList.currentIndex + 1) % quickOpenList.count
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    quickOpenList.currentIndex = (quickOpenList.currentIndex - 1 + quickOpenList.count) % quickOpenList.count
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                    if (quickOpenList.currentItem) {
                                        quickOpenList.currentItem.select()
                                    }
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }
                }

                ListView {
                    id: quickOpenList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: quickOpenResultsModel
                    highlight: Rectangle { color: Theme.accent; opacity: 0.1 }
                    highlightFollowsCurrentItem: true

                    delegate: ItemDelegate {
                        width: quickOpenList.width
                        height: 45

                        function select() {
                            agentCtx.openEditorFile(modelData)
                            quickOpen.close()
                        }

                        onClicked: select()

                        background: Rectangle {
                            color: ListView.isCurrentItem ? Theme.accent : "transparent"
                            opacity: ListView.isCurrentItem ? 0.1 : 0
                        }

                        contentItem: ColumnLayout {
                            spacing: 2
                            Label {
                                text: modelData.split("/").pop()
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }
                            Label {
                                text: modelData
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            property var quickOpenResultsModel: []

            Timer {
                id: quickOpenTimer
                interval: 150
                repeat: false
                onTriggered: {
                    if (quickOpenInput.text.trim().length === 0) {
                        quickOpen.quickOpenResultsModel = agentCtx.workspaceRecentFiles
                        return
                    }
                    quickOpen.quickOpenResultsModel = agentCtx.searchWorkspacePaths(quickOpenInput.text)
                }
            }

            onOpened: {
                quickOpenInput.text = ""
                quickOpen.quickOpenResultsModel = agentCtx.workspaceRecentFiles
                quickOpenInput.forceActiveFocus()
            }
        }

        // ── Command Palette (VS Code style Ctrl+Shift+P) ──────────────────
        CommandPalette {
            id: commandPalette
            allCommands: [
                { id: "ai.explain", title: "AI: Explain current file", description: "Use CodeMagic to explain the current file structure and logic", action: () => agentCtx.explainCurrentFileWithCodeMagic() },
                { id: "ai.review",  title: "AI: Review current file",  description: "Use CodeMagic to find potential issues and improvements", action: () => agentCtx.reviewCurrentFileWithCodeMagic() },
                { id: "ai.analyze", title: "AI: Analyze current file", description: "Perform deep architectural analysis of the current file", action: () => agentCtx.analyzeCurrentFileWithCodeMagic() },
                { id: "ws.index",   title: "Workspace: Index Knowledge", description: "Index all files in the workspace for semantic search", action: () => agentCtx.indexWorkspaceKnowledge() },
                { id: "ws.open",    title: "File: Open Folder...", category: "File", action: () => agentCtx.openWorkspaceFolder() },
                { id: "ws.openFile", title: "File: Open Workspace File...", category: "File", action: () => agentCtx.openWorkspaceFile() },
                { id: "ws.recent",  title: "File: Open Recent...", category: "File", action: () => openRecentPopup.open() },
                { id: "ws.close",   title: "File: Close Folder", category: "File", action: () => agentCtx.workspacePath = "" },
                { id: "editor.save", title: "File: Save", shortcut: "Ctrl+S", action: () => editorPanel.saveCurrentFile() },
                { id: "editor.reload", title: "File: Reload from disk", action: () => editorPanel.syncFromAgent(true) },
                { id: "editor.goto", title: "Go to Line", shortcut: "Ctrl+G", action: () => goToLinePopup.open() },
                { id: "editor.gotoSymbol", title: "Go to Symbol in Editor...", shortcut: "Ctrl+Shift+O", action: () => goToSymbolPopup.open() },
                { id: "editor.gotoWorkspaceSymbol", title: "Go to Symbol in Workspace...", shortcut: "Ctrl+T", action: () => goToWorkspaceSymbolPopup.open() },
                { id: "editor.bracket.jump", title: "Editor: Jump to Matching Bracket", shortcut: "Ctrl+Shift+\\", action: () => editorPanel.jumpToMatchingBracket() },
                { id: "editor.word.deleteForward", title: "Editor: Delete Word Forward", shortcut: "Ctrl+Delete", action: () => editorPanel.deleteWordForward() },
                { id: "editor.word.deleteBackward", title: "Editor: Delete Word Backward", shortcut: "Ctrl+Backspace", action: () => editorPanel.deleteWordBackward() },
                { id: "editor.case.upper", title: "Editor: Convert to UPPERCASE", action: () => editorPanel.transformSelection(0) },
                { id: "editor.case.lower", title: "Editor: Convert to lowercase", action: () => editorPanel.transformSelection(1) },
                { id: "editor.case.title", title: "Editor: Convert to Title Case", action: () => editorPanel.transformSelection(2) },
                { id: "editor.case.camel", title: "Editor: Convert to camelCase", action: () => editorPanel.transformSelection(3) },
                { id: "editor.case.snake", title: "Editor: Convert to snake_case", action: () => editorPanel.transformSelection(4) },
                { id: "editor.line.delete", title: "Editor: Delete Line", shortcut: "Ctrl+Shift+K", action: () => editorPanel.executeEditorCommand("editor.action.deleteLines") },
                { id: "editor.line.moveUp", title: "Editor: Move Line Up", shortcut: "Alt+Up", action: () => editorPanel.executeEditorCommand("editor.action.moveLinesUpAction") },
                { id: "editor.line.moveDown", title: "Editor: Move Line Down", shortcut: "Alt+Down", action: () => editorPanel.executeEditorCommand("editor.action.moveLinesDownAction") },
                { id: "editor.line.duplicate", title: "Editor: Duplicate Selection", shortcut: "Ctrl+Shift+D", action: () => editorPanel.executeEditorCommand("editor.action.duplicateSelection") },
                { id: "editor.line.sortAsc", title: "Editor: Sort Lines Ascending", action: () => editorPanel.executeEditorCommand("editor.action.sortLinesAscending") },
                { id: "editor.line.sortDesc", title: "Editor: Sort Lines Descending", action: () => editorPanel.executeEditorCommand("editor.action.sortLinesDescending") },
                { id: "editor.comment.toggle", title: "Editor: Toggle Line Comment", shortcut: "Ctrl+/", action: () => editorPanel.executeEditorCommand("editor.action.commentLine") },
                { id: "editor.comment.block", title: "Editor: Toggle Block Comment", shortcut: "Ctrl+Shift+/", action: () => editorPanel.executeEditorCommand("editor.action.blockComment") },
                { id: "view.toggleSidebar", title: "View: Toggle Sidebar", shortcut: "Ctrl+B", action: () => sidebarVisible = !sidebarVisible },
                { id: "view.search", title: "View: Show Search Pane", shortcut: "Ctrl+Shift+F", action: () => { agentTabs.currentIndex = 1; } },
                { id: "view.outline", title: "View: Show Outline Pane", action: () => { agentTabs.currentIndex = 2; } },
                { id: "view.terminal", title: "View: Show Terminal", shortcut: "Ctrl+`", action: () => { agentTabs.currentIndex = 3; } },
                { id: "view.git", title: "View: Show Source Control", action: () => { agentTabs.currentIndex = 8; } },
                { id: "view.gitHistory", title: "View: Show Git History", action: () => { agentTabs.currentIndex = 9; } },
                { id: "view.problems", title: "View: Show Problems", action: () => { agentTabs.currentIndex = 7; } }
            ]
            onCommandSelected: cmdId => {
                // The current CommandPalette.qml uses commandId signal
                const found = allCommands.find(c => c.id === cmdId)
                if (found && found.action) found.action();
            }
        }

        GoToLinePopup {
            id: goToLinePopup
            onLineEntered: line => editorPanel.goToLine(line)
        }

        GoToSymbolPopup {
            id: goToSymbolPopup
            agent: agentCtx
        }

        GoToWorkspaceSymbolPopup {
            id: goToWorkspaceSymbolPopup
            agent: agentCtx
        }

        Popup {
            id: openRecentPopup
            anchors.centerIn: parent
            width: 600
            height: 400
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            padding: 0

            background: Rectangle {
                color: Theme.surface
                radius: Theme.radius
                border.color: Theme.border
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    color: "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        Label { text: "Recent Workspaces"; font.pixelSize: Theme.fontMd; color: Theme.textPrimary; font.bold: true }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                }

                ListView {
                    id: recentList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.recentWorkspaces
                    delegate: ItemDelegate {
                        width: recentList.width
                        height: 50
                        onClicked: {
                            agentCtx.workspacePath = modelData
                            openRecentPopup.close()
                        }
                        background: Rectangle {
                            color: hovered ? Theme.accent : "transparent"
                            opacity: 0.1
                        }
                        contentItem: ColumnLayout {
                            spacing: 2
                            Label {
                                text: modelData.split("/").pop()
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }
                            Label {
                                text: modelData
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Global Shortcuts ──────────────────────────────────────────────────
    Shortcut {
        sequence: "Ctrl+P"
        onActivated: quickOpen.open()
    }

    Shortcut {
        sequence: "Ctrl+G"
        onActivated: {
            if (agentCtx.currentFilePath)
                goToLinePopup.open()
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+O"
        onActivated: {
            if (agentCtx.currentFilePath)
                goToSymbolPopup.open()
        }
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: goToWorkspaceSymbolPopup.open()
    }

    Shortcut {
        sequence: "Ctrl+Shift+P"
        onActivated: commandPalette.show()
    }

    Shortcut {
        sequence: "Ctrl+Shift+F"
        onActivated: { agentTabs.currentIndex = 1; }
    }

    Shortcut {
        sequence: "Ctrl+`"
        onActivated: { agentTabs.currentIndex = 3; }
    }

    Shortcut {
        sequence: "Ctrl+K,Ctrl+O"
        onActivated: agentCtx.openWorkspaceFolder()
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: openRecentPopup.open()
    }

    // ── Top toolbar ──────────────────────────────────────────────────────────────
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
                onClicked: agentCtx.openWorkspaceFolder()
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
                        onClicked: agentCtx.openWorkspaceFolder()
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

    // ── Tool approval dialog ───────────────���──────────────────────────────
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

    FileDialog {
        id: imagePicker
        title: "Attach image"
        nameFilters: [ "Images (*.png *.jpg *.jpeg *.gif *.bmp *.webp)" ]
        fileMode: FileDialog.OpenFile
        onAccepted: agentCtx.attachImageFromPath(selectedFile.toString())
    }

    FileDialog {
        id: workspaceFilePicker
        title: "Open Workspace File"
        nameFilters: [ "Workspace Files (*.code-workspace)", "All Files (*)" ]
        fileMode: FileDialog.OpenFile
        onAccepted: agentCtx.openWorkspaceFile(decodeURIComponent(selectedFile.toString().replace("file://", "")))
    }

    // ── File picker (uses native dialog via QML FileDialog) ───────────────
    FolderDialog {
        id: workspacePicker
        onAccepted: agentCtx.openWorkspaceFolder(decodeURIComponent(selectedFolder.toString().replace("file://", "")))
    }

    // ── State ─────────────────────────────────────────────────────────────
    property bool sidebarVisible: appSettings.sidebarVisible
    property real explorerWidth: appSettings.explorerWidth
    property real agentWidth: appSettings.agentWidth
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
        function onOpenWorkspaceFolderRequested() {
            workspacePicker.open()
        }
        function onOpenWorkspaceFileRequested() {
            workspaceFilePicker.open()
        }
        function onWorkspacePathChanged() {
            if (agentCtx.workspacePath) {
                root.addRecentWorkspace(agentCtx.workspacePath)
            }
        }
        function onCurrentFilePathChanged() {
            // Close diff mode when switching files normally
            editorPanel.closeDiff()
        }
        function onToolApprovalRequired(callId, toolName, summary, riskLevel) {
            approvalDialog.show(callId, toolName, summary, riskLevel)
        }
        function onCheckpointRestoreRequested(checkpointId, description, files) {
            checkpointRestoreDialog.show(checkpointId, description, files)
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
