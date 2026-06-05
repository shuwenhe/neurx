import QtQuick 6.2
import QtQuick.Controls 6.2
import NeurXCode

ScrollBar {
    id: control
    policy: ScrollBar.AsNeeded
    property real collapsedWidth: 9
    property real hoveredWidth: 12
    property real thumbWidth: 8
    property real thumbHeight: 28
    property real inactiveOpacity: 0.5
    property real activeOpacity: 1.0
    property real backgroundOpacity: 0.1
    property color thumbColor: "#424242"
    property color hoverThumbColor: "#797979"
    property color pressedThumbColor: "#969696"

    width: control.hovered || control.pressed || control.active ? control.hoveredWidth : control.collapsedWidth
    minimumSize: 0.12

    contentItem: Rectangle {
        implicitWidth: control.thumbWidth
        implicitHeight: control.thumbHeight
        radius: Math.max(2, control.thumbWidth / 2)
        color: control.pressed
                ? control.pressedThumbColor
                : (control.hovered || control.active ? control.hoverThumbColor : control.thumbColor)
        opacity: control.pressed
                ? control.activeOpacity
                : (control.hovered || control.active ? control.activeOpacity : control.inactiveOpacity)
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }
    }

    background: Item {
        implicitWidth: control.hoveredWidth
        opacity: control.hovered || control.active ? control.backgroundOpacity : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
