import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtCore
import NeurXCode

// ── FileTreePanel ─────────────────────────────────────────────────────────────
//  Left sidebar with a directory listing for the open workspace.

Item {
    id: root

    required property var agent

    signal fileClicked(string path)

    property var expandedPaths: ({})
    property var searchExpandedPaths: ({})
    property var searchMatches: []
    property string searchFocusPath: ""
    property string filterText: ""
    property string pendingActionMode: ""
    property string pendingTargetPath: ""
    property string pendingTargetDirPath: ""
    property string pendingName: ""
    property string pendingDeletePath: ""
    property string pendingDeleteName: ""
    property bool entryDialogVisible: entryDialog.visible
    property bool deleteDialogVisible: deleteDialog.visible

    // Root path for the disk browser (navigable by the user).
    property string diskRoot: "/"

    Settings {
        id: treeSettings
        property string expandedPathsByWorkspaceJson: "{}"
        property string diskRoot: "/"
    }

    function expandedPathsByWorkspace() {
        try {
            return JSON.parse(treeSettings.expandedPathsByWorkspaceJson || "{}")
        } catch (e) {
            return {}
        }
    }

    function normalizedPath(path) {
        if (path === undefined || path === null)
            return ""
        let text = path.toString()
        try {
            text = decodeURIComponent(text)
        } catch (e) {
        }
        // FolderListModel.filePath is typically a file:// URL.
        // Strip the URL scheme while preserving the leading '/' in absolute paths.
        if (text.startsWith("file://"))
            text = text.slice(7)
        return text.replace(/\\/g, "/")
    }

    function saveExpandedPaths() {
        const workspace = root.agent.workspacePath || ""
        const byWorkspace = expandedPathsByWorkspace()
        byWorkspace[workspace] = Object.keys(expandedPaths)
        treeSettings.expandedPathsByWorkspaceJson = JSON.stringify(byWorkspace)
    }

    function restoreExpandedPaths() {
        const workspace = root.agent.workspacePath || ""
        const byWorkspace = expandedPathsByWorkspace()
        const saved = byWorkspace[workspace] || []
        const next = {}
        for (let i = 0; i < saved.length; ++i)
            next[saved[i]] = true
        expandedPaths = next
    }

    function isExpanded(path) {
        return !!expandedPaths[path]
    }

    function setExpanded(path, expanded) {
        const next = Object.assign({}, expandedPaths)
        if (expanded)
            next[path] = true
        else
            delete next[path]
        expandedPaths = next
        root.saveExpandedPaths()
    }

    function clearExpandedPaths() {
        expandedPaths = ({})
        root.saveExpandedPaths()
    }

    function isSearchExpanded(path) {
        return !!searchExpandedPaths[path]
    }

    function hasSearchDescendant(path) {
        const query = root.filterText.trim()
        if (!query)
            return true
        const matches = root.searchMatches || []
        const prefix = path.endsWith("/") ? path : path + "/"
        for (let i = 0; i < matches.length; ++i) {
            const candidate = matches[i]
            if (candidate === path || candidate.startsWith(prefix))
                return true
        }
        return false
    }

    function currentDirForPath(path) {
        path = normalizedPath(path)
        if (!path)
            return root.agent.workspacePath || ""
        const idx = path.lastIndexOf("/")
        if (idx <= 0)
            return root.agent.workspacePath || ""
        return path.slice(0, idx)
    }

    function baseName(path) {
        path = normalizedPath(path)
        if (!path)
            return ""
        const parts = path.split("/")
        return parts[parts.length - 1]
    }

    function openCreateDialog(dirPath, directory) {
        pendingActionMode = directory ? "new-folder" : "new-file"
        pendingTargetDirPath = dirPath || root.agent.workspacePath || ""
        pendingTargetPath = ""
        pendingName = directory ? "new_folder" : "new_file.txt"
        entryDialog.open()
    }

    function openRenameDialog(path) {
        pendingActionMode = "rename"
        pendingTargetPath = path
        pendingTargetDirPath = currentDirForPath(path)
        pendingName = baseName(path)
        entryDialog.open()
    }

    function openDeleteDialog(path) {
        pendingDeletePath = path
        pendingDeleteName = baseName(path)
        deleteDialog.open()
    }

    function submitEntryDialog() {
        const name = nameField.text.trim()
        if (!name)
            return

        let ok = false
        if (pendingActionMode === "rename") {
            ok = root.agent.renameWorkspacePath(pendingTargetPath, name)
        } else {
            ok = root.agent.createWorkspaceEntry(pendingTargetDirPath, name, pendingActionMode === "new-folder")
        }

        if (ok) {
            if (pendingActionMode !== "rename")
                root.setExpanded(pendingTargetDirPath, true)
            root.updateSearchExpansion()
            root.revealCurrentFile()
            entryDialog.close()
        }
    }

    function submitDeleteDialog() {
        const ok = root.agent.deleteWorkspacePath(pendingDeletePath)
        if (ok) {
            root.updateSearchExpansion()
            root.revealCurrentFile()
            deleteDialog.close()
        }
    }

    function updateSearchExpansion() {
        const query = root.filterText.trim()
        if (!query || !root.agent.workspacePath) {
            searchExpandedPaths = ({})
            searchMatches = []
            searchFocusPath = ""
            return
        }

        const matches = root.agent.searchWorkspacePaths(query)
        searchMatches = matches
        searchFocusPath = matches.length ? matches[0] : ""
        const next = {}
        const workspace = root.agent.workspacePath

        for (let i = 0; i < matches.length; ++i) {
            const filePath = matches[i]
            if (!filePath.startsWith(workspace))
                continue

            const rel = filePath.slice(workspace.length).replace(/^\/+/, "")
            if (!rel)
                continue

            const parts = rel.split("/")
            let current = workspace
            for (let j = 0; j < parts.length - 1; ++j) {
                current += "/" + parts[j]
                next[current] = true
            }
        }

        searchExpandedPaths = next
        if (searchFocusPath)
            searchFocusTimer.restart()
    }

    function expandAncestors(filePath) {
        if (!filePath || !root.agent.workspacePath)
            return

        const workspace = root.agent.workspacePath
        if (!filePath.startsWith(workspace))
            return

        const rel = filePath.slice(workspace.length).replace(/^\/+/, "")
        if (!rel)
            return

        const parts = rel.split("/")
        let current = workspace
        for (let i = 0; i < parts.length - 1; ++i) {
            current += "/" + parts[i]
            root.setExpanded(current, true)
        }
    }

    function ensureCurrentFileRoot(filePath) {
        if (!filePath)
            return false

        const currentRoot = root.diskRoot || "/"
        if (filePath === currentRoot || filePath.startsWith(currentRoot.endsWith("/") ? currentRoot : currentRoot + "/"))
            return false

        const workspace = root.agent.workspacePath || ""
        if (workspace && (filePath === workspace || filePath.startsWith(workspace + "/"))) {
            root.diskRoot = workspace
            return true
        }

        root.diskRoot = "/"
        return true
    }

    function findObjectByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        const children = item.children || []
        for (let i = 0; i < children.length; ++i) {
            const found = root.findObjectByName(children[i], name)
            if (found)
                return found
        }
        return null
    }

    function scrollCurrentFileIntoView() {
        root.scrollPathIntoView(root.agent.currentFilePath)
    }

    function revealCurrentFile() {
        const changedRoot = root.ensureCurrentFileRoot(root.agent.currentFilePath)
        root.expandAncestors(root.agent.currentFilePath)
        if (changedRoot)
            Qt.callLater(() => Qt.callLater(() => root.scrollCurrentFileIntoView()))
        else
            Qt.callLater(() => root.scrollCurrentFileIntoView())
    }

    function scrollPathIntoView(path) {
        const marker = root.findObjectByName(treeFlick.contentItem, path)
        treeFlick.currentFileMarker = marker
        if (!marker)
            return

        const pos = marker.mapToItem(treeFlick.contentItem, 0, 0)
        const target = Math.max(0, pos.y - treeFlick.height / 2 + marker.height / 2)
        treeFlick.contentY = Math.max(0, Math.min(target, treeFlick.contentHeight - treeFlick.height))
    }

    Timer {
        id: searchFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.scrollPathIntoView(root.searchFocusPath)
    }

    Dialog {
        id: entryDialog
        modal: true
        implicitWidth: 360
        title: pendingActionMode === "rename"
            ? "Rename"
            : (pendingActionMode === "new-folder" ? "New Folder" : "New File")
        closePolicy: Popup.CloseOnEscape
        onOpened: {
            nameField.text = pendingName
            nameField.forceActiveFocus()
            nameField.selectAll()
        }

        contentItem: ColumnLayout {
            width: 320
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: pendingActionMode === "rename"
                      ? "Enter a new name."
                      : "Enter a name for the new item."
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }

            TextField {
                id: nameField
                objectName: "treeNameField"
                Layout.fillWidth: true
                placeholderText: pendingActionMode === "rename" ? "Rename to..." : "Name"
                onAccepted: root.submitEntryDialog()
            }
        }

        footer: Rectangle {
            color: "transparent"
            implicitHeight: 56

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: entryDialog.close()
                }

                Button {
                    text: pendingActionMode === "rename" ? "Rename" : "Create"
                    highlighted: true
                    onClicked: root.submitEntryDialog()
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        modal: true
        implicitWidth: 380
        title: "Delete"
        closePolicy: Popup.CloseOnEscape
        onOpened: {
            deleteConfirmButton.forceActiveFocus()
        }

        contentItem: ColumnLayout {
            width: 340
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: "Delete \"" + pendingDeleteName + "\"? This cannot be undone."
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }
        }

        footer: Rectangle {
            color: "transparent"
            implicitHeight: 56

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: deleteDialog.close()
                }

                Button {
                    id: deleteConfirmButton
                    text: "Delete"
                    highlighted: true
                    onClicked: root.submitDeleteDialog()
                }
            }
        }
    }

    Connections {
        target: root.agent
        function onCurrentFilePathChanged() {
            root.revealCurrentFile()
        }
        function onWorkspacePathChanged() {
            root.restoreExpandedPaths()
            root.updateSearchExpansion()
            root.revealCurrentFile()
        }
    }

    onFilterTextChanged: {
        root.updateSearchExpansion()
    }

    Component.onCompleted: {
        // Prefer workspace path as the initial disk root when available.
        // If no workspace is set, avoid defaulting to the user's home directory
        // which previously caused the explorer to stay stuck on `/home`.
        if (root.agent && root.agent.workspacePath) {
            root.diskRoot = root.agent.workspacePath || (treeSettings.diskRoot || "/")
        } else {
            // If the saved diskRoot points to a home directory, prefer the filesystem root instead
            const saved = treeSettings.diskRoot || "/"
            if (saved.startsWith("/home/") || saved === "/home")
                root.diskRoot = "/"
            else
                root.diskRoot = saved
        }
        root.restoreExpandedPaths()
        root.updateSearchExpansion()
        root.revealCurrentFile()
    }

    onDiskRootChanged: {
        treeSettings.diskRoot = root.diskRoot
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: Theme.surfaceAlt

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                    spacing: 4

                    // "Go up" button
                    ToolButton {
                        text: "↑"
                        font.pixelSize: Theme.fontSm
                        padding: 2
                        enabled: root.diskRoot !== "/"
                        opacity: enabled ? 1.0 : 0.35
                        onClicked: {
                            const parts = root.diskRoot.replace(/\/$/, "").split("/")
                            parts.pop()
                            root.diskRoot = parts.length <= 1 ? "/" : parts.join("/")
                        }
                        ToolTip.text: "Go up one level"
                        ToolTip.visible: hovered
                    }

                    // Current root path label (click to jump to workspace)
                    Label {
                        Layout.fillWidth: true
                        text: root.diskRoot === "/" ? "LOCAL DISK  /"
                              : root.diskRoot.split("/").pop().toUpperCase() + "  " + root.diskRoot
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    // "Jump to workspace" button
                    ToolButton {
                        text: "⌂"
                        font.pixelSize: Theme.fontSm
                        padding: 2
                        visible: root.agent.workspacePath !== ""
                        onClicked: root.diskRoot = root.agent.workspacePath
                        ToolTip.text: "Jump to workspace"
                        ToolTip.visible: hovered
                    }
                }
            }

            // Open editors — VS Code flat vertical list
            Column {
                Layout.fillWidth: true
                visible: root.agent.openFiles && root.agent.openFiles.length > 0

                // Section header
                Item {
                    width: parent.width
                    height: 26

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                        spacing: 0

                        Label {
                            text: "OPEN EDITORS"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        ToolButton {
                            text: "⟲"
                            font.pixelSize: Theme.fontSm
                            padding: 2
                            onClicked: root.revealCurrentFile()
                            ToolTip.text: "Reveal active file"
                            ToolTip.visible: hovered
                        }

                        ToolButton {
                            text: "×"
                            font.pixelSize: Theme.fontSm
                            padding: 2
                            onClicked: root.clearExpandedPaths()
                            ToolTip.text: "Collapse all folders"
                            ToolTip.visible: hovered
                        }
                    }
                }

                // File rows — use model.X to avoid required-property issues
                Repeater {
                    model: root.agent.openFiles

                    delegate: Item {
                        width: parent.width
                        height: 22

                        readonly property bool isActive: model.active || false
                        readonly property bool isDirty:  model.dirty  || false

                        Rectangle {
                            anchors.fill: parent
                            color: isActive ? Theme.accent
                                   : editorRowHover.containsMouse ? Theme.surfaceAlt
                                   : "transparent"
                            opacity: isActive ? 0.15 : 1.0
                        }

                        Rectangle {
                            visible: isActive
                            width: 2; height: parent.height
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors {
                                left: parent.left; leftMargin: 16
                                right: parent.right; rightMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 5

                            Label {
                                text: isDirty ? "●" : "📄"
                                color: isDirty ? "#e5a050" : Theme.textMuted
                                font.pixelSize: Theme.fontXs
                                Layout.preferredWidth: 12
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Label {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: model.name || ""
                                color: isActive ? Theme.textPrimary : Theme.textMuted
                                font.pixelSize: Theme.fontSm
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: editorRowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.agent.openEditorFile(model.path || "")
                        }
                    }
                }
            }

            // Filter input — VS Code style
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                color: Theme.bg
                border.color: searchField.activeFocus ? Theme.accent : Theme.border
                border.width: 1
                radius: 2

            TextField {
                id: searchField
                objectName: "treeFilterField"
                    anchors { fill: parent; margins: 1 }
                    placeholderText: "Filter (e.g. .cpp)"
                    text: root.filterText
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSm
                    font.family: Theme.uiFont.family
                    leftPadding: 8
                    background: Item {}
                    onTextEdited: {
                        root.filterText = text
                        root.updateSearchExpansion()
                    }
                }
            }

            Flickable {
                id: treeFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: treeColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {}
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                property Item currentFileMarker: null

                Column {
                    id: treeColumn
                    width: treeFlick.width

                    FileTreeItem {
                        width: parent.width
                        panel: root
                        dirPath: root.diskRoot
                        depth: 0
                        filterText: root.filterText
                        onFileClicked: (path) => root.fileClicked(path)
                    }
                }
            }
        }
    }
}
