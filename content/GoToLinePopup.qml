import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Popup {
    id: root
    width: 300
    height: 80
    anchors.centerIn: parent
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 20

    signal lineEntered(int line)

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            text: "Go to Line"
            font.pixelSize: Theme.fontSm
            font.bold: true
            color: Theme.textPrimary
        }

        TextField {
            id: lineInput
            Layout.fillWidth: true
            placeholderText: "Enter line number..."
            inputMethodHints: Qt.ImhDigitsOnly
            font.pixelSize: Theme.fontMd
            color: Theme.textPrimary
            background: Rectangle {
                radius: Theme.radius
                color: Theme.surfaceAlt
                border.color: lineInput.activeFocus ? Theme.accent : Theme.border
            }

            onAccepted: {
                const line = parseInt(text)
                if (!isNaN(line)) {
                    root.lineEntered(line)
                    root.close()
                }
            }

            Component.onCompleted: forceActiveFocus()
        }
    }

    onOpened: {
        lineInput.text = ""
        lineInput.forceActiveFocus()
    }
}

