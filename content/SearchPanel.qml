import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    required property var agent

    property string searchPath: ""
    property string searchText: ""
    property string replaceText: ""
    property bool replaceVisible: false
    property var results: []
    property bool searching: false

    function performSearch() {
        if (!searchText.trim()) return
        searching = true
        results = []

        // Use the C++ SearchService instead of Grep tool for better performance and VS Code logic
        const searchResults = agent.performSearch(searchText, false) // 2nd arg is useRegex

        const newResults = []
        searchResults.forEach(res => {
            newResults.push({
                file: res.file,
                line: res.line + 1, // SearchService uses 0-based lines
                content: res.lineText.trim(),
                fullPath: res.file.startsWith("/") ? res.file : agent.workspacePath + "/" + res.file
            })
        })
        results = newResults
        searching = false
    }

    function performReplaceAll() {
        if (!searchText || !replaceText) return
        searching = true

        const count = agent.replaceAllMatches(searchText, replaceText)
        agent.notifyInfo("Replaced " + count + " occurrences.")

        searching = false
        performSearch() // Refresh results
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Label {
            text: "SEARCH"
            font.pixelSize: Theme.fontXs
            font.bold: true
            color: Theme.textMuted
            Layout.fillWidth: true
        }

        ToolButton {
            text: replaceVisible ? "▼" : "▶"
            flat: true
            onClicked: replaceVisible = !replaceVisible
            ToolTip.text: "Toggle Replace"
            ToolTip.visible: hovered
        }

        Rectangle {
            Layout.fillWidth: true
            height: replaceVisible ? 72 : 32
            color: Theme.surfaceAlt
            radius: Theme.radius
            border.color: (searchInput.activeFocus || replaceInput.activeFocus) ? Theme.accent : Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "Search"
                        text: root.searchText
                        background: Item {}
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSm
                        onTextChanged: root.searchText = text
                        onAccepted: performSearch()
                    }

                    ToolButton {
                        text: "🔍"
                        flat: true
                        onClicked: performSearch()
                        enabled: !root.searching
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.replaceVisible
                    spacing: 4

                    TextField {
                        id: replaceInput
                        Layout.fillWidth: true
                        placeholderText: "Replace"
                        text: root.replaceText
                        background: Item {}
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSm
                        onTextChanged: root.replaceText = text
                        onAccepted: performReplaceAll()
                    }

                    ToolButton {
                        text: "➡"
                        flat: true
                        onClicked: performReplaceAll()
                        enabled: !root.searching && results.length > 0
                        ToolTip.text: "Replace All"
                        ToolTip.visible: hovered
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: resultsList
                anchors.fill: parent
                model: root.results
                clip: true
                spacing: 0

                section.property: "file"
                section.criteria: ViewSection.FullString
                section.delegate: Rectangle {
                    width: resultsList.width
                    height: 28
                    color: Theme.surfaceAlt

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 8
                        Label {
                            text: section.split('/').pop()
                            font.bold: true
                            font.pixelSize: Theme.fontSm
                            color: Theme.textPrimary
                        }
                        Label {
                            text: section
                            font.pixelSize: Theme.fontXs
                            color: Theme.textMuted
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }
                }

                delegate: ItemDelegate {
                    width: resultsList.width
                    height: 40
                    padding: 8

                    onClicked: {
                        agent.openEditorFile(modelData.fullPath)
                        // Trigger jump to line in EditorPanel. Since SearchPanel is a child of App.qml,
                        // it can access editorPanel by ID if it's in the same context.
                        if (typeof editorPanel !== "undefined") {
                            editorPanel.goToLine(parseInt(modelData.line))
                        }
                    }

                    background: Rectangle {
                        color: hovered ? Theme.surfaceAlt : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: 8
                        Label {
                            text: modelData.line
                            font.pixelSize: Theme.fontXs
                            color: Theme.textMuted
                            Layout.preferredWidth: 30
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: modelData.content
                            font.family: Theme.monoFont.family
                            font.pixelSize: Theme.fontXs
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: results.length === 0 && !searching && searchText !== ""
                    text: "No results matched your search."
                    color: Theme.textMuted
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    running: searching
                }

                ScrollBar.vertical: ScrollBar {}
            }
        }
    }
}
