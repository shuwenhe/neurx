import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root

    required property var agent

    property string searchQuery: ""
    property var selectedTool: ({})
    property var selectedToolPermission: ({})
    property var selectedToolStats: ({})
    property string argumentText: "{}"
    property var lastResult: ({})

    readonly property var catalog: agent.toolCatalog || []
    readonly property var filteredTools: {
        const query = root.searchQuery.trim().toLowerCase()
        const tools = root.catalog || []
        if (!query)
            return tools
        return tools.filter(function(tool) {
            const haystack = [
                tool.name || "",
                tool.description || "",
                tool.category || "",
                (tool.tags || []).join(" "),
                tool.schemaText || ""
            ].join(" ").toLowerCase()
            return haystack.indexOf(query) >= 0
        })
    }

    Connections {
        target: agent
        function onToolCatalogChanged() {
            if (!root.selectedTool.name && root.filteredTools.length > 0)
                root.selectTool(root.filteredTools[0])
            else
                root.refreshSelectedToolState()
        }

        function onExecutionTimelineChanged() {
            root.refreshSelectedToolState()
        }
    }

    function selectTool(tool) {
        root.selectedTool = tool || {}
        root.argumentText = "{}"
        root.lastResult = {}
        root.refreshSelectedToolState()
    }

    function refreshSelectedToolState() {
        if (!root.selectedTool.name) {
            root.selectedToolPermission = ({})
            root.selectedToolStats = ({})
            return
        }
        root.selectedToolPermission = agent.toolPermissionState(root.selectedTool.name || "", {})
        root.selectedToolStats = agent.toolExecutionStats(root.selectedTool.name || "")
    }

    function permissionBadge(text) {
        return text || "unknown"
    }

    Component.onCompleted: {
        if (!root.selectedTool.name && root.filteredTools.length > 0)
            root.selectTool(root.filteredTools[0])
        else
            root.refreshSelectedToolState()
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
                            text: "Tool Registry"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontMd
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Label {
                            text: root.filteredTools.length + " tools"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Search tools, schema, tags..."
                            text: root.searchQuery
                            onTextEdited: root.searchQuery = text
                        }

                        Button {
                            text: "Refresh"
                            onClicked: root.searchQuery = root.searchQuery
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 320
                    Layout.minimumWidth: 260
                    Layout.fillHeight: true
                    color: Theme.surfaceAlt
                    radius: Theme.radius
                    border.color: Theme.border

                    ListView {
                        id: toolsList
                        anchors.fill: parent
                        anchors.margins: 8
                        model: root.filteredTools
                        clip: true
                        spacing: 6

                        ScrollBar.vertical: CustomScrollBar {
                            anchors.right: toolsList.right
                            anchors.rightMargin: 0
                        }

                        delegate: Rectangle {
                            required property var modelData

                            width: toolsList.width
                            radius: Theme.radius
                            color: root.selectedTool && root.selectedTool.name === modelData.name ? Theme.surface : Theme.bg
                            border.color: Theme.border
                            implicitHeight: itemColumn.implicitHeight + 14

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectTool(modelData)
                            }

                            ColumnLayout {
                                id: itemColumn
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: modelData.name || "tool"
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSm
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Item { Layout.fillWidth: true }
                                    Label {
                                        text: modelData.riskLevel || "low"
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontXs
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.description || ""
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontXs
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: (Array.isArray(modelData.tags) ? modelData.tags : []).slice(0, 3)
                                        delegate: Rectangle {
                                            required property var modelData
                                            radius: 8
                                            color: Theme.surfaceAlt
                                            border.color: Theme.border
                                            implicitHeight: 20
                                            implicitWidth: tagLabel.implicitWidth + 14

                                            Label {
                                                id: tagLabel
                                                anchors.centerIn: parent
                                                text: modelData
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.surfaceAlt
                    radius: Theme.radius
                    border.color: Theme.border

                    Flickable {
                        id: detailFlickable
                        anchors.fill: parent
                        anchors.margins: 8
                        contentWidth: width
                        contentHeight: detailColumn.implicitHeight
                        clip: true

                        ScrollBar.vertical: CustomScrollBar {
                            anchors.right: detailFlickable.right
                            anchors.rightMargin: 0
                        }

                        ColumnLayout {
                            id: detailColumn
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.border
                                implicitHeight: infoColumn.implicitHeight + 16

                                ColumnLayout {
                                    id: infoColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Label {
                                        text: root.selectedTool.name || "Select a tool"
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontMd
                                        font.bold: true
                                    }

                                    Label {
                                        text: root.selectedTool.category || ""
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontXs
                                    }

                                    Label {
                                        visible: !!root.selectedTool.description
                                        Layout.fillWidth: true
                                        text: root.selectedTool.description || ""
                                        color: Theme.textPrimary
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: !!root.selectedTool.name
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.border
                                implicitHeight: permissionColumn.implicitHeight + 16

                                ColumnLayout {
                                    id: permissionColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Label {
                                        text: "Permission"
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSm
                                        font.bold: true
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 4

                                        Label { text: "Risk"; color: Theme.textMuted }
                                        Label {
                                            text: root.selectedToolPermission.riskLevel || root.selectedTool.riskLevel || "unknown"
                                            color: Theme.textPrimary
                                        }

                                        Label { text: "Approval"; color: Theme.textMuted }
                                        Label {
                                            text: root.selectedToolPermission.requiresApproval ? "required" : "not required"
                                            color: Theme.textPrimary
                                        }

                                        Label { text: "Policy"; color: Theme.textMuted }
                                        Label {
                                            text: root.selectedToolPermission.policyName || String(root.selectedToolPermission.policy || "unknown")
                                            color: Theme.textPrimary
                                        }

                                        Label { text: "Read-only"; color: Theme.textMuted }
                                        Label {
                                            text: root.selectedToolPermission.readOnlyMode ? "enabled" : "disabled"
                                            color: Theme.textPrimary
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: !!root.selectedTool.name
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.border
                                implicitHeight: statsColumn.implicitHeight + 16

                                ColumnLayout {
                                    id: statsColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Label {
                                        text: "Execution Stats"
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSm
                                        font.bold: true
                                    }

                                    GridLayout {
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 4

                                        Label { text: "Runs"; color: Theme.textMuted }
                                        Label { text: String(root.selectedToolStats.totalExecutions || 0); color: Theme.textPrimary }

                                        Label { text: "Running"; color: Theme.textMuted }
                                        Label { text: String(root.selectedToolStats.runningExecutions || 0); color: Theme.textPrimary }

                                        Label { text: "Success"; color: Theme.textMuted }
                                        Label { text: String(root.selectedToolStats.successfulExecutions || 0); color: Theme.textPrimary }

                                        Label { text: "Failed"; color: Theme.textMuted }
                                        Label { text: String(root.selectedToolStats.failedExecutions || 0); color: Theme.textPrimary }

                                        Label { text: "Success %"; color: Theme.textMuted }
                                        Label { text: Number(root.selectedToolStats.successRate || 0).toFixed(1) + "%"; color: Theme.textPrimary }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: !!root.selectedTool.name
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.border
                                implicitHeight: historyColumn.implicitHeight + 16

                                ColumnLayout {
                                    id: historyColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            text: "Recent Execution History"
                                            color: Theme.textPrimary
                                            font.pixelSize: Theme.fontSm
                                            font.bold: true
                                        }
                                        Item { Layout.fillWidth: true }
                                        Label {
                                            text: String(agent.toolExecutionHistory(root.selectedTool.name || "", 8).length) + " events"
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fontXs
                                        }
                                    }

                                    Repeater {
                                        model: agent.toolExecutionHistory(root.selectedTool.name || "", 8)

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            radius: Theme.radius
                                            color: Theme.bg
                                            border.color: Theme.border
                                            implicitHeight: historyItemColumn.implicitHeight + 12

                                            ColumnLayout {
                                                id: historyItemColumn
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 2

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Label {
                                                        text: modelData.title || modelData.kind || "event"
                                                        color: Theme.textPrimary
                                                        font.pixelSize: Theme.fontXs
                                                        font.bold: true
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                    Label {
                                                        text: modelData.status || ""
                                                        color: Theme.textMuted
                                                        font.pixelSize: Theme.fontXs
                                                    }
                                                }

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: modelData.details || ""
                                                    color: Theme.textMuted
                                                    font.pixelSize: Theme.fontXs
                                                    wrapMode: Text.WordWrap
                                                }

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: modelData.timestamp || ""
                                                    color: Theme.textMuted
                                                    font.pixelSize: Theme.fontXs
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: !!root.selectedTool.name
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.border
                                implicitHeight: schemaColumn.implicitHeight + 16

                                ColumnLayout {
                                    id: schemaColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            text: "Tool Schema"
                                            color: Theme.textPrimary
                                            font.pixelSize: Theme.fontSm
                                            font.bold: true
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    TextArea {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 220
                                        text: root.selectedTool.schemaText || "{}"
                                        readOnly: true
                                        wrapMode: TextArea.NoWrap
                                        font: Theme.monoFont
                                        color: Theme.textPrimary
                                        background: Rectangle {
                                            color: Theme.bg
                                            radius: Theme.radius
                                            border.color: Theme.border
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: !!root.selectedTool.name
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.border
                                implicitHeight: execColumn.implicitHeight + 16

                                ColumnLayout {
                                    id: execColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Label {
                                        text: "Execute"
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSm
                                        font.bold: true
                                    }

                                    TextArea {
                                        id: argsEditor
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 120
                                        text: root.argumentText
                                        wrapMode: TextArea.NoWrap
                                        font: Theme.monoFont
                                        color: Theme.textPrimary
                                        background: Rectangle {
                                            color: Theme.bg
                                            radius: Theme.radius
                                            border.color: Theme.border
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Button {
                                            text: "Run Tool"
                                            enabled: !!root.selectedTool.name
                                            onClicked: {
                                                root.argumentText = argsEditor.text
                                                try {
                                                    const parsed = argsEditor.text.trim().length ? JSON.parse(argsEditor.text) : {}
                                                    root.lastResult = agent.executeToolByName(root.selectedTool.name, parsed)
                                                } catch (e) {
                                                    root.lastResult = { error: "Invalid JSON: " + e.message }
                                                }
                                            }
                                        }

                                        Button {
                                            text: "Reset"
                                            onClicked: argsEditor.text = "{}"
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        visible: Object.keys(root.lastResult || {}).length > 0
                                        color: Theme.bg
                                        radius: Theme.radius
                                        border.color: Theme.border
                                        implicitHeight: resultColumn.implicitHeight + 16

                                        ColumnLayout {
                                            id: resultColumn
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 4

                                            Label {
                                                text: root.lastResult.error ? "Error" : "Result"
                                                color: root.lastResult.error ? Theme.error : Theme.textPrimary
                                                font.pixelSize: Theme.fontSm
                                                font.bold: true
                                            }

                                            TextArea {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 140
                                                text: JSON.stringify(root.lastResult || {}, null, 2)
                                                readOnly: true
                                                wrapMode: TextArea.NoWrap
                                                font: Theme.monoFont
                                                color: Theme.textPrimary
                                                background: Rectangle {
                                                    color: Theme.bg
                                                    radius: Theme.radius
                                                    border.color: Theme.border
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
