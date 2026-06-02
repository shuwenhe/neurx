import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root

    required property var mcpToolNames
    required property var knowledgeSources
    required property var knowledgeSearchResults
    required property string knowledgeSearchQuery
    required property var scheduledTasks
    required property string localGatewayUrl

    signal indexKnowledgeRequested()
    signal indexCurrentFileRequested()
    signal indexRecentFilesRequested()
    signal searchKnowledgeRequested(string query)
    signal removeKnowledgeSourceRequested(string path)
    signal openKnowledgeSourceRequested(string path)
    signal createReminderRequested(string title, int dueInMinutes, int repeatMinutes)
    signal cancelReminderRequested(string id)
    signal copyGatewayUrlRequested()

    property string searchQuery: ""

    readonly property bool hasMcpTools: mcpToolNames && mcpToolNames.length > 0
    readonly property bool hasKnowledgeSources: knowledgeSources && knowledgeSources.length > 0
    readonly property bool hasSearchResults: knowledgeSearchResults && knowledgeSearchResults.length > 0
    readonly property bool hasScheduledTasks: scheduledTasks && scheduledTasks.length > 0
    readonly property bool hasGatewayUrl: localGatewayUrl && localGatewayUrl.length > 0
    implicitHeight: panel.implicitHeight

    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.radius + 2
        implicitHeight: body.implicitHeight + 18

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Local Tools"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontMd
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: root.hasMcpTools ? root.mcpToolNames.length + " MCP tools" : "No MCP tools loaded"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                }
            }

            GroupBox {
                Layout.fillWidth: true
                title: "Knowledge"
                background: Rectangle { color: Theme.surfaceAlt; radius: Theme.radius }

                ColumnLayout {
                    width: parent.width
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        text: "Index the current workspace, then search the local knowledge base."
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            text: "Index Workspace"
                            implicitHeight: 30
                            onClicked: root.indexKnowledgeRequested()
                        }

                        Button {
                            text: "Index Current File"
                            implicitHeight: 30
                            enabled: true
                            onClicked: root.indexCurrentFileRequested()
                        }

                        Button {
                            text: "Index Recent Files"
                            implicitHeight: 30
                            enabled: true
                            onClicked: root.indexRecentFilesRequested()
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: "Search local notes, docs, or code..."
                            text: root.searchQuery
                            onTextEdited: root.searchQuery = text
                            onAccepted: {
                                if (text.trim().length > 0)
                                    root.searchKnowledgeRequested(text.trim())
                            }
                        }

                        Button {
                            text: "Search"
                            implicitHeight: 30
                            enabled: searchField.text.trim().length > 0
                            onClicked: root.searchKnowledgeRequested(searchField.text.trim())
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.hasKnowledgeSources
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: sourcesColumn.implicitHeight + 12

                        ColumnLayout {
                            id: sourcesColumn
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "Indexed Sources"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontXs
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    text: root.knowledgeSources.length + " sources"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontXs
                                }
                            }

                            Repeater {
                                model: root.knowledgeSources.slice(0, 6)

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    radius: Theme.radius
                                    color: Theme.surface
                                    border.color: Theme.border
                                    implicitHeight: row.implicitHeight + 10

                                    RowLayout {
                                        id: row
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.path || ""
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontXs
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: (modelData.chunkCount || 0) + " chunks · " + (modelData.updatedAt || "")
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontXs
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Button {
                                            text: "Remove"
                                            implicitHeight: 26
                                            onClicked: root.removeKnowledgeSourceRequested(modelData.path || "")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.hasSearchResults
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: searchColumn.implicitHeight + 12

                        ColumnLayout {
                            id: searchColumn
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "Last Search"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontXs
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    text: root.knowledgeSearchQuery
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontXs
                                    elide: Text.ElideRight
                                }
                            }

                            Repeater {
                                model: root.knowledgeSearchResults.slice(0, 5)

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    radius: Theme.radius
                                    color: Theme.surface
                                    border.color: Theme.border
                                    implicitHeight: row.implicitHeight + 10

                                    RowLayout {
                                        id: row
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.path || ""
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontXs
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: "chunk " + (modelData.chunkIndex ?? 0)
                                                    + " · " + (modelData.snippet || "")
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontXs
                                                wrapMode: Text.Wrap
                                            }
                                        }

                                        Button {
                                            text: "Open"
                                            implicitHeight: 26
                                            onClicked: root.openKnowledgeSourceRequested(modelData.path || "")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: scheduleColumn.implicitHeight + 12

                        ColumnLayout {
                            id: scheduleColumn
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "Schedule"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontXs
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    text: root.hasScheduledTasks ? root.scheduledTasks.length + " tasks" : "No scheduled tasks"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontXs
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    id: reminderTitleField
                                    Layout.fillWidth: true
                                    placeholderText: "Reminder title"
                                }

                                TextField {
                                    id: dueMinutesField
                                    width: 90
                                    placeholderText: "In min"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                }

                                TextField {
                                    id: repeatMinutesField
                                    width: 90
                                    placeholderText: "Repeat"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                }

                                Button {
                                    text: "Add"
                                    implicitHeight: 30
                                    enabled: reminderTitleField.text.trim().length > 0
                                    onClicked: {
                                        const dueMinutes = parseInt(dueMinutesField.text || "0", 10)
                                        const repeatMinutes = parseInt(repeatMinutesField.text || "0", 10)
                                        root.createReminderRequested(
                                            reminderTitleField.text.trim(),
                                            isNaN(dueMinutes) ? 0 : Math.max(0, dueMinutes),
                                            isNaN(repeatMinutes) ? 0 : Math.max(0, repeatMinutes))
                                        reminderTitleField.text = ""
                                        dueMinutesField.text = ""
                                        repeatMinutesField.text = ""
                                    }
                                }
                            }

                            Repeater {
                                model: root.scheduledTasks.slice(0, 5)

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    radius: Theme.radius
                                    color: Theme.surface
                                    border.color: Theme.border
                                    implicitHeight: row.implicitHeight + 10

                                    RowLayout {
                                        id: row
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.title || ""
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontXs
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: (modelData.dueAtUtc || "") + (modelData.repeatMinutes > 0 ? " · repeat " + modelData.repeatMinutes + "m" : "")
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontXs
                                                wrapMode: Text.Wrap
                                            }
                                        }

                                        Button {
                                            text: "Cancel"
                                            implicitHeight: 26
                                            onClicked: root.cancelReminderRequested(modelData.id || "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GroupBox {
                Layout.fillWidth: true
                title: "Gateway"
                background: Rectangle { color: Theme.surfaceAlt; radius: Theme.radius }

                ColumnLayout {
                    width: parent.width
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        text: "Local HTTP ingress for external apps and scripts."
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.localGatewayUrl
                            placeholderText: "Gateway not running"
                        }

                        Button {
                            text: "Copy URL"
                            implicitHeight: 30
                            enabled: root.hasGatewayUrl
                            onClicked: root.copyGatewayUrlRequested()
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "POST /task with {\"title\":\"...\",\"details\":\"...\"} or POST /message with {\"message\":\"...\"}. GET /health returns current agent state."
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                        wrapMode: Text.Wrap
                    }
                }
            }

            GroupBox {
                Layout.fillWidth: true
                title: "MCP Tools"
                background: Rectangle { color: Theme.surfaceAlt; radius: Theme.radius }

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Label {
                        Layout.fillWidth: true
                        text: root.hasMcpTools
                            ? "Loaded from <workspace>/.neurx/mcp.json"
                            : "No MCP configuration found"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: root.mcpToolNames

                        delegate: Rectangle {
                            required property string modelData

                            Layout.fillWidth: true
                            radius: Theme.radius
                            color: Theme.surface
                            border.color: Theme.border
                            implicitHeight: 28

                            Label {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
