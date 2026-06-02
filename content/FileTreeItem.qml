import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import Qt.labs.folderlistmodel
import NeurXCode

Item {
    id: root

    required property var panel
    property string dirPath: ""
    property int depth: 0
    property string filterText: ""

    signal fileClicked(string path)

    implicitHeight: nodeLoader.implicitHeight

    Component {
        id: nodeComponent

        Item {
            id: node
            width: root.width

            property string dirPath: ""
            property int depth: 0
            property var panel
            property string filterText: ""

            signal fileClicked(string path)

            implicitHeight: folderColumn.implicitHeight

            FolderListModel {
                id: folderModel
                folder: node.dirPath ? "file://" + node.dirPath : ""
                showFiles: true
                showDirs: true
                showHidden: false
                showDirsFirst: true
                sortField: FolderListModel.Name
            }

            Column {
                id: folderColumn
                width: parent.width
                spacing: 0

                Repeater {
                    model: folderModel

                    delegate: Item {
                        id: itemRoot
                        width: folderColumn.width
                        height: rowRect.height + (childLoader.active ? childLoader.implicitHeight : 0)
                        clip: true
                        readonly property string normalizedFilePath: node.panel.normalizedPath(model.filePath)

                        Behavior on height {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                        property bool isCurrentFile: normalizedFilePath === node.panel.agent.currentFilePath
                        property bool searchExpanded: node.panel.isSearchExpanded(normalizedFilePath)
                        visible: {
                            const filter = node.filterText.trim().toLowerCase()
                            if (filter.length === 0)
                                return true
                            if (model.fileIsDir)
                                return model.fileName.toLowerCase().indexOf(filter) >= 0
                                       || node.panel.hasSearchDescendant(normalizedFilePath)
                            return model.fileName.toLowerCase().indexOf(filter) >= 0
                                   || normalizedFilePath.toLowerCase().indexOf(filter) >= 0
                        }

                        Rectangle {
                            id: rowRect
                            width: parent.width
                            height: 22
                            objectName: itemRoot.normalizedFilePath
                            property string dragPath: itemRoot.normalizedFilePath
                            property bool dropHover: false
                            color: "transparent"
                            Drag.active: dragHandler.active
                            Drag.supportedActions: Qt.MoveAction
                            Drag.keys: ["workspace-entry"]
                            Drag.mimeData: ({ path: itemRoot.normalizedFilePath })
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            // Row background — separate so text stays fully opaque
                            Rectangle {
                                anchors.fill: parent
                                color: rowRect.dropHover ? Theme.accent
                                       : itemRoot.isCurrentFile ? Theme.accent
                                       : rowArea.containsMouse ? Theme.surfaceAlt
                                       : "transparent"
                                opacity: rowRect.dropHover ? 0.12 : itemRoot.isCurrentFile ? 0.18 : 1.0
                                border.color: rowRect.dropHover ? Theme.accent : "transparent"
                                border.width: rowRect.dropHover ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                }
                            }

                            // Depth guide lines
                            Repeater {
                                model: node.depth
                                delegate: Rectangle {
                                    x: 11 + (index * 8)
                                    y: 0
                                    width: 1
                                    height: parent.height
                                    color: Theme.border
                                    opacity: 0.4
                                }
                            }

                            // Active-file indicator bar
                            Rectangle {
                                visible: itemRoot.isCurrentFile
                                width: 2
                                height: parent.height
                                color: Theme.accent
                            }

                            Row {
                                anchors {
                                    left: parent.left
                                    leftMargin: 4 + node.depth * 8
                                    right: parent.right
                                    rightMargin: 4
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 2

                                // Rotating chevron — VS Code style
                                Item {
                                    width: 16
                                    height: rowRect.height
                                    Label {
                                        visible: model.fileIsDir
                                        text: "›"
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontMd
                                        font.bold: true
                                        anchors.centerIn: parent
                                        rotation: (node.panel.isExpanded(itemRoot.normalizedFilePath) || itemRoot.searchExpanded) ? 90 : 0
                                        Behavior on rotation {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }

                                // File / folder icon
                                Label {
                                    text: model.fileIsDir
                                          ? ((node.panel.isExpanded(itemRoot.normalizedFilePath) || itemRoot.searchExpanded) ? "📂" : "📁")
                                          : "📄"
                                    font.pixelSize: Theme.fontSm
                                    width: 16
                                }

                                Label {
                                    text: model.fileName
                                    color: itemRoot.isCurrentFile
                                           ? Theme.textPrimary
                                           : (model.fileIsDir ? Theme.textPrimary : Theme.textMuted)
                                    font.family: Theme.uiFont.family
                                    font.pixelSize: Theme.fontSm
                                    elide: Text.ElideRight
                                    width: rowRect.width - (4 + node.depth * 8) - 16 - 16 - 2 - 2 - 4
                                }
                            }

                            Menu {
                                id: rowMenu

                                MenuItem {
                                    text: "新建文件"
                                    onTriggered: root.panel.openCreateDialog(model.fileIsDir ? itemRoot.normalizedFilePath : root.panel.currentDirForPath(itemRoot.normalizedFilePath), false)
                                }

                                MenuItem {
                                    text: "新建文件夹"
                                    onTriggered: root.panel.openCreateDialog(model.fileIsDir ? itemRoot.normalizedFilePath : root.panel.currentDirForPath(itemRoot.normalizedFilePath), true)
                                }

                                MenuSeparator {}

                                MenuItem {
                                    visible: !model.fileIsDir
                                    text: "在编辑器打开"
                                    onTriggered: node.fileClicked(itemRoot.normalizedFilePath)
                                }

                                MenuItem {
                                    visible: model.fileIsDir
                                    text: (node.panel.isExpanded(itemRoot.normalizedFilePath) || itemRoot.searchExpanded) ? "折叠" : "展开"
                                    onTriggered: node.panel.setExpanded(itemRoot.normalizedFilePath, !node.panel.isExpanded(itemRoot.normalizedFilePath))
                                }

                                MenuItem {
                                    visible: model.fileIsDir
                                    text: "设为根目录"
                                    onTriggered: node.panel.diskRoot = itemRoot.normalizedFilePath
                                }

                                MenuItem {
                                    text: "重命名"
                                    onTriggered: root.panel.openRenameDialog(itemRoot.normalizedFilePath)
                                }

                                MenuSeparator {}

                                MenuItem {
                                    text: "复制路径"
                                    onTriggered: node.panel.agent.copyPathToClipboard(itemRoot.normalizedFilePath)
                                }

                                MenuSeparator {}

                                MenuItem {
                                    text: "删除"
                                    onTriggered: root.panel.openDeleteDialog(itemRoot.normalizedFilePath)
                                }
                            }

                            DragHandler {
                                id: dragHandler
                                target: null
                                onActiveChanged: {
                                    if (active && model.fileIsDir)
                                        rowArea.cancelClick = true
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: ["workspace-entry"]
                                visible: model.fileIsDir
                                onEntered: rowRect.dropHover = true
                                onExited: rowRect.dropHover = false
                                onDropped: (drop) => {
                                    rowRect.dropHover = false
                                    const source = drop.source
                                    if (!source || !source.dragPath || source.dragPath === itemRoot.normalizedFilePath)
                                        return
                                    if (source.dragPath.startsWith(itemRoot.normalizedFilePath + "/"))
                                        return
                                    root.panel.agent.moveWorkspacePath(source.dragPath, itemRoot.normalizedFilePath)
                                }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                property bool cancelClick: false
                                onClicked: (mouse) => {
                                    if (cancelClick) {
                                        cancelClick = false
                                        return
                                    }
                                    if (mouse.button === Qt.RightButton) {
                                        const popupPos = rowRect.mapToItem(null, mouse.x, mouse.y)
                                        rowMenu.x = popupPos.x
                                        rowMenu.y = popupPos.y
                                        rowMenu.open()
                                        return
                                    }

                                    if (model.fileIsDir) {
                                        node.panel.setExpanded(itemRoot.normalizedFilePath, !node.panel.isExpanded(itemRoot.normalizedFilePath))
                                    } else {
                                        node.fileClicked(itemRoot.normalizedFilePath)
                                    }
                                }
                                onPressAndHold: {
                                    const popupPos = rowRect.mapToItem(null, width / 2, height / 2)
                                    rowMenu.x = popupPos.x
                                    rowMenu.y = popupPos.y
                                    rowMenu.open()
                                }
                            }
                        }

                        Loader {
                            id: childLoader
                            anchors.top: rowRect.bottom
                            width: parent.width
                            active: model.fileIsDir && (
                                node.panel.isExpanded(itemRoot.normalizedFilePath) ||
                                itemRoot.searchExpanded ||
                                (node.filterText.trim().length > 0 && node.panel.hasSearchDescendant(itemRoot.normalizedFilePath))
                            )
                            sourceComponent: nodeComponent
                            onLoaded: {
                                item.dirPath = itemRoot.normalizedFilePath
                                item.depth = node.depth + 1
                                item.panel = node.panel
                                item.filterText = node.filterText
                                item.fileClicked.connect(node.fileClicked)
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: nodeLoader
        anchors.fill: parent
        sourceComponent: nodeComponent
        onLoaded: {
            item.dirPath = root.dirPath
            item.depth = root.depth
            item.panel = root.panel
            item.filterText = root.filterText
            item.fileClicked.connect(root.fileClicked)
        }
    }
}
