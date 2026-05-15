import QtQuick
import QtQuick.Window

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    width: 960
    height: 640
    minimumWidth: 760
    minimumHeight: 520
    title: qsTr("Neurx App Shell")
    color: "#111111"

    AppShell {
        anchors.fill: parent
    }
}
