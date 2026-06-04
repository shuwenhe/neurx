import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    implicitWidth: 48
    implicitHeight: 48

    property string icon: ""
    property bool active: false
    property string toolTip: ""
    signal clicked()

    Rectangle {
        anchors.fill: parent
        color: hovered ? Theme.surface : "transparent"
        visible: hovered || active
        opacity: active ? 1.0 : (hovered ? 0.6 : 0)

        Rectangle {
            anchors.left: parent.left
            height: parent.height - 20
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            color: Theme.accent
            visible: active
        }
    }

    Label {
        anchors.centerIn: parent
        text: root.icon
        font.pixelSize: 20
        color: active ? Theme.textPrimary : Theme.textMuted
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    property bool hovered: mouseArea.containsMouse

    ToolTip {
        visible: root.hovered && toolTip !== ""
        text: root.toolTip
        delay: 500
    }
}

