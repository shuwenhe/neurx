import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root

    required property var todoItems
    required property var recentCheckpoints

    signal restoreRequested(string checkpointId, string description)

    readonly property bool hasItems: todoItems && todoItems.length > 0
    readonly property bool hasCheckpoints: recentCheckpoints && recentCheckpoints.length > 0

    implicitHeight: hasItems || hasCheckpoints ? panel.implicitHeight : 0
    visible: hasItems || hasCheckpoints

    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: contentColumn.implicitHeight + 20
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.radius + 2

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: "Task Plan"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontMd
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: root.todoItems.length + " items"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                }
            }

            Repeater {
                model: root.todoItems

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: row.implicitHeight + 12
                    radius: Theme.radius
                    color: modelData.status === "in_progress"
                        ? Theme.surfaceAlt
                        : "transparent"
                    border.color: modelData.status === "in_progress"
                        ? Theme.accent
                        : Theme.border
                    border.width: modelData.status === "in_progress" ? 1 : 0

                    RowLayout {
                        id: row
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Label {
                            text: modelData.status === "completed" ? "✓"
                                : modelData.status === "in_progress" ? "▶"
                                : modelData.status === "cancelled" ? "✕"
                                : "○"
                            color: modelData.status === "completed" ? Theme.success
                                : modelData.status === "in_progress" ? Theme.accent
                                : modelData.status === "cancelled" ? Theme.error
                                : Theme.textMuted
                            font.pixelSize: Theme.fontMd
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                Layout.fillWidth: true
                                text: modelData.content
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                wrapMode: Text.Wrap
                            }

                            Label {
                                text: "[" + modelData.id + "] " + modelData.status
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: checkpointColumn.implicitHeight + 12
                visible: root.hasCheckpoints
                color: "transparent"
                border.color: Theme.border
                radius: Theme.radius

                ColumnLayout {
                    id: checkpointColumn
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: "Recent Checkpoints"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSm
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Label {
                            text: root.recentCheckpoints.length + " saved"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                        }
                    }

                    Repeater {
                        model: root.recentCheckpoints.slice(0, 5)

                        delegate: ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                Layout.fillWidth: true
                                text: "[" + modelData.id + "] " + modelData.description
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                wrapMode: Text.Wrap
                            }

                            Label {
                                text: modelData.timestamp
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Item { Layout.fillWidth: true }

                                Button {
                                    text: "Restore"
                                    implicitHeight: 28

                                    onClicked: {
                                        root.restoreRequested(modelData.id, modelData.description || "")
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
