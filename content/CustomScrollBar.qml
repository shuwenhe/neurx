import QtQuick 6.2
import QtQuick.Controls 6.2
import NeurXCode

ScrollBar {
    id: control
    policy: ScrollBar.AsNeeded
    width: control.hovered || control.pressed || control.active ? 12 : 9
    minimumSize: 0.12

    contentItem: Rectangle {
        implicitWidth: 8
        implicitHeight: 28
        radius: 4
        color: control.pressed
                ? "#969696"
                : (control.hovered || control.active ? "#797979" : "#424242")
        opacity: control.pressed
                ? 1.0
                : (control.hovered || control.active ? 1.0 : 0.5)
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }
    }

    background: Item {
        implicitWidth: 12
        opacity: control.hovered || control.active ? 0.1 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
