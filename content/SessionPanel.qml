import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root

    required property var recentSessions

    signal resumeRequested(string sessionId)
    signal newSessionRequested()

    readonly property bool hasSessions: recentSessions && recentSessions.length > 0
    implicitHeight: hasSessions ? panel.implicitHeight : 0
    visible: hasSessions

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
                            text: modelData.sessionId
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontXs
                            font.bold: true
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
                                onClicked: root.resumeRequested(modelData.sessionId)
                            }
                        }
                    }
                }
            }
        }
    }
}
