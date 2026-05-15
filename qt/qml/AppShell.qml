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
                    Layout.preferredHeight: 180
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
                    Layout.fillHeight: true

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
            }
        }
    }
}
