import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Rectangle {
    id: statusRoot
    height: 22
    color: "#2d2d30"

    required property var agent
    property int cursorLine: 1
    property int cursorColumn: 1
    property string gitBranch: ""

    function switchBranch(branch) {
        agent.executeToolByName("Bash", { "command": "git checkout " + branch })
        // Trigger refresh
        const result = agent.executeToolByName("Bash", { "command": "git branch --show-current" })
        if (result && result.result) {
            gitBranch = result.result.trim()
        }
    }

    Timer {
        interval: 10000 // Every 10 seconds
        running: agent.workspacePath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const result = agent.executeToolByName("Bash", { "command": "git branch --show-current" })
            if (result && result.result) {
                gitBranch = result.result.trim()
            } else {
                gitBranch = ""
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 15

        RowLayout {
            spacing: 5

            MouseArea {
                Layout.preferredWidth: gitBranchRow.implicitWidth
                Layout.fillHeight: true
                hoverEnabled: true

                RowLayout {
                    id: gitBranchRow
                    anchors.fill: parent
                    spacing: 5
                    Label {
                        text: "" // Git icon
                        color: "white"
                        font.pixelSize: 12
                        visible: gitBranch !== ""
                    }
                    Label {
                        text: gitBranch
                        color: "white"
                        font.pixelSize: 12
                        visible: gitBranch !== ""
                    }
                }

                onClicked: {
                    const res = agent.executeToolByName("Bash", { "command": "git branch" })
                    if (res && res.result) {
                        const branches = res.result.split("\n")
                            .map(b => b.trim())
                            .filter(b => b.length > 0)
                            .map(b => b.startsWith("*") ? b.slice(1).trim() : b)

                        branchMenu.clear()
                        branches.forEach(b => {
                            const item = branchMenu.addItem(b)
                            item.triggered.connect(() => switchBranch(b))
                        })
                        branchMenu.popup()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "white"
                    opacity: parent.containsMouse ? 0.1 : 0
                }
            }

            Label {
                text: agent.workspacePath ? agent.workspacePath.split("/").pop() : "No folder"
                color: "white"
                font.pixelSize: 12
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: 15

            Label {
                text: "Selected: " + agent.currentSelectionText.length + " chars"
                color: "white"
                font.pixelSize: 12
                visible: agent.currentSelectionText.length > 0
            }

            Label {
                text: "Ln " + cursorLine + ", Col " + cursorColumn
                color: "white"
                font.pixelSize: 12
                visible: agent.currentFilePath !== ""
            }

            Label {
                text: "UTF-8"
                color: "white"
                font.pixelSize: 12
            }

            Label {
                text: {
                    const p = agent.currentFilePath || ""
                    const dot = p.lastIndexOf(".")
                    return dot >= 0 ? p.slice(dot + 1).toUpperCase() : "Plain Text"
                }
                color: "white"
                font.pixelSize: 12
            }

            Label {
                text: "" // Feedback/Bell icon
                color: "white"
                font.pixelSize: 12
            }
        }
    }

    Menu {
        id: branchMenu
        title: "Select Branch"
    }
}
