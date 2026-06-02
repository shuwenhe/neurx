import QtQuick 6.2
import QtQuick.Controls 6.2
import NeurXCode

// ── ErrorBanner ───────────────────────────────────────────────────────────────

Rectangle {
    id: root
    height: visible ? 44 : 0
    visible: false
    color: bannerColor
    z: 100

    property string message: ""
    property color bannerColor: Theme.error

    function showError(msg) {
        show(msg, Theme.error)
    }

    function showSuccess(msg) {
        show(msg, Theme.success)
    }

    function show(msg, colorValue) {
        message = msg
        bannerColor = colorValue
        visible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 6000
        onTriggered: root.visible = false
    }

    Label {
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        text: root.message
        color: "white"
        font.pixelSize: Theme.fontMd
        width: parent.width - 60
        elide: Text.ElideRight
    }

    Label {
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        text: "✕"
        color: "white"
        font.pixelSize: Theme.fontLg
        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }
}
