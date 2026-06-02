import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

// ── ChatPanel ─────────────────────────────────────────────────────────────────
//  Right-side agent panel: message list on top, send controls at bottom.

Item {
    id: root

    required property var    model         // ChatModel*
    required property bool   busy
    required property string streamingText

    signal sendMessage(string text)
    signal interrupt()
    signal clearHistory()

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

                    width: listView.width
                    implicitHeight: bubble.implicitHeight

                    MessageBubble {
                        id: bubble
                        width: parent.width
                        messageRole: parent.role
                        messageContent: parent.content
                        messageToolCalls: parent.toolCalls
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

                Button {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    text: root.busy ? "Stop response" : "NeurX"
                    enabled: root.busy || inputArea.text.trim().length > 0
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
            }
        }
    }

    function submitInput() {
        const txt = inputArea.text.trim()
        if (txt.length === 0) return
        inputArea.text = ""
        root.sendMessage(txt)
    }
}
