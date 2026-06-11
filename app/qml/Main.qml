import QtQuick
import QtQuick.Window

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    width: 1440
    height: 900
    minimumWidth: 1200
    minimumHeight: 760
    title: qsTr("Neurx Explorer / Editor / Agent")
    color: "#111111"

    AppShell {
        id: appShell
        width: root.width / appShell.uiZoom
        height: root.height / appShell.uiZoom
        scale: appShell.uiZoom
        transformOrigin: Item.TopLeft
    }

    Shortcut {
        sequences: ["Ctrl++", "Ctrl+=", "Ctrl+Shift+="]
        onActivated: appShell.zoomIn()
    }

    Shortcut {
        sequences: ["Ctrl+-", "Ctrl+_"]
        onActivated: appShell.zoomOut()
    }

    Shortcut {
        sequences: ["Ctrl+0"]
        onActivated: appShell.resetZoom()
    }
}
