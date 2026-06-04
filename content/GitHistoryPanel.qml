import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    required property var agent

    property var commitLogs: []
    property bool refreshing: false

    function refresh() {
        if (!agent.workspacePath) return
        refreshing = true

        const result = agent.executeToolByName("Bash", { "command": "git log --pretty=format:\"%h|%an|%ar|%s\" -n 50" })
        if (result && result.result) {
            const lines = result.result.trim().split('\n')
            const logs = []
            lines.forEach(line => {
                if (line.trim() === "") return
                const parts = line.split('|')
                if (parts.length >= 4) {
                    logs.push({
                        hash: parts[0],
                        author: parts[1],
                        date: parts[2],
                        subject: parts.slice(3).join('|')
                    })
                }
            })
            commitLogs = logs
        } else {
            commitLogs = []
        }
        refreshing = false
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "GIT HISTORY"
                font.pixelSize: Theme.fontXs
                font.bold: true
                color: Theme.textMuted
                Layout.fillWidth: true
            }
            ToolButton {
                text: "🔄"
                onClicked: refresh()
                enabled: !refreshing
                flat: true
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                model: commitLogs
                delegate: ItemDelegate {
                    width: parent.width
                    height: 60
                    padding: 8

                    contentItem: ColumnLayout {
                        spacing: 2
                        RowLayout {
                            spacing: 8
                            Label {
                                text: modelData.hash
                                color: Theme.accent
                                font.family: Theme.monoFont.family
                                font.pixelSize: Theme.fontSm
                            }
                            Label {
                                text: modelData.author
                                color: Theme.textPrimary
                                font.bold: true
                                font.pixelSize: Theme.fontSm
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.date
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                            }
                        }
                        Label {
                            text: modelData.subject
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSm
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    background: Rectangle {
                        color: hovered ? Theme.surfaceAlt : "transparent"
                        radius: 4
                    }

                    onClicked: {
                        // Display details or diff for this commit in the future
                        const res = agent.executeToolByName("Bash", { "command": "git show --stat " + modelData.hash })
                        if (res && res.result) {
                            agent.sendMessage("Can you explain what was changed in commit " + modelData.hash + "?\n\n" + res.result)
                        }
                    }
                }
            }
        }
    }
}

