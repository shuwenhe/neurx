import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root

    required property var recentSessions
    required property var executionTimeline
    property string currentThreadId: ""
    property string timelineFilter: "all"

    signal resumeRequested(string sessionId)
    signal newSessionRequested()
    signal forkRequested()

    readonly property bool hasSessions: recentSessions && recentSessions.length > 0
    readonly property bool hasTimeline: executionTimeline && executionTimeline.length > 0
    readonly property var filteredTimeline: {
        const items = root.executionTimeline || []
        if (root.timelineFilter === "all")
            return items
        return items.filter(function(item) {
            return timelineGroup(item.kind) === root.timelineFilter
        })
    }
    implicitHeight: panel.implicitHeight
    visible: true

    function timelineGroup(kind) {
        switch (kind) {
        case "assistant_message":
        case "user_message":
        case "system_message":
            return "messages";
        case "approval":
            return "approvals";
        case "tool_output":
            return "output";
        case "command_execution":
            return "commands";
        case "file_change":
            return "files";
        case "search":
        case "memory":
        case "knowledge":
            return "search";
        case "web":
            return "web";
        default:
            return "tools";
        }
    }

    function timelineIcon(kind, status) {
        if (status === "error")
            return "!";
        if (status === "running")
            return "▶";
        switch (kind) {
        case "assistant_message":
        case "user_message":
        case "system_message":
            return "✉";
        case "command_execution":
            return "⌘";
        case "file_change":
            return "✎";
        case "approval":
            return "✓";
        case "tool_output":
            return "≋";
        case "search":
        case "memory":
        case "knowledge":
            return "⌕";
        case "web":
            return "🌐";
        case "tool":
            return "⋯";
        default:
            return "•";
        }
    }

    function timelineStatusColor(status) {
        if (status === "error")
            return Theme.error;
        if (status === "running")
            return Theme.accent;
        return Theme.textMuted;
    }

    function timelineKindLabel(kind) {
        switch (kind) {
        case "assistant_message":
            return "Assistant";
        case "user_message":
            return "User";
        case "system_message":
            return "System";
        case "approval":
            return "Approval";
        case "tool_output":
            return "Output";
        case "command_execution":
            return "Command";
        case "file_change":
            return "File";
        case "search":
            return "Search";
        case "memory":
            return "Memory";
        case "knowledge":
            return "Knowledge";
        case "web":
            return "Web";
        default:
            return kind || "Event";
        }
    }

    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.radius + 2
        implicitHeight: contentColumn.implicitHeight + 18

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 9
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Recent Sessions"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontMd
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "New Session"
                    implicitHeight: 28
                    onClicked: root.newSessionRequested()
                }

                Button {
                    text: "Fork Thread"
                    implicitHeight: 28
                    onClicked: root.forkRequested()
                }
            }

            Label {
                Layout.fillWidth: true
                text: "Active thread: " + (root.currentThreadId || "none")
                color: Theme.textMuted
                font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
            }

            Label {
                visible: !root.hasSessions
                text: "No saved sessions yet. Start a new thread to create one."
                color: Theme.textMuted
                font.pixelSize: Theme.fontXs
                wrapMode: Text.Wrap
            }

            Repeater {
                model: root.recentSessions.slice(0, 4)

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    radius: Theme.radius
                    color: Theme.surfaceAlt
                    border.color: Theme.border
                    implicitHeight: sessionColumn.implicitHeight + 12

                    ColumnLayout {
                        id: sessionColumn
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Label {
                            Layout.fillWidth: true
                            text: modelData.threadId || modelData.sessionId
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontXs
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "thread " + (modelData.threadId || modelData.sessionId || "")
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: (modelData.workspacePath || "No workspace")
                                + " · " + (modelData.currentModel || "unknown model")
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }

                        Label {
                            visible: (modelData.parentThreadId || "").length > 0
                            Layout.fillWidth: true
                            text: "forked from " + modelData.parentThreadId
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: modelData.updatedAt || ""
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                            }

                            Item { Layout.fillWidth: true }

                            Label {
                                text: modelData.messageCount + " msgs"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                            }

                            Button {
                                text: "Resume"
                                implicitHeight: 26
                                onClicked: root.resumeRequested(modelData.threadId || modelData.sessionId)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.hasTimeline
                color: Theme.surfaceAlt
                radius: Theme.radius
                border.color: Theme.border
                implicitHeight: timelineColumn.implicitHeight + 12

                ColumnLayout {
                    id: timelineColumn
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: "Recent Activity"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSm
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Label {
                            text: root.timelineFilter === "all"
                                ? root.executionTimeline.length + " events"
                                : root.filteredTimeline.length + " / " + root.executionTimeline.length + " events"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { key: "all", label: "All" },
                                { key: "messages", label: "Messages" },
                                { key: "approvals", label: "Approvals" },
                                { key: "output", label: "Output" },
                                { key: "commands", label: "Commands" },
                                { key: "files", label: "Files" },
                                { key: "search", label: "Search" },
                                { key: "web", label: "Web" },
                                { key: "tools", label: "Tools" }
                            ]

                            delegate: Button {
                                required property var modelData
                                text: modelData.label
                                checkable: true
                                checked: root.timelineFilter === modelData.key
                                implicitHeight: 26
                                onClicked: root.timelineFilter = modelData.key
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Repeater {
                        model: root.filteredTimeline.slice(-8)

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            radius: Theme.radius
                            color: Theme.surface
                            border.color: Theme.border
                            implicitHeight: eventRow.implicitHeight + 10

                            RowLayout {
                                id: eventRow
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Label {
                                    text: timelineIcon(modelData.kind, modelData.status)
                                    color: timelineStatusColor(modelData.status)
                                    font.pixelSize: Theme.fontSm
                                    font.bold: modelData.status === "error" || modelData.status === "running"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.title || modelData.kind || "event"
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontXs
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: timelineKindLabel(modelData.kind)
                                            + ((modelData.toolName || "").length > 0 ? " · " + modelData.toolName : "")
                                            + ((modelData.details || "").length > 0 ? " · " + modelData.details : "")
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontXs
                                        elide: Text.ElideRight
                                    }
                                }

                                Label {
                                    text: modelData.timestamp || ""
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontXs
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
