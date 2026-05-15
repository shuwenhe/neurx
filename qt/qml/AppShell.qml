import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: shell

    readonly property color bg: "#111111"
    readonly property color surface: "#1a1a1a"
    readonly property color border: "#2b2b2b"
    readonly property color accent: "#19a974"
    readonly property color textPrimary: "#f3f3f3"
    readonly property color textMuted: "#a0a0a0"
    readonly property color panelAlt: "#151515"

    Rectangle {
        anchors.fill: parent
        color: shell.bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 92
            radius: 16
            color: shell.surface
            border.color: shell.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                Label {
                    text: qsTr("Neurx Agent Shell")
                    color: shell.textPrimary
                    font.pixelSize: 28
                    font.bold: true
                }

                Label {
                    text: qsTr("Migrated QML shell backed by neurx/agent and the Qt bridge runtime.")
                    color: shell.textMuted
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 84
            radius: 14
            color: shell.surface
            border.color: shell.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Label {
                    text: qsTr("Runtime Status")
                    color: shell.textPrimary
                    font.pixelSize: 16
                    font.bold: true
                }

                Label {
                    id: runtimeStatus
                    text: Runtime.ping()
                    color: shell.textMuted
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: qsTr("Agents")
                        color: shell.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: AgentModel
                        spacing: 10
                        clip: true

                        delegate: Rectangle {
                            required property string agentId
                            required property string name
                            required property string status

                            width: ListView.view.width
                            height: 82
                            radius: 14
                            color: shell.panelAlt
                            border.color: shell.border

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                Label {
                                    text: name
                                    color: shell.textPrimary
                                    font.bold: true
                                }

                                Label {
                                    text: agentId
                                    color: shell.textMuted
                                }

                                Label {
                                    text: status
                                    color: shell.accent
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Label {
                        text: qsTr("Prompt")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    TextArea {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        placeholderText: qsTr("Ask the agent to inspect files, summarize state, or run a minimal workflow")
                        wrapMode: TextEdit.Wrap
                        color: shell.textPrimary
                        selectionColor: shell.accent
                        selectedTextColor: shell.bg
                        background: Rectangle {
                            radius: 12
                            color: "#121212"
                            border.color: shell.border
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Button {
                            text: qsTr("Run Agent")
                            onClicked: {
                                var prompt = promptInput.text.trim()
                                if (!prompt)
                                    prompt = "hello"
                                resultOutput.text = Runtime.run_agent(prompt, 4)
                            }

                            background: Rectangle {
                                radius: 10
                                color: parent.down ? "#14815b" : shell.accent
                            }

                            contentItem: Label {
                                text: parent.text
                                color: shell.bg
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.bold: true
                            }
                        }

                        Button {
                            text: qsTr("Refresh Status")
                            onClicked: runtimeStatus.text = Runtime.ping()

                            background: Rectangle {
                                radius: 10
                                color: "#202020"
                                border.color: shell.border
                            }

                            contentItem: Label {
                                text: parent.text
                                color: shell.textPrimary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Label {
                        text: qsTr("Result")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120

                        TextArea {
                            id: resultOutput
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            text: qsTr("Run the agent to see output here.")
                            background: Rectangle {
                                radius: 12
                                color: "#121212"
                                border.color: shell.border
                            }
                        }
                    }

                    Label {
                        text: qsTr("Runtime Log")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: shell.panelAlt
                        border.color: shell.border

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 12
                            model: LogModel
                            spacing: 8
                            clip: true

                            delegate: Row {
                                required property string time
                                required property string level
                                required property string tag
                                required property string message

                                width: ListView.view.width
                                spacing: 8

                                Label {
                                    text: time
                                    color: shell.textMuted
                                    width: 64
                                }

                                Label {
                                    text: level
                                    color: level === "error" ? "#ff6b6b" : (level === "warning" ? "#ffb347" : shell.accent)
                                    width: 56
                                }

                                Label {
                                    text: tag
                                    color: shell.textPrimary
                                    width: 64
                                }

                                Label {
                                    text: message
                                    color: shell.textMuted
                                    width: ListView.view.width - 220
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
