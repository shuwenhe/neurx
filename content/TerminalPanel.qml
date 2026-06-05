import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    required property var agent

    property var history: []
    property string currentInput: ""

    function runCommand() {
        if (!currentInput.trim()) return

        const cmd = currentInput.trim()
        history.push({ type: "input", text: "$ " + cmd })
        currentInput = ""

        const result = agent.executeToolByName("Shell", { "command": cmd })

        if (result && result.result) {
            history.push({ type: "output", text: result.result })
        } else if (result && result.error) {
            history.push({ type: "error", text: result.error })
        }

        // Limit history size
        if (history.length > 100) {
            history = history.slice(history.length - 100)
        }

        terminalList.positionViewAtEnd()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label {
            text: "TERMINAL"
            font.pixelSize: Theme.fontXs
            font.bold: true
            color: Theme.textMuted
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg
            border.color: Theme.border
            radius: Theme.radius

            ListView {
                id: terminalList
                anchors.fill: parent
                anchors.margins: 8
                model: root.history
                clip: true
                spacing: 2

                delegate: Label {
                    width: terminalList.width
                    text: modelData.text
                    font.family: Theme.monoFont.family
                    font.pixelSize: Theme.fontXs
                    color: modelData.type === "input" ? Theme.accent : (modelData.type === "error" ? Theme.error : Theme.textPrimary)
                    wrapMode: Text.WrapAnywhere
                }

                ScrollBar.vertical: CustomScrollBar {}
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: Theme.surfaceAlt
            radius: Theme.radius
            border.color: commandInput.activeFocus ? Theme.accent : Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                Label {
                    text: ">"
                    color: Theme.accent
                    font.bold: true
                }

                TextField {
                    id: commandInput
                    Layout.fillWidth: true
                    text: root.currentInput
                    placeholderText: "Run shell command..."
                    font.family: Theme.monoFont.family
                    font.pixelSize: Theme.fontSm
                    color: Theme.textPrimary
                    background: Item {}
                    onTextChanged: root.currentInput = text
                    onAccepted: runCommand()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_L && event.modifiers === Qt.ControlModifier) {
                            root.history = []
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
}
