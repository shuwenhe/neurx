import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

// ── ChatPanel ─────────────────────────────────────────────────────────────────
//  Right-side agent panel: message list on top, send controls at bottom.

Item {
    id: root

    required property var    model         // ChatModel*
    required property var    agent
    required property bool   busy
    required property string streamingText

    signal sendMessage(string text)
    signal interrupt()
    signal clearHistory()
    signal attachImageRequested()
    signal pasteImageRequested()

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 54
            color: Theme.surface
            border.color: Theme.border
            radius: Theme.radius + 2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.accent

                    Label {
                        anchors.centerIn: parent
                        text: "N"
                        color: "white"
                        font.pixelSize: Theme.fontSm
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Label {
                        text: "NeurX Chat"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontMd
                        font.bold: true
                    }

                    Label {
                        text: root.busy ? "Thinking and using tools" : "Ready for code questions"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                    }
                }

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: root.busy ? Theme.warning : Theme.success
                }
            }
        }

        // ── Message list ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 180
            color: Theme.surface
            border.color: Theme.border
            radius: Theme.radius + 2
            clip: true

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 8
                model: root.model
                clip: true
                spacing: 6
                topMargin: 8
                bottomMargin: 8
                verticalLayoutDirection: ListView.TopToBottom

                ScrollBar.vertical: ScrollBar {}

                onCountChanged: Qt.callLater(() => positionViewAtEnd())

                delegate: Item {
                    required property string role
                    required property string content
                    required property var toolCalls
                    required property var attachments

                    width: listView.width
                    implicitHeight: bubble.implicitHeight

                    MessageBubble {
                        id: bubble
                        width: parent.width
                        messageRole: parent.role
                        messageContent: parent.content
                        messageToolCalls: parent.toolCalls
                        messageAttachments: parent.attachments
                    }
                }

                footer: Item {
                    width: listView.width
                    height: busy ? 48 : 0
                    visible: busy

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: 3
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 4
                                color: Theme.accent
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.2; duration: 400 + index * 150 }
                                    NumberAnimation { to: 1.0; duration: 400 + index * 150 }
                                }
                            }
                        }

                        Label {
                            text: "NeurX is thinking..."
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                        }
                    }
                }
            }
        }

        // ── Send window ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.minimumHeight: 156
            Layout.preferredHeight: 184
            color: Theme.surface
            border.color: Theme.border
            radius: Theme.radius + 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bg
                    radius: Theme.radius + 2
                    border.color: inputArea.activeFocus ? Theme.accent : Theme.border
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true

                        TextArea {
                            id: inputArea
                            objectName: "chatInput"
                            width: parent.width
                            placeholderText: "Ask NeurX Code. Shift+Enter for newline"
                            wrapMode: TextArea.Wrap
                            color: Theme.textPrimary
                            font: Theme.uiFont
                            background: null
                            enabled: !root.busy
                            focus: true

                            Keys.onReturnPressed: event => {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    event.accepted = false   // insert newline
                                } else if (inputArea.preeditText.length > 0) {
                                    event.accepted = false   // let IME confirm the composition
                                } else {
                                    event.accepted = true
                                    submitInput()
                                }
                            }

                            Component.onCompleted: forceActiveFocus()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        text: "Attach image"
                        enabled: !root.busy
                        onClicked: root.attachImageRequested()
                    }

                    Button {
                        text: "Paste image"
                        enabled: !root.busy
                        onClicked: root.pasteImageRequested()
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Clear attachments"
                        enabled: !root.busy && root.agent && root.agent.pendingAttachments && root.agent.pendingAttachments.length > 0
                        onClicked: root.agent.clearPendingAttachments()
                    }
                }

                Repeater {
                    model: root.agent && root.agent.pendingAttachments ? root.agent.pendingAttachments : []

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: Theme.radius
                        color: Theme.surfaceAlt
                        border.color: Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: Theme.surface
                                border.color: Theme.border

                                Label {
                                    anchors.centerIn: parent
                                    text: "🖼"
                                    font.pixelSize: Theme.fontSm
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Label {
                                    text: modelData.fileName || modelData.path || "Image attachment"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSm
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: modelData.altText || modelData.mimeType || ""
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontXs
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    text: root.busy ? "Stop response" : "NeurX"
                    enabled: root.busy
                             || inputArea.text.trim().length > 0
                             || (root.agent && root.agent.pendingAttachments && root.agent.pendingAttachments.length > 0)
                    highlighted: !root.busy

                    background: Rectangle {
                        radius: Theme.radius
                        color: root.busy ? Theme.error : Theme.accent
                    }

                    contentItem: Label {
                        text: parent.text
                        color: "white"
                        font.pixelSize: Theme.fontMd
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (root.busy) root.interrupt()
                        else           submitInput()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    color: "transparent"

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        Label {
                            text: "Clear conversation"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearHistory()
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: root.busy ? "Working" : "Ready"
                            color: root.busy ? Theme.warning : Theme.textMuted
                            font.pixelSize: Theme.fontSm
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: "Commands: /help /plan /review /search /checkpoint /delegate"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
            }
        }
    }

    function submitInput() {
        const txt = inputArea.text.trim()
        const hasAttachments = root.agent && root.agent.pendingAttachments && root.agent.pendingAttachments.length > 0
        if (txt.length === 0 && !hasAttachments)
            return
        inputArea.text = ""
        root.sendMessage(txt)
    }
}
