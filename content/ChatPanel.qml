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
    readonly property var slashCommands: [
        { "label": "/help", "hint": "show command list" },
        { "label": "/plan", "hint": "replace task plan" },
        { "label": "/review", "hint": "request code review" },
        { "label": "/search", "hint": "search workspace" },
        { "label": "/checkpoint", "hint": "open rollback" },
        { "label": "/delegate", "hint": "delegate a subtask" }
    ]
    property string slashQuery: ""
    property bool slashMenuOpen: false

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

        // ── Codex-style composer ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.minimumHeight: 72 + attachmentsArea.implicitHeight
            color: Theme.surface
            border.color: Theme.border
            radius: Theme.radius + 2
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Attachment chips ───────────────────────────────────
                ColumnLayout {
                    id: attachmentsArea
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: attachmentsList.count > 0 ? 8 : 0
                    Layout.bottomMargin: attachmentsList.count > 0 ? 8 : 0
                    spacing: 6
                    visible: attachmentsList.count > 0

                    Repeater {
                        id: attachmentsList
                        model: root.agent && root.agent.pendingAttachments ? root.agent.pendingAttachments : []

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.radius
                            color: Theme.surfaceAlt
                            border.color: Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 6

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 6
                                    color: Theme.bg
                                    border.color: Theme.border

                                    Label {
                                        anchors.centerIn: parent
                                        text: "🖼"
                                        font.pixelSize: 12
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Label {
                                        text: modelData.fileName || modelData.path || "Image"
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSm
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Label {
                                        text: modelData.mimeType || ""
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontXs
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 4
                                    color: closeBtn.containsMouse ? Theme.error : "transparent"
                                    opacity: closeBtn.containsMouse ? 0.8 : 0.5

                                    Label {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: "white"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: closeBtn
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        enabled: !root.busy

                                        onClicked: root.agent.clearPendingAttachments()
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Main input row (Copilot style) ─────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 40
                    Layout.margins: 8
                    color: Theme.bg
                    radius: Theme.radius
                    border.color: inputArea.activeFocus ? Theme.accent : Theme.border
                    border.width: inputArea.activeFocus ? 2 : 1
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        anchors.rightMargin: 4
                        spacing: 4

                        // ── Left toolbar (attach/paste buttons) ────────
                        RowLayout {
                            spacing: 2

                            // Slash command trigger
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: slashHovered ? Theme.surfaceAlt : "transparent"
                                border.color: slashHovered ? Theme.border : "transparent"
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: "/"
                                    color: Theme.textPrimary
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                property bool slashHovered: false

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: !root.busy
                                    enabled: !root.busy
                                    opacity: enabled ? 1.0 : 0.4

                                    onHoveredChanged: parent.slashHovered = containsMouse
                                    onClicked: root.insertSlashCommand("/")
                                }
                            }

                            // Attach image button
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: attachHovered ? Theme.surfaceAlt : "transparent"
                                border.color: attachHovered ? Theme.border : "transparent"
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: "📎"
                                    font.pixelSize: 14
                                }

                                property bool attachHovered: false

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: !root.busy
                                    enabled: !root.busy
                                    opacity: enabled ? 1.0 : 0.4

                                    onHoveredChanged: parent.attachHovered = containsMouse
                                    onClicked: root.attachImageRequested()
                                }
                            }

                            // Paste image button
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: pasteHovered ? Theme.surfaceAlt : "transparent"
                                border.color: pasteHovered ? Theme.border : "transparent"
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: "🖼"
                                    font.pixelSize: 14
                                }

                                property bool pasteHovered: false

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: !root.busy
                                    enabled: !root.busy
                                    opacity: enabled ? 1.0 : 0.4

                                    onHoveredChanged: parent.pasteHovered = containsMouse
                                    onClicked: root.pasteImageRequested()
                                }
                            }
                        }

                        // ── Send button (right side) ───────────────────
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: sendBtnReady ? (sendBtnHovered ? Theme.accent : Theme.accent) : Theme.surfaceAlt
                            opacity: sendBtnReady ? 1.0 : 0.5

                            property bool sendBtnReady: root.busy
                                                       || inputArea.text.trim().length > 0
                                                       || (root.agent && root.agent.pendingAttachments && root.agent.pendingAttachments.length > 0)
                            property bool sendBtnHovered: false

                            Label {
                                anchors.centerIn: parent
                                text: root.busy ? "⏹" : "↑"
                                color: parent.sendBtnReady ? "white" : Theme.textMuted
                                font.pixelSize: 18
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: parent.sendBtnReady ? Qt.PointingHandCursor : Qt.ArrowCursor
                                hoverEnabled: true
                                enabled: parent.sendBtnReady
                                opacity: enabled ? 1.0 : 0.5

                                onHoveredChanged: parent.sendBtnHovered = containsMouse
                                onClicked: {
                                    if (root.busy) root.interrupt()
                                    else           submitInput()
                                }
                            }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        spacing: 6

                        Label {
                            text: "Commands"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                        }

                        Repeater {
                            model: root.slashCommands

                            delegate: Rectangle {
                                required property var modelData
                                property bool hovered: false

                                radius: 10
                                color: hovered ? Theme.surfaceAlt : "transparent"
                                border.color: Theme.border
                                border.width: 1
                                implicitHeight: 22
                                implicitWidth: chipLabel.implicitWidth + 18

                                Label {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontXs
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    enabled: !root.busy

                                    onHoveredChanged: parent.hovered = containsMouse
                                    onClicked: root.insertSlashCommand(modelData.label + " ")
                                }
                            }
                        }
                    }

                    ScrollView {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 40
                        anchors.rightMargin: 44
                        anchors.topMargin: 10
                        anchors.bottomMargin: 34
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        clip: true

                        TextArea {
                            id: inputArea
                            objectName: "chatInput"
                            width: parent.width
                            placeholderText: "Ask NeurX Code. Shift+Enter for newline"
                            placeholderTextColor: Theme.textMuted
                            wrapMode: TextArea.Wrap
                            color: Theme.textPrimary
                            font: Theme.uiFont
                            background: null
                            enabled: !root.busy
                            focus: true
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0

                            Keys.onReturnPressed: event => {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    event.accepted = false
                                } else if (inputArea.preeditText.length > 0) {
                                    event.accepted = false
                                } else {
                                    event.accepted = true
                                    submitInput()
                                }
                            }

                            Component.onCompleted: forceActiveFocus()
                        }
                    }
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

    function insertSlashCommand(command) {
        if (root.busy)
            return
        inputArea.forceActiveFocus()
        inputArea.text = command
        inputArea.cursorPosition = inputArea.text.length
    }
}
