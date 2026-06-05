import QtQuick
import QtQuick.Controls

/**
 * FileTreeContextMenu.qml
 * Right-click context menu for file tree items
 */

Menu {
    id: contextMenu

    // Properties
    property string targetPath: ""
    property bool isDirectory: false

    // Signals
    signal newFile()
    signal newFolder()
    signal rename()
    signal deleteItem()
    signal copyPath()
    signal copyRelativePath()
    signal cut()
    signal copy()
    signal paste()

    signal findInFolder()

    // File operations
    MenuItem {
        text: "New File"
        onTriggered: contextMenu.newFile()
    }

    MenuItem {
        text: "New Folder"
        onTriggered: contextMenu.newFolder()
    }

    MenuSeparator { }

    MenuItem {
        text: "Find in Folder..."
        visible: isDirectory
        onTriggered: contextMenu.findInFolder()
    }

    MenuSeparator { visible: isDirectory }

    // Edit operations
    MenuItem {
        text: "Cut"
        onTriggered: contextMenu.cut()
    }

    MenuItem {
        text: "Copy"
        onTriggered: contextMenu.copy()
    }

    MenuItem {
        text: "Paste"
        onTriggered: contextMenu.paste()
    }

    MenuSeparator { }

    // File operations
    MenuItem {
        text: "Rename"
        onTriggered: contextMenu.rename()
    }

    MenuItem {
        text: "Delete"
        onTriggered: contextMenu.deleteItem()
    }

    MenuSeparator { }

    // Path operations
    MenuItem {
        text: "Copy Path"
        onTriggered: contextMenu.copyPath()
    }

    MenuItem {
        text: "Copy Relative Path"
        onTriggered: contextMenu.copyRelativePath()
    }

    // Styling
    delegate: MenuItem {
        id: menuItem
        implicitWidth: 200
        implicitHeight: 30
        padding: 0

        contentItem: Text {
            text: menuItem.text
            color: menuItem.highlighted ? "#ffffff" : (text === "Delete" ? "#d4534f" : "#cccccc")
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
            font.pixelSize: 11
        }

        background: Rectangle {
            color: menuItem.highlighted ? "#094771" : "transparent"
        }
    }

    background: Rectangle {
        color: "#252526"
        border.color: "#3e3e42"
        border.width: 1
        implicitWidth: 200
        implicitHeight: implicitContentHeight
    }
}
