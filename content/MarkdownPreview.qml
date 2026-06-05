import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    property string markdownText: ""
    property string filePath: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header for Markdown Preview
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
                    text: "PREVIEW: " + (root.filePath.split("/").pop() || "Untitled.md")
                    font.pixelSize: Theme.fontXs
                    font.bold: true
                    color: Theme.textMuted
                    Layout.fillWidth: true
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: CustomScrollBar {}
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Rectangle {
                width: parent.width
                implicitHeight: previewText.implicitHeight + 40
                color: Theme.bg

                Text {
                    id: previewText
                    width: parent.width - 40
                    x: 20
                    y: 20
                    text: root.markdownText
                    textFormat: Text.MarkdownText
                    wrapMode: Text.WordWrap
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontMd

                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }
        }
    }
}
