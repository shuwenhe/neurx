import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    required property var agent

    property var stagedChanges: []
    property var unstagedChanges: []
    property bool isGitRepo: false
    property bool refreshing: false
    property string commitMessage: ""

    signal diffRequested(string file, string original, string modified)

    function refresh() {
        if (!agent.workspacePath) return
        refreshing = true

        // Check if git repo
        const checkGit = agent.executeToolByName("Bash", { "command": "git rev-parse --is-inside-work-tree" })
        if (checkGit && checkGit.result && checkGit.result.includes("true")) {
            isGitRepo = true
        } else {
            isGitRepo = false
            refreshing = false
            return
        }

        // Get status
        const statusResult = agent.executeToolByName("Bash", { "command": "git status --porcelain" })
        if (statusResult && statusResult.result) {
            parseStatus(statusResult.result)
        } else {
            stagedChanges = []
            unstagedChanges = []
        }
        refreshing = false
    }

    function parseStatus(output) {
        const staged = []
        const unstaged = []
        const lines = output.trim().split('\n')

        lines.forEach(line => {
            if (line.trim() === "") return
            const x = line[0]
            const y = line[1]
            const file = line.slice(3)

            // X is status in index, Y is status in work tree
            // If X is not ' ' and not '?', it's staged (partially or fully)
            if (x !== ' ' && x !== '?') {
                staged.push({ file: file, status: x, fullPath: agent.workspacePath + "/" + file })
            }
            if (y !== ' ' || x === '?') {
                unstaged.push({ file: file, status: y === ' ' ? x : y, fullPath: agent.workspacePath + "/" + file })
            }
        })

        stagedChanges = staged
        unstagedChanges = unstaged
    }

    function stageFile(file) {
        agent.executeToolByName("Bash", { "command": "git add \"" + file + "\"" })
        refresh()
    }

    function unstageFile(file) {
        agent.executeToolByName("Bash", { "command": "git reset HEAD \"" + file + "\"" })
        refresh()
    }

    function stageAll() {
        agent.executeToolByName("Bash", { "command": "git add ." })
        refresh()
    }

    function commit() {
        if (!commitMessage.trim()) return
        const result = agent.executeToolByName("Bash", { "command": "git commit -m \"" + commitMessage.replace(/"/g, '\\"') + "\"" })
        commitMessage = ""
        refresh()
    }

    function push() {
        agent.executeToolByName("Bash", { "command": "git push" })
        refresh()
    }

    function pull() {
        agent.executeToolByName("Bash", { "command": "git pull" })
        refresh()
    }

    Component.onCompleted: refresh()

    Connections {
        target: agent
        function onWorkspacePathChanged() { refresh() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "SOURCE CONTROL"
                font.pixelSize: Theme.fontXs
                font.bold: true
                color: Theme.textMuted
                Layout.fillWidth: true
            }
            ToolButton {
                text: "↓"
                onClicked: pull()
                ToolTip.text: "Pull"
                ToolTip.visible: hovered
                flat: true
            }
            ToolButton {
                text: "↑"
                onClicked: push()
                ToolTip.text: "Push"
                ToolTip.visible: hovered
                flat: true
            }
            ToolButton {
                text: "🔄"
                onClicked: refresh()
                enabled: !refreshing
                ToolTip.text: "Refresh"
                ToolTip.visible: hovered
                flat: true
            }
        }

        // Commit Box
        Rectangle {
            Layout.fillWidth: true
            height: 100
            color: Theme.surfaceAlt
            radius: Theme.radius
            border.color: Theme.border
            visible: isGitRepo

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                TextArea {
                    id: commitInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "Message (Ctrl+Enter to commit)"
                    text: root.commitMessage
                    onTextChanged: root.commitMessage = text
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSm
                    background: null
                    wrapMode: TextArea.Wrap
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return && event.modifiers === Qt.ControlModifier) {
                            commit()
                        }
                    }
                }
                Button {
                    text: "Commit"
                    Layout.fillWidth: true
                    onClicked: commit()
                    enabled: commitMessage.trim() !== "" && stagedChanges.length > 0
                    background: Rectangle {
                        color: parent.enabled ? Theme.accent : Theme.surface
                        radius: 4
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // Changes List
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: isGitRepo

            ColumnLayout {
                width: parent.width
                spacing: 15

                // Staged Changes
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: stagedChanges.length > 0
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "STAGED CHANGES"; font.pixelSize: Theme.fontXs; font.bold: true; color: Theme.textMuted; Layout.fillWidth: true }
                        ToolButton { text: "-"; onClicked: agent.executeToolByName("Bash", { "command": "git reset HEAD ." }); refresh() }
                    }
                    Repeater {
                        model: stagedChanges
                        delegate: changeDelegate
                    }
                }

                // Unstaged Changes
                ColumnLayout {
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: unstagedChanges.length > 0 ? "CHANGES" : "NO CHANGES"; font.pixelSize: Theme.fontXs; font.bold: true; color: Theme.textMuted; Layout.fillWidth: true }
                        ToolButton { text: "+"; onClicked: stageAll() }
                    }
                    Repeater {
                        model: unstagedChanges
                        delegate: changeDelegate
                    }
                }
            }
        }

        Label {
            text: "The opened folder has no git repository."
            visible: !isGitRepo && !refreshing
            color: Theme.textMuted
            Layout.alignment: Qt.AlignCenter
        }
    }

    Component {
        id: changeDelegate
        ItemDelegate {
            width: parent.width
            height: 32

            onClicked: {
                const res = agent.executeToolByName("Bash", { "command": "git show HEAD:\"" + modelData.file + "\"" })
                const original = (res && res.result) ? res.result : ""

                // Ensure the file is open in editor first to get current content
                agent.openEditorFile(modelData.fullPath)
                root.diffRequested(modelData.file, original, agent.currentFileContent)
            }

            contentItem: RowLayout {
                spacing: 8
                Label {
                    text: modelData.status
                    color: {
                        if (modelData.status === 'A' || modelData.status === '?') return "#4EC9B0" // Added/Untracked
                        if (modelData.status === 'M') return "#CE9178" // Modified
                        if (modelData.status === 'D') return "#F48771" // Deleted
                        return Theme.textPrimary
                    }
                    font.bold: true
                    font.pixelSize: Theme.fontSm
                    Layout.preferredWidth: 15
                }
                Label {
                    text: modelData.file
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSm
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                ToolButton {
                    text: (stagedChanges.includes(modelData)) ? "-" : "+"
                    flat: true
                    visible: hovered
                    onClicked: {
                        if (stagedChanges.includes(modelData)) unstageFile(modelData.file)
                        else stageFile(modelData.file)
                    }
                }
            }
            background: Rectangle {
                color: hovered ? Theme.surfaceAlt : "transparent"
            }
        }
    }
}
