import QtQuick 6.2
import QtQuick.Controls 6.2
import NeurXCode

ScrollBar {
    id: control
    policy: ScrollBar.AsNeeded
    width: 6

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 30
        radius: 3
        color: control.pressed ? Theme.textMuted : (control.hovered ? "#555" : "#444")
        opacity: control.active || control.hovered ? 0.9 : 0.3
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    background: Item {
        implicitWidth: 6
    }
}

