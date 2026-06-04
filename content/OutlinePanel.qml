import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root
    required property var agent

    property var symbols: []
    property bool loading: false

    function refresh() {
        if (!agent.currentFilePath || !agent.currentFileContent) {
            symbols = []
            return
        }

        loading = true
        const content = agent.currentFileContent
        const newSymbols = []
        const lines = content.split('\n')
        const path = agent.currentFilePath.toLowerCase()

        if (path.endsWith('.py') || path.endsWith('.pyw')) {
            const pyRegex = /^\s*(def|class)\s+([a-zA-Z_][a-zA-Z0-9_]*)/
            lines.forEach((line, idx) => {
                const match = line.match(pyRegex)
                if (match) {
                    newSymbols.push({
                        name: match[2],
                        line: idx + 1,
                        type: match[1] === "class" ? "class" : "function"
                    })
                }
            })
        } else if (path.endsWith('.qml')) {
            const idRegex = /id\s*:\s*([a-zA-Z_][a-zA-Z0-9_]*)/
            const propRegex = /property\s+\w+\s+([a-zA-Z_][a-zA-Z0-9_]*)/
            const funcRegex = /function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
            const componentRegex = /^\s*([A-Z][a-zA-Z0-9_]*)\s*\{/

            lines.forEach((line, idx) => {
                let match = line.match(idRegex)
                if (match) {
                    newSymbols.push({ name: "id: " + match[1], line: idx + 1, type: "id" })
                    return
                }
                match = line.match(funcRegex)
                if (match) {
                    newSymbols.push({ name: match[1], line: idx + 1, type: "function" })
                    return
                }
                match = line.match(propRegex)
                if (match) {
                    newSymbols.push({ name: "prop: " + match[1], line: idx + 1, type: "property" })
                    return
                }
                match = line.match(componentRegex)
                if (match) {
                    newSymbols.push({ name: match[1], line: idx + 1, type: "class" })
                }
            })
        } else if (path.endsWith('.js') || path.endsWith('.ts') || path.endsWith('.jsx') || path.endsWith('.tsx')) {
            const jsRegex = /^\s*(function|class)\s+([a-zA-Z_][a-zA-Z0-9_]*)/
            const arrowRegex = /^\s*(?:const|let|var)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(?:\([^)]*\)|[a-zA-Z_][a-zA-Z0-9_]*)\s*=>/
            lines.forEach((line, idx) => {
                let match = line.match(jsRegex)
                if (match) {
                    newSymbols.push({ name: match[2], line: idx + 1, type: match[1] })
                } else {
                    match = line.match(arrowRegex)
                    if (match) {
                        newSymbols.push({ name: match[1], line: idx + 1, type: "function" })
                    }
                }
            })
        } else {
            // General C-style functions (C, C++, Java, C#, Go, etc.)
            const cRegex = /^\s*(?:[\w<>:\[\]]+[\s\&\*]+)+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
            lines.forEach((line, idx) => {
                const match = line.match(cRegex)
                if (match && !/^(if|for|while|switch|return)$/.test(match[1])) {
                    newSymbols.push({
                        name: match[1],
                        line: idx + 1,
                        type: "function"
                    })
                }
            })
        }

        symbols = newSymbols
        loading = false
    }

    Connections {
        target: agent
        function onCurrentFileContentChanged() { refreshTimer.restart() }
        function onCurrentFilePathChanged() { refresh() }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        onTriggered: refresh()
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label {
            text: "OUTLINE"
            font.pixelSize: Theme.fontXs
            font.bold: true
            color: Theme.textMuted
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: symbolList
                anchors.fill: parent
                model: root.symbols
                clip: true
                spacing: 1

                delegate: ItemDelegate {
                    width: symbolList.width
                    height: 32
                    padding: 4

                    onClicked: {
                        agent.openEditorFile(agent.currentFilePath)
                        if (typeof editorPanel !== "undefined") {
                            editorPanel.goToLine(modelData.line)
                        }
                    }

                    background: Rectangle {
                        color: hovered ? Theme.surfaceAlt : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: 8
                        Label {
                            text: modelData.type === "class" ? "C" : (modelData.type === "function" ? "f" : "#")
                            color: Theme.accent
                            font.bold: true
                            font.family: Theme.monoFont.family
                        }
                        Label {
                            text: modelData.name
                            font.pixelSize: Theme.fontSm
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: modelData.line
                            font.pixelSize: Theme.fontXs
                            color: Theme.textMuted
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: symbols.length === 0 && !loading
                    text: agent.currentFilePath ? "No symbols found." : "Open a file to see outline."
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                }
            }
        }
    }
}
