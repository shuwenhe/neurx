import QtQuick
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

                Text {
                    text: qsTr("Neurx Agent Shell")
                    color: shell.textPrimary
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
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

                Text {
                    text: qsTr("Runtime Status")
                    color: shell.textPrimary
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
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
            implicitHeight: 178
            radius: 14
            color: shell.surface
            border.color: shell.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: qsTr("Local Model")
                    color: shell.textPrimary
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: Runtime.localModelSummary
                    color: shell.textMuted
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 190
                        Layout.preferredHeight: 34
                        radius: 10
                        color: shell.panelAlt
                        border.color: shell.border

                        Text {
                            anchors.centerIn: parent
                            text: Runtime.localModelBackend === "ollama" ? qsTr("Ollama") : qsTr("OpenAI Compatible")
                            color: shell.textPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Runtime.localModelBackend = Runtime.localModelBackend === "ollama" ? "openai" : "ollama"
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 170
                        Layout.preferredHeight: 34
                        radius: 10
                        color: shell.panelAlt
                        border.color: shell.border

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 3
                                color: Runtime.localModelEnabled ? shell.accent : "transparent"
                                border.color: shell.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: qsTr("Use local model")
                                color: shell.textPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Runtime.localModelEnabled = !Runtime.localModelEnabled
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        id: baseUrlField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 10
                        color: "#121212"
                        border.color: shell.border

                        TextInput {
                            anchors.fill: parent
                            anchors.margins: 10
                            text: Runtime.localModelBaseUrl
                            color: shell.textPrimary
                            selectByMouse: true
                            selectionColor: shell.accent
                            selectedTextColor: shell.bg
                            cursorVisible: activeFocus
                            onTextEdited: Runtime.localModelBaseUrl = text
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("http://127.0.0.1:8000")
                            color: shell.textMuted
                            visible: Runtime.localModelBaseUrl.length === 0
                        }
                    }

                    Rectangle {
                        id: modelField
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 36
                        radius: 10
                        color: "#121212"
                        border.color: shell.border

                        TextInput {
                            anchors.fill: parent
                            anchors.margins: 10
                            text: Runtime.localModelName
                            color: shell.textPrimary
                            selectByMouse: true
                            selectionColor: shell.accent
                            selectedTextColor: shell.bg
                            cursorVisible: activeFocus
                            onTextEdited: Runtime.localModelName = text
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("llama3.1")
                            color: shell.textMuted
                            visible: Runtime.localModelName.length === 0
                        }
                    }

                    Rectangle {
                        id: chatPathField
                        Layout.preferredWidth: 250
                        Layout.preferredHeight: 36
                        radius: 10
                        color: "#121212"
                        border.color: shell.border

                        TextInput {
                            anchors.fill: parent
                            anchors.margins: 10
                            text: Runtime.localModelChatPath
                            color: shell.textPrimary
                            selectByMouse: true
                            selectionColor: shell.accent
                            selectedTextColor: shell.bg
                            cursorVisible: activeFocus
                            onTextEdited: Runtime.localModelChatPath = text
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("/v1/chat/completions")
                            color: shell.textMuted
                            visible: Runtime.localModelChatPath.length === 0
                        }
                    }
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

                    Text {
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

                                Text {
                                    text: name
                                    color: shell.textPrimary
                                    font.bold: true
                                }

                                Text {
                                    text: agentId
                                    color: shell.textMuted
                                }

                                Text {
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

                    Text {
                        text: qsTr("Prompt")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        radius: 12
                        color: "#121212"
                        border.color: shell.border

                        TextEdit {
                            id: promptEditor
                            anchors.fill: parent
                            anchors.margins: 10
                            text: ""
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            selectionColor: shell.accent
                            selectedTextColor: shell.bg
                            focus: true
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            text: qsTr("Ask the agent to inspect files, summarize state, or run a minimal workflow")
                            color: shell.textMuted
                            visible: promptEditor.text.length === 0 && !promptEditor.activeFocus
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 36
                            radius: 10
                            color: shell.accent

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Run Agent")
                                color: shell.bg
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var prompt = promptEditor.text.trim()
                                    if (!prompt)
                                        prompt = "hello"
                                    resultOutput.text = Runtime.run_agent(prompt, 4)
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 136
                            Layout.preferredHeight: 36
                            radius: 10
                            color: "#202020"
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Refresh Status")
                                color: shell.textPrimary
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: runtimeStatus.text = Runtime.ping()
                            }
                        }
                    }

                    Text {
                        text: qsTr("Result")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        radius: 12
                        color: "#121212"
                        border.color: shell.border

                        TextEdit {
                            id: resultOutput
                            anchors.fill: parent
                            anchors.margins: 10
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            text: qsTr("Run the agent to see output here.")
                        }
                    }

                    Text {
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

                                Text {
                                    text: time
                                    color: shell.textMuted
                                    width: 64
                                }

                                Text {
                                    text: level
                                    color: level === "error" ? "#ff6b6b" : (level === "warning" ? "#ffb347" : shell.accent)
                                    width: 56
                                }

                                Text {
                                    text: tag
                                    color: shell.textPrimary
                                    width: 64
                                }

                                Text {
                                    text: message
                                    color: shell.textMuted
                                    width: Math.max(0, parent.width - 220)
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
