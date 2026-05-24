import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    width: 430
    height: 932
    visible: true
    title: qsTr("NeurX Mobile")
    color: "#09111b"

    MobileHome {
        anchors.fill: parent
    }
}
