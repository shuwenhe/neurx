import QtQuick 6.2
import QtQuick.Controls 6.2
import NeurXCode

ScrollBar {
    id: control
    policy: ScrollBar.AsNeeded
    width: control.hovered || control.pressed || control.active ? 8 : 6

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 30
        radius: 3
        color: control.pressed ? Theme.accent : (control.hovered || control.active ? Theme.textMuted : "#444")
        opacity: control.active || control.hovered || control.pressed ? 0.95 : 0.28
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }
    }

    background: Item {
        implicitWidth: 6
        opacity: control.hovered || control.active ? 1.0 : 0.0
    }
}
