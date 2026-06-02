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

    implicitHeight: bodyColumn.implicitHeight + 16

    readonly property int avatarSize: 28
    readonly property int labelWidth: 56
    readonly property int rowGap: 10
    readonly property real contentWidth: Math.max(220, width - 32 - avatarSize - labelWidth - (rowGap * 2))

    readonly property bool isUser:   messageRole === "user"
    readonly property bool isTool:   messageRole === "tool" || messageRole === "tool_result"
    readonly property bool isAssistant: messageRole === "assistant"
    readonly property bool isCheckpointNotice: root.isTool
        && (messageContent.indexOf("Restored checkpoint ") === 0
            || messageContent.indexOf("Rolled back workspace files") === 0)
    property bool toolsExpanded: false
    readonly property var contentBlocks: root.isAssistant ? parseBlocks(root.messageContent) : []
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
            height: Math.max(avatar.height, Math.max(roleLabel.implicitHeight, bubble.visible ? bubble.implicitHeight : 0))

            Rectangle {
                id: avatar
                x: root.isUser ? parent.width - root.avatarSize : 0
                y: 0
                width: root.avatarSize
                height: root.avatarSize
                radius: root.avatarSize / 2
                color: root.badgeColor
                border.color: root.isUser ? Theme.accent : Theme.border

                Label {
                    anchors.centerIn: parent
                    text: root.isUser ? "U" : root.isCheckpointNotice ? "C" : root.isTool ? "T" : "N"
                    color: root.isUser ? "white" : Theme.textPrimary
                    font.pixelSize: Theme.fontSm
                    font.bold: true
                }
            }

            Label {
                id: roleLabel
                x: root.isUser
                    ? avatar.x - root.rowGap - width
                    : avatar.width + root.rowGap
                y: 2
                width: root.labelWidth
                horizontalAlignment: root.isUser ? Text.AlignRight : Text.AlignLeft
                text: root.isUser ? "You" : root.isCheckpointNotice ? "Checkpoint" : root.isTool ? "Tool" : "NeurX"
                color: root.isUser ? Theme.accent : root.isCheckpointNotice ? Theme.success : Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.bold: true
            }

            Rectangle {
                id: bubble
                x: root.isUser
                    ? roleLabel.x - root.rowGap - width
                    : roleLabel.x + roleLabel.width + root.rowGap
                y: 0
                width: root.contentWidth
                visible: root.messageContent.length > 0
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
                    }

                    Repeater {
                        model: root.isAssistant ? root.contentBlocks : []

                        delegate: Loader {
                            required property var modelData
                            width: parent ? parent.width : root.contentWidth - 24
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
            width: root.contentWidth - 24
            visible: text.trim().length > 0
        }
    }

    Component {
        id: codeBlock

        Rectangle {
            width: root.contentWidth - 24
            color: Theme.bg
            radius: Theme.radius
            border.color: Theme.border
            visible: blockText.trim().length > 0
            implicitHeight: codeColumn.implicitHeight + 16

            ColumnLayout {
                id: codeColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Label {
                    text: blockLanguage.length > 0 ? blockLanguage : "code"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                    font.bold: true
                }

                TextEdit {
                    width: parent.width
                    text: blockText
                    wrapMode: TextEdit.WrapAnywhere
                    color: Theme.textPrimary
                    font: Theme.monoFont
                    readOnly: true
                    selectByMouse: true
                }
            }
        }
    }
}
