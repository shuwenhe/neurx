import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Rectangle {
    id: root

    anchors.fill: parent
    z: 10000
    visible: isVisible
    color: "transparent"
    focus: isVisible

    property bool isVisible: false
    property var allCommands: []
    property var filteredCommands: []
    property string query: ""
    property int selectedIndex: -1

    signal commandSelected(string commandId)
    signal visibilityChanged(bool visible)

    Keys.onEscapePressed: hide()

    function setCommands(commands) {
        allCommands = commands || []
        applyFilter()
    }

    function show(commands) {
        if (commands !== undefined)
            setCommands(commands)
        isVisible = true
        visibilityChanged(true)
        searchInput.forceActiveFocus()
        searchInput.selectAll()
        applyFilter()
    }

    function hide() {
        isVisible = false
        visibilityChanged(false)
    }

    function applyFilter() {
        query = searchInput.text.trim().toLowerCase()
        const results = []
        for (let i = 0; i < allCommands.length; ++i) {
            const cmd = allCommands[i]
            const title = (cmd.title || "").toLowerCase()
            const id = (cmd.id || "").toLowerCase()
            const description = (cmd.description || "").toLowerCase()
            const category = (cmd.category || "").toLowerCase()
            const shortcut = (cmd.shortcut || "").toLowerCase()
            if (!query
                || title.includes(query)
                || id.includes(query)
                || description.includes(query)
                || category.includes(query)
                || shortcut.includes(query)) {
                results.push(cmd)
            }
        }
        filteredCommands = results
        selectedIndex = results.length > 0 ? 0 : -1
    }

    function selectCurrent() {
        if (selectedIndex < 0 || selectedIndex >= filteredCommands.length)
            return
        const cmd = filteredCommands[selectedIndex]
        if (!cmd || !cmd.id)
            return
        commandSelected(cmd.id)
        hide()
    }

    function moveSelection(delta) {
        if (filteredCommands.length === 0)
            return
        selectedIndex = (selectedIndex + delta + filteredCommands.length) % filteredCommands.length
        commandList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    Rectangle {
        id: paletteWindow
        width: Math.min(760, Math.max(520, parent.width * 0.62))
        height: Math.min(560, Math.max(240, searchInput.implicitHeight + commandList.contentHeight + 32))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 60
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius + 4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            TextField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "Type a command..."
                text: ""
                font.pixelSize: Theme.fontMd
                color: Theme.textPrimary
                selectionColor: Theme.accent
                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.surfaceAlt
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                }

                onTextChanged: root.applyFilter()

                Keys.onEscapePressed: root.hide()
                Keys.onDownPressed: event => {
                    event.accepted = true
                    root.moveSelection(1)
                }
                Keys.onUpPressed: event => {
                    event.accepted = true
                    root.moveSelection(-1)
                }
                Keys.onReturnPressed: event => {
                    event.accepted = true
                    root.selectCurrent()
                }
                Keys.onEnterPressed: event => {
                    event.accepted = true
                    root.selectCurrent()
                }
            }

            ListView {
                id: commandList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filteredCommands
                currentIndex: root.selectedIndex
                highlightMoveDuration: 0
                spacing: 4

                delegate: ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    height: 56
                    highlighted: ListView.isCurrentItem

                    background: Rectangle {
                        radius: Theme.radius
                        color: ListView.isCurrentItem ? Theme.accentHover : Theme.surfaceAlt
                        border.color: ListView.isCurrentItem ? Theme.accent : Theme.border
                    }

                    contentItem: ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: modelData.title || modelData.id || "Untitled"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: modelData.shortcut || ""
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                            }
                        }

                        Label {
                            text: (modelData.category ? "[" + modelData.category + "] " : "") + (modelData.description || "")
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    onClicked: {
                        root.selectedIndex = index
                        root.selectCurrent()
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    onIsVisibleChanged: {
        if (isVisible) {
            searchInput.forceActiveFocus()
            applyFilter()
        } else {
            query = ""
            searchInput.text = ""
        }
    }
}
