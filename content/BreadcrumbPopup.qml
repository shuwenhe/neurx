import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import Qt.labs.folderlistmodel
import NeurXCode

Popup {
    id: root
    width: 250
    height: 350
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string path: ""
    signal itemClicked(string filePath, bool isDir)

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1
        layer.enabled: true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: folderModel
            ScrollBar.vertical: CustomScrollBar {
                collapsedWidth: 8
                hoveredWidth: 10
                thumbWidth: 6
                thumbHeight: 26
                inactiveOpacity: 0.35
                activeOpacity: 0.9
                backgroundOpacity: 0.07
                thumbColor: "#3d3d3d"
                hoverThumbColor: "#646464"
                pressedThumbColor: "#909090"
            }

            FolderListModel {
                id: folderModel
                folder: root.path ? "file://" + root.path : ""
                showFiles: true
                showDirs: true
                showHidden: false
                showDirsFirst: true
                sortField: FolderListModel.Name
            }

            delegate: ItemDelegate {
                width: listView.width
                height: 30
                onClicked: {
                    const normalized = model.filePath.toString().replace("file://", "").replace(/\\/g, "/")
                    root.itemClicked(normalized, model.fileIsDir)
                    root.close()
                }

                contentItem: RowLayout {
                    spacing: 8
                    Label {
                        text: model.fileIsDir ? "📁" : "📄"
                        font.pixelSize: Theme.fontSm
                    }
                    Label {
                        text: model.fileName
                        font.pixelSize: Theme.fontSm
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
