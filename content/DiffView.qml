import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    property string originalText: ""
    property string modifiedText: ""
    property string fileName: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: Theme.surfaceAlt
            border.color: Theme.border
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                Label {
                    text: "DIFF: " + root.fileName
                    font.pixelSize: Theme.fontXs
                    font.bold: true
                    color: Theme.textMuted
                    Layout.fillWidth: true
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Original (Left)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    color: Theme.surfaceAlt
                    Label {
                        anchors.centerIn: parent
                        text: "ORIGINAL (HEAD)"
                        font.pixelSize: Theme.fontXs
                        color: Theme.textMuted
                    }
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        text: root.originalText
                        readOnly: true
                        font: Theme.monoFont
                        color: Theme.textPrimary
                        background: null
                    }
                }
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

            // Modified (Right)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    color: Theme.surfaceAlt
                    Label {
                        anchors.centerIn: parent
                        text: "MODIFIED"
                        font.pixelSize: Theme.fontXs
                        color: Theme.textMuted
                    }
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        text: root.modifiedText
                        readOnly: true
                        font: Theme.monoFont
                        color: Theme.textPrimary
                        background: null
                    }
                }
            }
        }
    }
}

