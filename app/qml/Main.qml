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
        anchors.fill: parent
    }
}
