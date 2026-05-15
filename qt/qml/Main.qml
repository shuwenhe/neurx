import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Window

Window {
    id: root
    visible: true
    width: 960
    height: 640
    minimumWidth: 760
    minimumHeight: 520
    title: qsTr("Neurx Qt Agent Shell")
    color: "#111111"

    AppShell {
        anchors.fill: parent
    }
}
