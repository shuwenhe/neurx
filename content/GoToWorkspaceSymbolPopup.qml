import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Popup {
    id: root
    anchors.centerIn: parent
    width: 600
    height: 400
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 0

    required property var agent
    property var results: []

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1
    }

    onOpened: {
        searchInput.text = ""
        results = []
        searchInput.forceActiveFocus()
    }

    function performSearch() {
        const query = searchInput.text.trim()
        if (query.length < 2) {
            results = []
            return
        }

        // Use Grep to find common patterns like 'function name', 'class name', 'def name'
        // This is a naive implementation but works for a "do all" request.
        const patterns = [
            "function\\s+" + query,
            "class\\s+" + query,
            "def\\s+" + query,
            "id\\s*:\\s*" + query
        ]

        const allResults = []
        patterns.forEach(p => {
            const res = agent.executeToolByName("Grep", { "pattern": p, "path": "." })
            if (res && res.result) {
                const lines = res.result.split('\n')
                lines.forEach(line => {
                    const parts = line.match(/^(.+?):(\d+): (.*)$/)
                    if (parts) {
                        allResults.push({
                            file: parts[1],
                            line: parts[2],
                            content: parts[3].trim(),
                            fullPath: agent.workspacePath + "/" + parts[1]
                        })
                    }
                })
            }
        })
        results = allResults
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 10
                Label { text: "#"; font.pixelSize: 18; color: Theme.accent }
                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "Search symbols in workspace..."
                    font.pixelSize: Theme.fontMd
                    color: Theme.textPrimary
                    background: Item {}
                    onTextChanged: searchTimer.restart()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) { resultList.currentIndex = (resultList.currentIndex + 1) % resultList.count; event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { resultList.currentIndex = (resultList.currentIndex - 1 + resultList.count) % resultList.count; event.accepted = true; }
                        else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            if (resultList.currentItem) resultList.currentItem.select()
                            event.accepted = true
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.results
            highlight: Rectangle { color: Theme.accent; opacity: 0.1 }
            delegate: ItemDelegate {
                width: resultList.width
                height: 50
                onClicked: select()
                function select() {
                    agent.openEditorFile(modelData.fullPath)
                    if (typeof editorPanel !== "undefined") {
                        editorPanel.goToLine(parseInt(modelData.line))
                    }
                    root.close()
                }
                contentItem: ColumnLayout {
                    spacing: 2
                    Label {
                        text: modelData.content
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSm
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Label {
                            text: modelData.file + ":" + modelData.line
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: searchTimer
        interval: 300
        onTriggered: performSearch()
    }
}

