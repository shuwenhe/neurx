import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: shell

    readonly property color bg: "#09111b"
    readonly property color panel: "#101826"
    readonly property color panelAlt: "#132033"
    readonly property color border: "#203147"
    readonly property color accent: "#21c27a"
    readonly property color textPrimary: "#f4f7fb"
    readonly property color textMuted: "#89a0ba"

    property bool running: false
    property int runSteps: 4
    property int activeAssistantIndex: -1
    property string runtimeStatusText: qsTr("Ready")

    function appendMessage(role, text) {
        messageModel.append({
            role: role,
            body: text,
            timestamp: Qt.formatTime(new Date(), "hh:mm:ss")
        })
        messageView.positionViewAtEnd()
    }

    function sendPrompt() {
        var text = promptField.text.trim()
        if (!text.length || running) {
            return
        }
        appendMessage("user", text)
        messageModel.append({
            role: "assistant",
            body: "",
            timestamp: Qt.formatTime(new Date(), "hh:mm:ss")
        })
        activeAssistantIndex = messageModel.count - 1
        running = true
        runtimeStatusText = qsTr("Running")
        Runtime.run_agent_auto_async(text, "", runSteps)
        promptField.text = ""
    }

    ListModel {
        id: messageModel
    }

    // ── QR scanner result popup ──────────────────────────────────────────────
    Connections {
        target: QrScanner

        function onQrCodeFound(code) {
            qrResultPopup.resultText = code
            qrResultPopup.open()
        }

        function onScanCancelled() {
            // No-op: user cancelled, nothing to show.
        }
    }

    Popup {
        id: qrResultPopup
        property string resultText: ""
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 400)
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 20

        background: Rectangle {
            radius: 16
            color: shell.panel
            border.color: shell.border
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
                text: qsTr("扫码结果")
                color: shell.accent
                font.pixelSize: 16
                font.bold: true
            }

            TextEdit {
                Layout.fillWidth: true
                text: qrResultPopup.resultText
                color: shell.textPrimary
                font.pixelSize: 13
                wrapMode: Text.WrapAnywhere
                readOnly: true
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: "#0d1520"
                    border.color: shell.border
                }
                leftPadding: 8; rightPadding: 8
                topPadding: 8; bottomPadding: 8
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    text: qsTr("发送到对话")
                    Layout.fillWidth: true
                    onClicked: {
                        if (qrResultPopup.resultText.length > 0) {
                            promptField.text = qrResultPopup.resultText
                        }
                        qrResultPopup.close()
                    }
                }

                Button {
                    text: qsTr("关闭")
                    onClicked: qrResultPopup.close()
                }
            }
        }
    }

    Connections {
        target: Runtime

        function onAgentRunFinished(result) {
            if (shell.activeAssistantIndex >= 0 && shell.activeAssistantIndex < messageModel.count) {
                messageModel.setProperty(shell.activeAssistantIndex, "body", result)
            } else {
                shell.appendMessage("assistant", result)
            }
            shell.activeAssistantIndex = -1
            shell.running = false
            shell.runtimeStatusText = qsTr("Completed")
            messageView.positionViewAtEnd()
        }

        function onAgentRunChunk(chunk) {
            if (shell.activeAssistantIndex < 0 || shell.activeAssistantIndex >= messageModel.count) {
                return
            }
            var current = messageModel.get(shell.activeAssistantIndex).body || ""
            messageModel.setProperty(shell.activeAssistantIndex, "body", current + chunk)
            messageView.positionViewAtEnd()
        }

        function onRuntime_status_changed(status, task) {
            shell.runtimeStatusText = task && task.length ? status + " / " + task : status
        }
    }

    Rectangle {
        anchors.fill: parent
        color: shell.bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            radius: 18
            color: shell.panel
            border.color: shell.border
            implicitHeight: headerLayout.implicitHeight + 24

            ColumnLayout {
                id: headerLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Text {
                    text: qsTr("NeurX Mobile Agent")
                    color: shell.textPrimary
                    font.pixelSize: 24
                    font.bold: true
                }

                Text {
                    text: shell.runtimeStatusText
                    color: shell.accent
                    font.pixelSize: 13
                    wrapMode: Text.WrapAnywhere
                }

                Repeater {
                    model: AgentModel

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: name
                            color: shell.textPrimary
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: status
                            color: shell.textMuted
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Text {
                    text: Runtime.local_model_summary()
                    color: shell.textMuted
                    font.pixelSize: 11
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true

            TabButton { text: qsTr("Chat") }
            TabButton { text: qsTr("Logs") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            Rectangle {
                color: "transparent"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    ListView {
                        id: messageView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 10
                        model: messageModel

                        delegate: Item {
                            width: messageView.width
                            height: bubble.implicitHeight + 8

                            Rectangle {
                                id: bubble
                                width: Math.min(parent.width * 0.86, bubbleColumn.implicitWidth + 24)
                                anchors.right: model.role === "user" ? parent.right : undefined
                                anchors.left: model.role === "user" ? undefined : parent.left
                                radius: 16
                                color: model.role === "user" ? "#154734" : shell.panelAlt
                                border.color: model.role === "user" ? "#1f6f51" : shell.border
                                implicitHeight: bubbleColumn.implicitHeight + 20

                                ColumnLayout {
                                    id: bubbleColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    Text {
                                        text: model.role === "user" ? qsTr("You") : qsTr("NeurX")
                                        color: model.role === "user" ? "#baf2d2" : shell.textMuted
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.body
                                        color: shell.textPrimary
                                        wrapMode: Text.WrapAnywhere
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: model.timestamp
                                        color: shell.textMuted
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {}
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: 18
                        color: shell.panel
                        border.color: shell.border
                        implicitHeight: composerLayout.implicitHeight + 24

                        ColumnLayout {
                            id: composerLayout
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            TextArea {
                                id: promptField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                placeholderText: qsTr("Describe the Android / iOS work you want NeurX to do")
                                wrapMode: TextEdit.Wrap
                                color: shell.textPrimary
                                selectionColor: "#225c45"
                                selectedTextColor: shell.textPrimary
                                background: Rectangle {
                                    radius: 14
                                    color: "#0d1520"
                                    border.color: shell.border
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                SpinBox {
                                    id: runStepsBox
                                    from: 1
                                    to: 12
                                    value: shell.runSteps
                                    editable: true
                                    onValueModified: shell.runSteps = value
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Button {
                                    text: qsTr("扫码")
                                    enabled: !shell.running
                                    onClicked: QrScanner.startScan()
                                }

                                Button {
                                    text: shell.running ? qsTr("Running...") : qsTr("Run")
                                    enabled: !shell.running
                                    onClicked: shell.sendPrompt()
                                }

                                Button {
                                    text: qsTr("Clear")
                                    enabled: !shell.running
                                    onClicked: {
                                        messageModel.clear()
                                        shell.activeAssistantIndex = -1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                color: "transparent"

                ListView {
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    model: LogModel

                    delegate: Rectangle {
                        width: ListView.view.width
                        radius: 14
                        color: shell.panel
                        border.color: shell.border
                        implicitHeight: logColumn.implicitHeight + 18

                        ColumnLayout {
                            id: logColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: time
                                    color: shell.accent
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: level + " / " + tag
                                    color: shell.textMuted
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: message
                                color: shell.textPrimary
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: 13
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {}
                }
            }
        }
    }
}
