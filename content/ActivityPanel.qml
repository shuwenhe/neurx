import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root

    required property var executionTimeline
    property string currentThreadId: ""
    property string timelineFilter: "all"

    readonly property bool hasTimeline: executionTimeline && executionTimeline.length > 0
    readonly property var filteredTimeline: {
        const items = root.executionTimeline || []
        if (root.timelineFilter === "all")
            return items
        return items.filter(function(item) {
            return timelineGroup(item.kind) === root.timelineFilter
        })
    }

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
        case "subagent_tool":
            return "subagent";
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
        case "subagent_tool":
            return "🤖";
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
        case "subagent_tool":
            return "Sub-Agent";
        default:
            return kind || "Event";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.radius + 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headerColumn.implicitHeight + 18
                color: Theme.surfaceAlt
                radius: Theme.radius + 2
                border.color: Theme.border

                ColumnLayout {
                    id: headerColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: "Execution Timeline"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontMd
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

                    Label {
                        Layout.fillWidth: true
                        text: "Active thread: " + (root.currentThreadId || "none")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                        elide: Text.ElideRight
                    }
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
                        { key: "subagent", label: "Sub-Agents" },
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

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.hasTimeline
                color: Theme.surfaceAlt
                radius: Theme.radius
                border.color: Theme.border

                Flickable {
                    id: flickable
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    contentWidth: width
                    contentHeight: timelineColumn.implicitHeight

                    ScrollBar.vertical: CustomScrollBar {
                        anchors.right: flickable.right
                        anchors.rightMargin: -2
                    }

                    ColumnLayout {
                        id: timelineColumn
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: root.filteredTimeline.slice(-20)

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
                                            text: modelData.title || timelineKindLabel(modelData.kind)
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

            Label {
                visible: !root.hasTimeline
                Layout.fillWidth: true
                text: "No execution events yet. Send a message or run a tool to start the timeline."
                color: Theme.textMuted
                font.pixelSize: Theme.fontXs
                wrapMode: Text.Wrap
            }
        }
    }
}
