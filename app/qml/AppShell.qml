import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: shell

    readonly property color bg: "#111111"
    readonly property color surface: "#1a1a1a"
    readonly property color border: "#2b2b2b"
    readonly property color accent: "#19a974"
    readonly property color textPrimary: "#f3f3f3"
    readonly property color textMuted: "#a0a0a0"
    readonly property color panelAlt: "#151515"
    readonly property color panelHover: "#202020"
    readonly property color editorBg: "#0f1115"
    readonly property color selectionBg: "#173f31"
    readonly property color userBubble: "#123d2f"
    readonly property color agentBubble: "#171b22"
    readonly property color lineNumberBg: "#14181d"
    readonly property color lineNumberBorder: "#20262d"
    readonly property color highlightKeyword: "#6cb6ff"
    readonly property color highlightString: "#f69d50"
    readonly property color highlightComment: "#7f8c98"
    readonly property color highlightDirective: "#d2a8ff"
    readonly property int paneHandleWidth: 10
    readonly property int paneMinExplorerWidth: 220
    readonly property int paneMinEditorWidth: 420
    readonly property int paneMinAgentWidth: 300

    readonly property int workspaceMargin: 20

    property int selectedFileIndex: 1
    property string selectedFilePath: ""
    property int explorerPaneWidth: 280
    property int agentPaneWidth: 342
    property int runSteps: 4
    property bool agentRunning: false
    property int runClickSeq: 0
    property int runStartMs: 0
    property string lastPromptText: ""
    property string lastResponseLabel: qsTr("NeurX")
    property string lastRunDurationText: ""
    property string runtimeStatusText: Runtime.ping()
    property string editorPlainText: ""
    property string editorKind: "Text"
    property bool agentDetailsExpanded: false
    property int activeAssistantMessageIndex: -1
    property string copyNoticeText: ""

    function escapeHtml(text) {
        return (text || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\"/g, "&quot;")
    }

    function syntaxKeywords(kind) {
        if (kind === "QML") {
            return ["import", "property", "readonly", "required", "signal", "function", "if", "else", "return", "true", "false", "var", "let", "const", "id", "onClicked", "anchors", "parent"]
        }
        if (kind === "C++") {
            return ["class", "const", "constexpr", "enum", "explicit", "false", "for", "if", "include", "int", "namespace", "nullptr", "override", "private", "protected", "public", "return", "signals", "slots", "static", "struct", "switch", "template", "true", "void", "while"]
        }
        return ["if", "else", "for", "while", "return", "function", "const", "let", "var", "true", "false"]
    }

    function lineNumberHtml(text) {
        var lineCount = Math.max(1, (text || "").split("\n").length)
        var numbers = []
        for (var index = 1; index <= lineCount; ++index) {
            numbers.push(index)
        }

        return "<pre style=\"margin:0;font-family:'Consolas','Courier New',monospace;font-size:14px;line-height:1.35;color:" + shell.textMuted + ";text-align:right;\">"
            + numbers.join("\n")
            + "</pre>"
    }

    function highlightCode(text, kind) {
        var source = text || ""
        if (!source.length) {
            return "<pre style=\"margin:0;font-family:'Consolas','Courier New',monospace;font-size:14px;line-height:1.35;color:" + shell.textPrimary + ";\"></pre>"
        }

        var keywords = syntaxKeywords(kind)
        var keywordPattern = keywords.length > 0 ? "\\b(?:" + keywords.join("|") + ")\\b" : "$^"
        var tokenPattern = new RegExp("(//[^\\n]*|/\\*[\\s\\S]*?\\*/|\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|#[A-Za-z_][A-Za-z0-9_]*|" + keywordPattern + ")", "g")
        var highlighted = ""
        var lastIndex = 0
        var match

        while ((match = tokenPattern.exec(source)) !== null) {
            highlighted += escapeHtml(source.slice(lastIndex, match.index))
            var token = match[0]
            var color = shell.highlightKeyword

            if (token.indexOf("//") === 0 || token.indexOf("/*") === 0) {
                color = shell.highlightComment
            } else if (token.indexOf("#") === 0) {
                color = shell.highlightDirective
            } else if (token.indexOf("\"") === 0 || token.indexOf("'") === 0) {
                color = shell.highlightString
            }

            highlighted += "<span style=\"color:" + color + ";\">" + escapeHtml(token) + "</span>"
            lastIndex = match.index + token.length
        }

        highlighted += escapeHtml(source.slice(lastIndex))
        return "<pre style=\"margin:0;font-family:'Consolas','Courier New',monospace;font-size:14px;line-height:1.35;color:" + shell.textPrimary + ";\">"
            + highlighted.replace(/\t/g, "    ")
            + "</pre>"
    }

    function appendConversationMessage(kind, label, text, pending) {
        conversationModel.append({
            kind: kind,
            label: label,
            text: text,
            pending: pending,
            durationText: pending ? qsTr("Working...") : ""
        })
        conversationList.positionViewAtEnd()
    }

    function copyConversationText(text) {
        if (!text || !text.length) {
            return
        }
        Runtime.copy_to_clipboard(text)
        shell.copyNoticeText = qsTr("Copied")
        copyNoticeTimer.restart()
    }

    function beginConversation(prompt, responseLabel, pendingText) {
        lastPromptText = prompt
        lastResponseLabel = responseLabel
        resultOutput.text = pendingText
        lastRunDurationText = qsTr("Working...")
        runStartMs = Date.now()
        appendConversationMessage("user", qsTr("You"), prompt, false)
        activeAssistantMessageIndex = conversationModel.count
        appendConversationMessage("assistant", responseLabel, pendingText, true)
    }

    function finishConversation(result, durationText) {
        resultOutput.text = result
        if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
            conversationModel.setProperty(activeAssistantMessageIndex, "text", result)
            conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
            conversationModel.setProperty(activeAssistantMessageIndex, "durationText", durationText || "")
        }
        conversationList.positionViewAtEnd()
        activeAssistantMessageIndex = -1
    }

    function sendAgentPrompt() {
        if (shell.agentRunning) {
            return
        }

        var prompt = promptEditor.text.trim()
        if (!prompt) {
            prompt = "hello"
        }
        promptEditor.text = ""

        shell.runClickSeq += 1
        shell.agentRunning = true
        shell.runtimeStatusText = qsTr("routing #") + shell.runClickSeq
        shell.beginConversation(prompt, qsTr("NeurX"), qsTr("Working on your request..."))
        shell.agentDetailsExpanded = false

        try {
            Runtime.run_agent_auto_async(prompt, shell.selectedFilePath || "", shell.runSteps)
        } catch (e) {
            resultOutput.text = qsTr("run_agent_failed: ") + e
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
                activeAssistantMessageIndex = -1
            }
            shell.runtimeStatusText = qsTr("failed #") + shell.runClickSeq
            shell.agentRunning = false
        } finally {
            // Completion comes from Runtime.agentRunFinished.
        }
    }

    function sendCodeSuggestion() {
        var prompt = promptEditor.text.trim()
        var filePath = shell.selectedFilePath || ""
        promptEditor.text = ""
        shell.runtimeStatusText = qsTr("suggesting")
        shell.beginConversation(prompt, qsTr("NeurX"), qsTr("Preparing code suggestion..."))
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.run_code_assistant(prompt, filePath)
            var elapsedSeconds = Math.max(1, Math.round((Date.now() - shell.runStartMs) / 1000))
            shell.lastRunDurationText = qsTr("Worked for %1s").arg(elapsedSeconds)
            shell.runtimeStatusText = qsTr("suggestion_done")
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", shell.lastRunDurationText)
            }
            activeAssistantMessageIndex = -1
        } catch (e) {
            resultOutput.text = qsTr("suggest_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.lastRunDurationText = qsTr("Working...")
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
            }
            activeAssistantMessageIndex = -1
        }
    }

    function resolvedAgentPrompt() {
        var prompt = promptEditor.text.trim()
        if (!prompt && shell.lastPromptText.length > 0) {
            prompt = shell.lastPromptText
        }
        if (!prompt) {
            prompt = "hello"
        }
        return prompt
    }

    function sendSkillSnapshot() {
        var prompt = resolvedAgentPrompt()
        shell.runtimeStatusText = qsTr("snapshot")
        shell.beginConversation(prompt, qsTr("Snapshot"), qsTr("Exporting skill snapshot..."))
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.export_agent_skill_snapshot(prompt, shell.runSteps)
            var elapsedSeconds = Math.max(1, Math.round((Date.now() - shell.runStartMs) / 1000))
            shell.lastRunDurationText = qsTr("Worked for %1s").arg(elapsedSeconds)
            shell.runtimeStatusText = qsTr("snapshot_done")
            shell.finishConversation(resultOutput.text, shell.lastRunDurationText)
        } catch (e) {
            resultOutput.text = qsTr("snapshot_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.finishConversation(resultOutput.text, qsTr("failed"))
        }
    }

    function sendTrajectoryExport() {
        var prompt = resolvedAgentPrompt()
        shell.runtimeStatusText = qsTr("trajectory")
        shell.beginConversation(prompt, qsTr("Trajectory"), qsTr("Exporting agent trajectory..."))
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.export_agent_trajectory(prompt, shell.runSteps)
            var elapsedSeconds = Math.max(1, Math.round((Date.now() - shell.runStartMs) / 1000))
            shell.lastRunDurationText = qsTr("Worked for %1s").arg(elapsedSeconds)
            shell.runtimeStatusText = qsTr("trajectory_done")
            shell.finishConversation(resultOutput.text, shell.lastRunDurationText)
        } catch (e) {
            resultOutput.text = qsTr("trajectory_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.finishConversation(resultOutput.text, qsTr("failed"))
        }
    }

    ListModel {
        id: conversationModel
    }

    ListModel {
        id: fileModel

        ListElement {
            label: "main.cpp"
            path: "app/app/main.cpp"
            kind: "C++"
            content: "#include <QGuiApplication>\n#include <QQmlApplicationEngine>\n#include <QQmlContext>\n#include <QUrl>\n\n#include \"bridge/AgentListModel.h\"\n#include \"bridge/LogModel.h\"\n#include \"bridge/neurx_bridge.h\"\n\nint main(int argc, char* argv[]) {\n    QGuiApplication app(argc, argv);\n    app.setApplicationName(\"Neurx App Shell\");\n\n    NeurxBridge bridge;\n    AgentListModel agent_model;\n    LogModel log_model;\n\n    QObject::connect(&bridge, &NeurxBridge::runtime_status_changed,\n        &agent_model, &AgentListModel::set_primary_agent_status);\n    QObject::connect(&bridge, &NeurxBridge::log_message,\n        &log_model, &LogModel::append);\n\n    QQmlApplicationEngine engine;\n    engine.rootContext()->setContextProperty(\"Runtime\", &bridge);\n    engine.rootContext()->setContextProperty(\"AgentModel\", &agent_model);\n    engine.rootContext()->setContextProperty(\"LogModel\", &log_model);\n\n    engine.load(QUrl(QStringLiteral(\"qrc:/neurx/app/qml/Main.qml\")));\n\n    if (engine.rootObjects().isEmpty()) {\n        return -1;\n    }\n\n    return app.exec();\n}"
        }

        ListElement {
            label: "Main.qml"
            path: "app/qml/Main.qml"
            kind: "QML"
            content: "import QtQuick\nimport QtQuick.Window\n\nWindow {\n    id: root\n    visible: true\n    visibility: Window.FullScreen\n    width: 1440\n    height: 900\n    minimumWidth: 1200\n    minimumHeight: 760\n    title: qsTr(\"Neurx Explorer / Editor / Agent\")\n    color: \"#111111\"\n\n    AppShell {\n        anchors.fill: parent\n    }\n}"
        }

        ListElement {
            label: "neurx_bridge.cpp"
            path: "app/bridge/neurx_bridge.cpp"
            kind: "C++"
            content: "#include \"neurx_bridge.h\"\n\n// Bridge runtime helpers live here."
        }

        ListElement {
            label: "AgentListModel.h"
            path: "app/bridge/AgentListModel.h"
            kind: "C++"
            content: "#pragma once\n\n#include <QAbstractListModel>\n#include <QString>\n#include <QVector>\n\nclass AgentListModel : public QAbstractListModel {\n    Q_OBJECT\n\npublic:\n    enum Roles {\n        IdRole = Qt::UserRole + 1,\n        NameRole,\n        StatusRole,\n    };\n\n    explicit AgentListModel(QObject* parent = nullptr);\n\n    int rowCount(const QModelIndex& parent = QModelIndex()) const override;\n    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;\n    QHash<int, QByteArray> roleNames() const override;\n\npublic slots:\n    void set_primary_agent_status(const QString& status, const QString& task);\n\nprivate:\n    struct AgentEntry {\n        QString id;\n        QString name;\n        QString status;\n    };\n\n    QVector<AgentEntry> entries_;\n};"
        }
    }

    function selectFile(index) {
        if (index < 0 || index >= fileModel.count) {
            return
        }

        selectedFileIndex = index
        var entry = fileModel.get(index)
        selectedFilePath = entry.path
        editorKind = entry.kind
        editorPlainText = entry.content
    }

    function clamp(value, minValue, maxValue) {
        if (maxValue < minValue) {
            return maxValue
        }
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function clampPaneWidths() {
        var available = Math.max(0, shell.width - (workspaceMargin * 2) - (paneHandleWidth * 2))
        var minEditor = Math.min(paneMinEditorWidth, available)
        var maxLeft = Math.max(paneMinExplorerWidth, available - paneMinAgentWidth - minEditor)
        explorerPaneWidth = clamp(explorerPaneWidth, paneMinExplorerWidth, maxLeft)

        var maxRight = Math.max(paneMinAgentWidth, available - explorerPaneWidth - minEditor)
        agentPaneWidth = clamp(agentPaneWidth, paneMinAgentWidth, maxRight)

        var editorWidth = available - explorerPaneWidth - agentPaneWidth
        if (editorWidth < paneMinEditorWidth) {
            var deficit = paneMinEditorWidth - editorWidth
            var reduceRight = Math.min(deficit, agentPaneWidth - paneMinAgentWidth)
            agentPaneWidth -= reduceRight
            deficit -= reduceRight

            if (deficit > 0) {
                var reduceLeft = Math.min(deficit, explorerPaneWidth - paneMinExplorerWidth)
                explorerPaneWidth -= reduceLeft
            }
        }
    }

    function parseResultField(text, key) {
        var lines = (text || "").split("\n")
        var prefix = key + "="
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf(prefix) === 0) {
                return lines[i].slice(prefix.length)
            }
        }
        return ""
    }

    function isFailureResult(text) {
        return text.indexOf("runtime_") === 0
            || text.indexOf("local_model_") === 0
            || text.indexOf("repo_not_found") === 0
    }

    Connections {
        target: Runtime

        function onAgentRunFinished(result) {
            var elapsedSeconds = Math.max(1, Math.round((Date.now() - shell.runStartMs) / 1000))
            shell.lastRunDurationText = qsTr("Worked for %1s").arg(elapsedSeconds)
            shell.finishConversation(result, shell.lastRunDurationText)
            shell.runtimeStatusText = isFailureResult(result) ? qsTr("failed #") + shell.runClickSeq : qsTr("done #") + shell.runClickSeq
            shell.agentRunning = false
        }
    }

    Component.onCompleted: {
        selectFile(selectedFileIndex)
        if (Runtime.checkpointModelChoices.length > 0) {
            Runtime.localModelName = Runtime.checkpointModelChoices[0].value
        }
        clampPaneWidths()
    }
    onWidthChanged: clampPaneWidths()

    Rectangle {
        anchors.fill: parent
        color: shell.bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: shell.explorerPaneWidth
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: qsTr("Explorer")
                        color: shell.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: qsTr("Project files")
                        color: shell.textMuted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: shell.panelAlt
                        border.color: shell.border

                        ListView {
                            id: fileView
                            anchors.fill: parent
                            anchors.margins: 10
                            model: fileModel
                            spacing: 8
                            clip: true
                            currentIndex: shell.selectedFileIndex

                            delegate: Rectangle {
                                required property int index
                                required property string label
                                required property string path
                                required property string kind

                                width: ListView.view.width
                                height: 72
                                radius: 12
                                color: ListView.isCurrentItem ? shell.selectionBg : shell.editorBg
                                border.color: ListView.isCurrentItem ? shell.accent : shell.border

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: shell.selectFile(index)
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: label
                                            color: shell.textPrimary
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 20
                                            radius: 8
                                            color: shell.panelAlt
                                            border.color: shell.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: kind
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                            }
                                        }
                                    }

                                    Text {
                                        text: path
                                        color: shell.textMuted
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }

                }
            }

            Rectangle {
                Layout.preferredWidth: shell.paneHandleWidth
                Layout.fillHeight: true
                color: shell.bg

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    radius: 5
                    color: shell.panelAlt
                    border.color: shell.border
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    property real dragStartX: 0
                    property int dragStartWidth: 0

                    onPressed: function(mouse) {
                        dragStartX = mouse.x
                        dragStartWidth = shell.explorerPaneWidth
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed) {
                            return
                        }
                        var delta = mouse.x - dragStartX
                        var available = Math.max(0, shell.width - (shell.workspaceMargin * 2) - (shell.paneHandleWidth * 2))
                        var maxLeft = Math.max(shell.paneMinExplorerWidth, available - shell.paneMinAgentWidth - shell.paneMinEditorWidth)
                        shell.explorerPaneWidth = shell.clamp(dragStartWidth + delta, shell.paneMinExplorerWidth, maxLeft)
                        shell.clampPaneWidths()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: Math.max(0, shell.width - (shell.workspaceMargin * 2) - shell.explorerPaneWidth - shell.agentPaneWidth - (shell.paneHandleWidth * 2))
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: qsTr("Editor")
                            color: shell.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: selectedFilePath
                            color: shell.textMuted
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 28
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Read only")
                                color: shell.textMuted
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: shell.editorBg
                        border.color: shell.border
                        clip: true

                        Rectangle {
                            id: editorGutter
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 60
                            color: shell.lineNumberBg
                            border.color: shell.lineNumberBorder

                            Text {
                                id: editorLineNumbers
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                y: 12 - editorFlick.contentY
                                textFormat: Text.RichText
                                text: shell.lineNumberHtml(shell.editorPlainText)
                            }
                        }

                        Flickable {
                            id: editorFlick
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.left: editorGutter.right
                            anchors.margins: 1
                            contentWidth: Math.max(width, editorText.paintedWidth + 32)
                            contentHeight: editorText.paintedHeight + 24
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: editorText
                                width: Math.max(editorFlick.width - 32, paintedWidth + 4)
                                height: paintedHeight + 2
                                x: 16
                                y: 12
                                text: shell.highlightCode(shell.editorPlainText, shell.editorKind)
                                textFormat: TextEdit.RichText
                                readOnly: true
                                wrapMode: TextEdit.NoWrap
                                selectByMouse: true
                                color: shell.textPrimary
                                selectionColor: shell.accent
                                selectedTextColor: shell.bg
                                font.family: "Consolas"
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Select a file from Explorer to load it into the editor.")
                                color: shell.textMuted
                                visible: shell.editorPlainText.length === 0
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: qsTr("Status")
                            color: shell.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Editing %1").arg(selectedFilePath)
                            color: shell.textPrimary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: shell.paneHandleWidth
                Layout.fillHeight: true
                color: shell.bg

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    radius: 5
                    color: shell.panelAlt
                    border.color: shell.border
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    property real dragStartX: 0
                    property int dragStartWidth: 0

                    onPressed: function(mouse) {
                        dragStartX = mouse.x
                        dragStartWidth = shell.agentPaneWidth
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed) {
                            return
                        }
                        var delta = mouse.x - dragStartX
                        var available = Math.max(0, shell.width - (shell.workspaceMargin * 2) - (shell.paneHandleWidth * 2))
                        var maxRight = Math.max(shell.paneMinAgentWidth, available - shell.explorerPaneWidth - shell.paneMinEditorWidth)
                        shell.agentPaneWidth = shell.clamp(dragStartWidth - delta, shell.paneMinAgentWidth, maxRight)
                        shell.clampPaneWidths()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: shell.agentPaneWidth
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 8
                    anchors.bottomMargin: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("Conversation")
                            color: shell.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 440
                        Layout.minimumHeight: 320
                        radius: 12
                        color: shell.editorBg
                        border.color: shell.border

                        Timer {
                            id: copyNoticeTimer
                            interval: 1200
                            repeat: false
                            onTriggered: shell.copyNoticeText = ""
                        }

                        ListView {
                            id: conversationList
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            spacing: 12
                            model: conversationModel
                            boundsBehavior: Flickable.StopAtBounds
                            onContentHeightChanged: positionViewAtEnd()

                            delegate: Item {
                                width: conversationList.width
                                height: bubbleRect.height
                                property bool hovered: false

                                Rectangle {
                                    id: bubbleRect
                                    width: Math.min(parent.width * 0.90, bubbleColumn.implicitWidth + 28)
                                    height: bubbleColumn.implicitHeight + 20
                                    x: model.kind === "user" ? parent.width - width : 0
                                    radius: 12
                                    color: model.kind === "user" ? shell.userBubble : shell.agentBubble
                                    border.color: model.kind === "user" ? Qt.rgba(1, 1, 1, 0.06) : shell.border

                                    Column {
                                        id: bubbleColumn
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        RowLayout {
                                            spacing: 8
                                            Layout.fillWidth: true

                                            Rectangle {
                                                visible: model.kind !== "user"
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: shell.accent

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: qsTr("C")
                                                    color: shell.bg
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }

                                            Text {
                                                text: model.label
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Text {
                                                visible: model.kind !== "user"
                                                text: model.durationText
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            width: Math.max(120, bubbleRect.width - 20)
                                            text: model.text
                                            wrapMode: Text.Wrap
                                            color: shell.textPrimary
                                            font.pixelSize: 13
                                        }
                                    }

                                    ToolButton {
                                        enabled: !model.pending && model.text.length > 0
                                        visible: hovered
                                        opacity: hovered ? 1.0 : 0.0
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 6
                                        anchors.rightMargin: 6
                                        width: 24
                                        height: 24
                                        padding: 0
                                        text: ""
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Copy")
                                        contentItem: Text {
                                            text: "⧉"
                                            color: enabled ? shell.textPrimary : shell.textMuted
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 14
                                        }
                                        onClicked: shell.copyConversationText(model.text)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: bubbleRect
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: hovered = true
                                    onExited: hovered = false
                                }
                            }
                        }

                        Rectangle {
                            visible: shell.copyNoticeText.length > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            radius: 999
                            color: Qt.rgba(0.09, 0.12, 0.11, 0.92)
                            border.color: Qt.rgba(0.39, 0.67, 0.54, 0.55)
                            z: 10

                            Text {
                                anchors.margins: 6
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: shell.textPrimary
                                font.pixelSize: 10
                                text: shell.copyNoticeText
                            }
                        }

                        TextEdit {
                            id: resultOutput
                            visible: false
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            text: qsTr("Run the agent to see output here.")
                            font.pixelSize: 12
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 12
                    }

                    Text {
                        text: qsTr("Send")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        Layout.maximumHeight: 88
                        radius: 12
                        color: shell.editorBg
                        border.color: shell.border

                        TextEdit {
                            id: promptEditor
                            anchors.fill: parent
                            anchors.margins: 10
                            text: ""
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            selectionColor: shell.accent
                            selectedTextColor: shell.bg
                            font.pixelSize: 13
                            focus: true
                            Keys.priority: Keys.BeforeItem

                            Keys.onPressed: function(event) {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                    event.accepted = true
                                    shell.sendAgentPrompt()
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            text: qsTr("Ask the agent to inspect files or summarize state")
                            color: shell.textMuted
                            visible: promptEditor.text.length === 0 && !promptEditor.activeFocus
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 116
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.agentRunning ? shell.panelHover : shell.accent

                            Text {
                                anchors.centerIn: parent
                                text: shell.agentRunning ? qsTr("Running...") : qsTr("Run")
                                color: shell.bg
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !shell.agentRunning
                                onClicked: shell.sendAgentPrompt()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 132
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Suggest")
                                color: shell.textPrimary
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: shell.sendCodeSuggestion()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 138
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Snapshot")
                                color: shell.textPrimary
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: shell.sendSkillSnapshot()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 142
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Trajectory")
                                color: shell.textPrimary
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: shell.sendTrajectoryExport()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                Text {
                                    text: qsTr("Steps")
                                    color: shell.textPrimary
                                    font.bold: true
                                    font.pixelSize: 11
                                }

                                SpinBox {
                                    id: stepsPicker
                                    from: 1
                                    to: 64
                                    value: shell.runSteps
                                    editable: true
                                    onValueModified: shell.runSteps = value
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 124
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Refresh")
                                color: shell.textPrimary
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: shell.runtimeStatusText = Runtime.ping()
                            }
                        }
                    }

                }
            }
        }
    }
}
