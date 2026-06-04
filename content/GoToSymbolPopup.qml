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
    property var symbols: []
    property var filteredSymbols: []

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1
    }

    onOpened: {
        extractSymbols()
        searchInput.text = ""
        filterSymbols()
        searchInput.forceActiveFocus()
    }

    function extractSymbols() {
        if (!agent.currentFilePath || !agent.currentFileContent) {
            symbols = []
            return
        }

        const content = agent.currentFileContent
        const newSymbols = []
        const lines = content.split('\n')
        const path = agent.currentFilePath.toLowerCase()

        if (path.endsWith('.py') || path.endsWith('.pyw')) {
            const pyRegex = /^\s*(def|class)\s+([a-zA-Z_][a-zA-Z0-9_]*)/
            lines.forEach((line, idx) => {
                const match = line.match(pyRegex)
                if (match) {
                    newSymbols.push({ name: match[2], line: idx + 1, type: match[1] === "class" ? "class" : "function" })
                }
            })
        } else if (path.endsWith('.qml')) {
            const idRegex = /id\s*:\s*([a-zA-Z_][a-zA-Z0-9_]*)/
            const propRegex = /property\s+\w+\s+([a-zA-Z_][a-zA-Z0-9_]*)/
            const funcRegex = /function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
            const componentRegex = /^\s*([A-Z][a-zA-Z0-9_]*)\s*\{/
            lines.forEach((line, idx) => {
                let match = line.match(idRegex)
                if (match) { newSymbols.push({ name: "@" + match[1], line: idx + 1, type: "id" }); return; }
                match = line.match(funcRegex)
                if (match) { newSymbols.push({ name: match[1], line: idx + 1, type: "function" }); return; }
                match = line.match(propRegex)
                if (match) { newSymbols.push({ name: "prop: " + match[1], line: idx + 1, type: "property" }); return; }
                match = line.match(componentRegex)
                if (match) { newSymbols.push({ name: match[1], line: idx + 1, type: "class" }); }
            })
        } else if (path.endsWith('.js') || path.endsWith('.ts') || path.endsWith('.jsx') || path.endsWith('.tsx')) {
            const jsRegex = /^\s*(function|class)\s+([a-zA-Z_][a-zA-Z0-9_]*)/
            const arrowRegex = /^\s*(?:const|let|var)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(?:\([^)]*\)|[a-zA-Z_][a-zA-Z0-9_]*)\s*=>/
            lines.forEach((line, idx) => {
                let match = line.match(jsRegex)
                if (match) { newSymbols.push({ name: match[2], line: idx + 1, type: match[1] })
                } else {
                    match = line.match(arrowRegex)
                    if (match) { newSymbols.push({ name: match[1], line: idx + 1, type: "function" }) }
                }
            })
        } else {
            const cRegex = /^\s*(?:[\w<>:\[\]]+[\s\&\*]+)+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
            lines.forEach((line, idx) => {
                const match = line.match(cRegex)
                if (match && !/^(if|for|while|switch|return)$/.test(match[1])) {
                    newSymbols.push({ name: match[1], line: idx + 1, type: "function" })
                }
            })
        }
        symbols = newSymbols
    }

    function filterSymbols() {
        const query = searchInput.text.toLowerCase()
        if (!query) {
            filteredSymbols = symbols
            return
        }
        filteredSymbols = symbols.filter(s => s.name.toLowerCase().includes(query))
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
                Label { text: "@"; font.pixelSize: 18; color: Theme.accent }
                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "Go to symbol in file..."
                    font.pixelSize: Theme.fontMd
                    color: Theme.textPrimary
                    background: Item {}
                    onTextChanged: filterSymbols()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) { symbolList.currentIndex = (symbolList.currentIndex + 1) % symbolList.count; event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { symbolList.currentIndex = (symbolList.currentIndex - 1 + symbolList.count) % symbolList.count; event.accepted = true; }
                        else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            if (symbolList.currentItem) symbolList.currentItem.select()
                            event.accepted = true
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }

        ListView {
            id: symbolList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filteredSymbols
            highlight: Rectangle { color: Theme.accent; opacity: 0.1 }
            delegate: ItemDelegate {
                width: symbolList.width
                height: 45
                onClicked: select()
                function select() {
                    if (typeof editorPanel !== "undefined") {
                        editorPanel.goToLine(modelData.line)
                    }
                    root.close()
                }
                contentItem: RowLayout {
                    spacing: 12
                    Label {
                        text: modelData.type === "class" ? "C" : (modelData.type === "function" ? "f" : "#")
                        color: Theme.accent
                        font.bold: true
                        font.family: Theme.monoFont.family
                        Layout.preferredWidth: 20
                    }
                    Label {
                        text: modelData.name
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSm
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Label {
                        text: "line " + modelData.line
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                    }
                }
            }
        }
    }
}

