import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NeurXCode

/**
 * ProblemsPanel.qml
 * Enhanced diagnostics panel with filtering and navigation
 */

Item {
    id: root
    required property var agent
    property var diagnosticsService

    property var problems: []
    property var filteredProblems: []
    property string searchText: ""
    property bool showErrors: true
    property bool showWarnings: true
    property bool showInfo: true

    function addProblem(message, type = "error") {
        problems.push({
            message: message,
            type: type,
            time: new Date().toLocaleTimeString(),
            file: agent.currentFilePath ? agent.currentFilePath.split("/").pop() : "System",
            fullPath: agent.currentFilePath || ""
        })
        problemsChanged()
        updateFilteredProblems()
    }

    function updateFilteredProblems() {
        filteredProblems = problems.filter(p => {
            let typeMatch = (p.type === "error" && showErrors) ||
                           (p.type === "warning" && showWarnings) ||
                           (p.type === "info" && showInfo)
            let searchMatch = searchText === "" ||
                             p.message.toLowerCase().includes(searchText.toLowerCase()) ||
                             p.file.toLowerCase().includes(searchText.toLowerCase())
            return typeMatch && searchMatch
        })
        filteredProblemsChanged()
    }

    Connections {
        target: agent
        function onErrorOccurred(message) {
            addProblem(message, "error")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#252526"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#3e3e42"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: "PROBLEMS"
                    color: "#cccccc"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                Rectangle {
                    implicitWidth: 50
                    implicitHeight: 20
                    color: "#3c3c3c"
                    border.color: "#555555"
                    border.width: 1
                    radius: 3

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: "●"
                            color: "#f48771"
                            font.pixelSize: 8
                        }

                        Text {
                            text: problems.filter(p => p.type === "error").length
                            color: "#f48771"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "●"
                            color: "#dcdcaa"
                            font.pixelSize: 8
                        }

                        Text {
                            text: problems.filter(p => p.type === "warning").length
                            color: "#dcdcaa"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Clear"
                    font.pixelSize: 11
                    palette.buttonText: "#cccccc"
                    background: Rectangle {
                        color: "#2d2d2d"
                        border.color: "#3e3e42"
                        border.width: 1
                        radius: 3
                    }
                    onClicked: {
                        problems = []
                        updateFilteredProblems()
                    }
                }
            }
        }

        // Filter bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            color: "#1e1e1e"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#3e3e42"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                CheckBox {
                    text: "Errors"
                    checked: root.showErrors
                    onToggled: {
                        root.showErrors = checked
                        updateFilteredProblems()
                    }
                }

                CheckBox {
                    text: "Warnings"
                    checked: root.showWarnings
                    onToggled: {
                        root.showWarnings = checked
                        updateFilteredProblems()
                    }
                }

                CheckBox {
                    text: "Info"
                    checked: root.showInfo
                    onToggled: {
                        root.showInfo = checked
                        updateFilteredProblems()
                    }
                }

                Item { Layout.fillWidth: true }

                TextField {
                    placeholderText: "Search..."
                    Layout.preferredWidth: 150
                    onTextChanged: {
                        root.searchText = text
                        updateFilteredProblems()
                    }
                    background: Rectangle {
                        color: "#3c3c3c"
                        border.color: "#555555"
                        border.width: 1
                        radius: 3
                    }
                }
            }
        }

        // Problems list
        ListView {
            id: problemsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.filteredProblems
            clip: true

            delegate: Rectangle {
                width: problemsList.width
                height: 56
                color: index % 2 === 0 ? "#1e1e1e" : "#252526"

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: "#3e3e42"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = parent.color === "#1e1e1e" ? "#2d2d2d" : "#333333"
                    onExited: parent.color = parent.color === "#2d2d2d" ? "#1e1e1e" : "#252526"
                    onClicked: {
                        if (modelData.fullPath) {
                            agent.openEditorFile(modelData.fullPath)
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    RowLayout {
                        spacing: 8

                        Text {
                            text: modelData.type === "error" ? "●" : (modelData.type === "warning" ? "●" : "ⓘ")
                            color: modelData.type === "error" ? "#f48771" : (modelData.type === "warning" ? "#dcdcaa" : "#6a9955")
                            font.pixelSize: 12
                        }

                        Text {
                            text: modelData.message
                            color: "#cccccc"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: modelData.file
                            color: "#858585"
                            font.pixelSize: 10
                        }

                        Text {
                            text: modelData.time
                            color: "#858585"
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: filteredProblems.length === 0
                text: problems.length === 0 ? "No problems detected" : "No matching problems"
                color: "#858585"
                font.pixelSize: 12
            }

            ScrollBar.vertical: CustomScrollBar {}
        }

        // Status bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            color: "#252526"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: "#3e3e42"
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: filteredProblems.length + " of " + problems.length
                color: "#858585"
                font.pixelSize: 10
            }
        }
    }
}
