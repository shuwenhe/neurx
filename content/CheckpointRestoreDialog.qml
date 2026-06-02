import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Popup {
    id: root

    modal: true
    closePolicy: Popup.CloseOnEscape
    padding: 20
    implicitWidth: 420

    property string checkpointId: ""
    property string checkpointDescription: ""
    property var affectedFiles: []

    signal confirmed(string checkpointId)

    function show(checkpointId, description, files) {
        root.checkpointId = checkpointId || ""
        root.checkpointDescription = description || ""
        root.affectedFiles = files || []
        open()
    }

    background: Rectangle {
        color: Theme.surfaceAlt
        radius: Theme.radius
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0

        Label {
            text: "Restore Checkpoint"
            font.pixelSize: Theme.fontMd
            font.bold: true
            color: Theme.textPrimary
        }

        Item { height: 12 }

        Label {
            Layout.fillWidth: true
            text: "This will overwrite current workspace files with the selected checkpoint."
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
            wrapMode: Text.Wrap
        }

        Item { height: 12 }

        Rectangle {
            Layout.fillWidth: true
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border
            implicitHeight: detailsColumn.implicitHeight + 16

            ColumnLayout {
                id: detailsColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Label {
                    text: "Checkpoint: [" + root.checkpointId + "]"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSm
                    font.bold: true
                }

                Label {
                    Layout.fillWidth: true
                    text: root.checkpointDescription
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    wrapMode: Text.Wrap
                    visible: root.checkpointDescription.length > 0
                }

                Label {
                    text: "Affected files"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSm
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: Theme.surfaceAlt
                    radius: Theme.radius
                    border.color: Theme.border
                    implicitHeight: filesColumn.implicitHeight + 12

                    ColumnLayout {
                        id: filesColumn
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Label {
                            visible: root.affectedFiles.length === 0
                            text: "No file preview available."
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                        }

                        Repeater {
                            model: root.affectedFiles.slice(0, 8)

                            delegate: Label {
                                required property var modelData
                                Layout.fillWidth: true
                                text: "\u2022 " + modelData
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        Label {
                            visible: root.affectedFiles.length > 8
                            text: "+" + (root.affectedFiles.length - 8) + " more files"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                        }
                    }
                }
            }
        }

        Item { height: 16 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Button {
                text: "Cancel"
                onClicked: root.close()
            }

            Button {
                text: "Restore"
                onClicked: {
                    root.confirmed(root.checkpointId)
                    root.close()
                }
                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.warning
                }
                contentItem: Label {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
