import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

// ── MessageBubble ─────────────────────────────────────────────────────────────
//  Renders one entry in the chat list.
//  role: "user" | "assistant" | "tool" | "tool_result"

Item {
    id: root

    required property string     messageRole
    required property string     messageContent
    required property var        messageToolCalls   // list of {id, name, status, args, result}
    required property var        messageAttachments // list of QVariantMap image attachments

    implicitHeight: bodyColumn.implicitHeight + 16

    readonly property int avatarSize: root.isAssistant ? 22 : 28
    readonly property int labelWidth: 56
    readonly property int rowGap: 10
    readonly property real contentWidth: Math.max(220, width - 32 - avatarSize - labelWidth - (rowGap * 2))
    readonly property real wideContentWidth: Math.max(220, width - 32)

    readonly property bool isUser:   messageRole === "user"
    readonly property bool isTool:   messageRole === "tool" || messageRole === "tool_result"
    readonly property bool isAssistant: messageRole === "assistant"
    readonly property bool isCheckpointNotice: root.isTool
        && (messageContent.indexOf("Restored checkpoint ") === 0
            || messageContent.indexOf("Rolled back workspace files") === 0)
    property bool toolsExpanded: false
    readonly property real roleLabelHeight: root.isAssistant ? 0 : roleLabel.implicitHeight
    readonly property var contentBlocks: root.isAssistant ? parseBlocks(root.messageContent) : []
    readonly property var attachments: root.messageAttachments || []
    readonly property color badgeColor: {
        if (isUser)
            return Theme.accent
        if (isCheckpointNotice)
            return Theme.success
        if (isTool)
            return Theme.warning
        return Theme.surfaceAlt
    }
    readonly property color bubbleColor: {
        if (isUser)
            return Theme.accent
        if (isCheckpointNotice)
            return Theme.surfaceAlt
        if (isTool)
            return Theme.surface
        return Theme.surfaceAlt
    }

    function parseBlocks(text) {
        const source = text || ""
        const blocks = []
        const regex = /```([^\n`]*)\n?([\s\S]*?)```/g
        let lastIndex = 0
        let match

        while ((match = regex.exec(source)) !== null) {
            if (match.index > lastIndex) {
                blocks.push({
                    type: "markdown",
                    text: source.slice(lastIndex, match.index)
                })
            }
            blocks.push({
                type: "code",
                language: (match[1] || "").trim(),
                text: match[2] || ""
            })
            lastIndex = regex.lastIndex
        }

        if (lastIndex < source.length) {
            blocks.push({
                type: "markdown",
                text: source.slice(lastIndex)
            })
        }

        if (blocks.length === 0)
            blocks.push({ type: "markdown", text: source })

        return blocks
    }

    Column {
        id: bodyColumn
        x: 16
        y: 8
        width: root.width - 32
        spacing: 8

        Item {
            id: messageRow
            width: parent.width
            height: root.isAssistant
                ? avatar.height + 6 + (bubble.visible ? bubble.implicitHeight : 0)
                : Math.max(avatar.height, Math.max(roleLabelHeight, bubble.visible ? bubble.implicitHeight : 0))

            Rectangle {
                id: avatar
                x: root.isUser ? parent.width - root.avatarSize : 0
                y: 0
                width: root.avatarSize
                height: root.avatarSize
                radius: root.avatarSize / 2
                color: root.badgeColor
                border.color: root.isUser ? Theme.accent : Theme.border
                clip: true

                // Show logo for assistant messages, letter for others
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.isAssistant ? "file:///Users/feifei/agent/neurx-code/assets/icons/logo.png" : ""
                    fillMode: Image.PreserveAspectFit
                    visible: root.isAssistant
                }

                Label {
                    anchors.centerIn: parent
                    text: root.isUser ? "U" : root.isCheckpointNotice ? "C" : root.isTool ? "T" : "N"
                    color: root.isUser ? "white" : Theme.textPrimary
                    font.pixelSize: Theme.fontSm
                    font.bold: true
                    visible: !root.isAssistant
                }
            }

            Label {
                id: roleLabel
                x: root.isAssistant ? 0 : (root.isUser ? avatar.x - root.rowGap - width : avatar.width + root.rowGap)
                y: 2
                width: root.isAssistant ? parent.width : root.labelWidth
                horizontalAlignment: root.isUser ? Text.AlignRight : Text.AlignLeft
                text: root.isUser ? "You" : root.isCheckpointNotice ? "Checkpoint" : root.isTool ? "Tool" : "NeurX"
                color: root.isUser ? Theme.accent : root.isCheckpointNotice ? Theme.success : Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.bold: true
                visible: !root.isAssistant
            }

            Rectangle {
                id: bubble
                x: root.isAssistant ? 0 : (root.isUser
                    ? roleLabel.x - root.rowGap - width
                    : roleLabel.x + roleLabel.width + root.rowGap)
                y: root.isAssistant ? (avatar.height + 6) : 0
                width: root.isAssistant ? root.wideContentWidth : root.contentWidth
                visible: root.messageContent.length > 0 || root.attachments.length > 0
                color: root.bubbleColor
                radius: Theme.radius + 2
                border.color: root.isUser ? Theme.accent : root.isCheckpointNotice ? Theme.success : Theme.border
                border.width: root.isUser ? 0 : 1
                implicitHeight: bubbleContent.implicitHeight + 24

                Column {
                    id: bubbleContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    TextEdit {
                        width: parent.width
                        visible: !root.isAssistant
                        text: root.messageContent
                        wrapMode: TextEdit.Wrap
                        color: root.isUser ? "white" : root.isCheckpointNotice ? Theme.textPrimary : Theme.textPrimary
                        font: Theme.uiFont
                        readOnly: true
                        selectByMouse: true
                        // Prevent TextEdit from stealing wheel events from the parent ListView
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => { wheel.accepted = false }
                        }
                    }

                    Flow {
                        width: parent.width
                        visible: root.attachments.length > 0
                        spacing: 8

                        Repeater {
                            model: root.attachments

                            delegate: Rectangle {
                                required property var modelData
                                width: 110
                                height: 118
                                radius: Theme.radius
                                color: Theme.bg
                                border.color: Theme.border

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 5

                                    Rectangle {
                                        width: parent.width
                                        height: 78
                                        radius: 6
                                        color: Theme.surface
                                        border.color: Theme.border
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            source: modelData.dataUrl || ""
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                    }

                                    Label {
                                        width: parent.width
                                        text: modelData.fileName || modelData.path || "image"
                                        color: root.isUser ? "white" : Theme.textPrimary
                                        font.pixelSize: Theme.fontXs
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.isAssistant ? root.contentBlocks : []

                        delegate: Loader {
                            required property var modelData
                            width: parent ? parent.width : root.wideContentWidth - 24
                            sourceComponent: modelData.type === "code" ? codeBlock : markdownBlock

                            property string blockText: modelData.text || ""
                            property string blockLanguage: modelData.language || ""
                        }
                    }
                }
            }
        }

        Rectangle {
            id: toolsSummary
            x: root.isUser ? widthParent() - width : root.avatarSize + root.rowGap + root.labelWidth + root.rowGap
            width: root.contentWidth
            visible: root.messageToolCalls.length > 0
            radius: Theme.radius
            color: Theme.surface
            border.color: Theme.border
            implicitHeight: toolsColumn.implicitHeight + 16

            function widthParent() {
                return parent ? parent.width : root.width - 32
            }

            Column {
                id: toolsColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 8

                    Label {
                        text: root.toolsExpanded ? "▼" : "▶"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                    }

                    Label {
                        width: parent.width - x
                        text: root.messageToolCalls.length === 1
                            ? "Used 1 tool"
                            : "Used " + root.messageToolCalls.length + " tools"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.toolsExpanded

                    Repeater {
                        model: root.messageToolCalls
                        ToolCallCard {
                            width: toolsColumn.width
                            toolName: modelData.name ?? ""
                            toolStatus: modelData.status ?? "pending"
                            toolArgs: modelData.args ?? ""
                            toolResult: modelData.result ?? ""
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toolsExpanded = !root.toolsExpanded
            }
        }
    }

    Component {
        id: markdownBlock

        Text {
            text: blockText
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap
            color: Theme.textPrimary
            font: Theme.uiFont
            width: root.isAssistant ? root.wideContentWidth - 24 : root.contentWidth - 24
            visible: text.trim().length > 0
        }
    }

    Component {
        id: codeBlock

        Rectangle {
            id: codeBlockRect
            width: root.isAssistant ? root.wideContentWidth - 24 : root.contentWidth - 24
            color: "#111318"
            radius: Theme.radius + 2
            border.color: codeBlockRect.hovered ? "#3c4658" : "#2b313d"
            border.width: 1
            visible: blockText.trim().length > 0
            implicitHeight: codeColumn.implicitHeight + 18

            property bool hovered: false
            property bool copied: false

            ColumnLayout {
                id: codeColumn
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: "#171b22"
                    radius: codeBlockRect.radius

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: codeHeaderDivider.height
                        color: codeHeaderDivider.color
                        visible: false
                    }

                    Rectangle {
                        id: codeHeaderDivider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: "#262d38"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: languageLabel.implicitWidth + 14
                            radius: 11
                            color: "#202734"
                            border.color: "#30394a"
                            border.width: 1

                            Label {
                                id: languageLabel
                                anchors.centerIn: parent
                                text: blockLanguage.length > 0 ? blockLanguage : "code"
                                color: "#c3cedd"
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            id: copyButton
                            Layout.preferredWidth: copyButtonLabel.implicitWidth + 28
                            Layout.preferredHeight: 24
                            radius: 12
                            color: codeBlockRect.copied
                                   ? "#193524"
                                   : (copyButtonMouseArea.containsMouse ? "#263142" : "#1c2330")
                            border.color: codeBlockRect.copied ? "#2d8a57" : "#344154"
                            border.width: 1
                            opacity: codeBlockRect.hovered || codeBlockRect.copied ? 1.0 : 0.82

                            Behavior on opacity {
                                NumberAnimation { duration: 120 }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5

                                Label {
                                    text: codeBlockRect.copied ? "✓" : "⎘"
                                    color: codeBlockRect.copied ? "#7ee2a8" : "#b7c2d3"
                                    font.pixelSize: Theme.fontSm
                                    font.bold: true
                                }

                                Label {
                                    id: copyButtonLabel
                                    text: codeBlockRect.copied ? "Copied" : "Copy"
                                    color: codeBlockRect.copied ? "#7ee2a8" : "#d6deea"
                                    font.pixelSize: Theme.fontXs
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: copyButtonMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    codeTextEdit.selectAll()
                                    codeTextEdit.copy()
                                    codeTextEdit.deselect()
                                    codeBlockRect.copied = true
                                    copiedTimer.restart()
                                }
                            }

                            Timer {
                                id: copiedTimer
                                interval: 1800
                                onTriggered: codeBlockRect.copied = false
                            }
                        }
                    }
                }

                TextEdit {
                    id: codeTextEdit
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: 10
                    Layout.bottomMargin: 12
                    text: blockText
                    wrapMode: TextEdit.WrapAnywhere
                    color: "#e6edf3"
                    font: Theme.monoFont
                    readOnly: true
                    selectByMouse: true
                    // Prevent TextEdit from stealing wheel events from the parent ListView
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => { wheel.accepted = false }
                    }
                }
            }

            // Hover detection
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: codeBlockRect.hovered = true
                onExited: codeBlockRect.hovered = false
                propagateComposedEvents: true
            }
        }
    }
}
