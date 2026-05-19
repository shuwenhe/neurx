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
            content: "import QtQuick\nimport QtQuick.Window\n\nWindow {\n    id: root\n    visible: true\n    visibility: Window.FullScreen\n    width: 960\n    height: 640\n    minimumWidth: 760\n    minimumHeight: 520\n    title: qsTr(\"Neurx Explorer / Editor / Agent\")\n    color: \"#111111\"\n\n    AppShell {\n        anchors.fill: parent\n    }\n}"
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
        editorText.text = entry.content
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

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 94
            radius: 16
            color: shell.surface
            border.color: shell.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                Text {
                    text: qsTr("Explorer / Editor / Agent")
                    color: shell.textPrimary
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    text: qsTr("Left: project explorer. Middle: code editor. Right: live agent workspace.")
                    color: shell.textMuted
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 54
            radius: 14
            color: shell.surface
            border.color: shell.border

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Text {
                    text: qsTr("Runtime")
                    color: shell.textPrimary
                    font.bold: true
                }

                Text {
                    id: runtimeStatus
                    Layout.fillWidth: true
                    text: Runtime.ping()
                    color: shell.textMuted
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.preferredWidth: 168
                    Layout.preferredHeight: 28
                    radius: 10
                    color: shell.panelAlt
                    border.color: shell.border

                    Text {
                        anchors.centerIn: parent
                        text: Runtime.localModelEnabled ? qsTr("Local model on") : qsTr("Local model off")
                        color: shell.textPrimary
                    }
                }
            }
        }

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

                    onPressed: {
                        dragStartX = mouse.x
                        dragStartWidth = shell.explorerPaneWidth
                    }

                    onPositionChanged: {
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

                        Flickable {
                            id: editorFlick
                            anchors.fill: parent
                            anchors.margins: 1
                            contentWidth: width
                            contentHeight: editorText.paintedHeight + 24
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: editorText
                                width: editorFlick.width - 32
                                height: paintedHeight + 2
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.top: parent.top
                                anchors.topMargin: 12
                                text: ""
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
                                visible: editorText.text.length === 0
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

                    onPressed: {
                        dragStartX = mouse.x
                        dragStartWidth = shell.agentPaneWidth
                    }

                    onPositionChanged: {
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
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: qsTr("Agent")
                        color: shell.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: qsTr("Live runtime and agent control")
                        color: shell.textMuted
                    }

                    Text {
                        text: qsTr("Model")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        radius: 14
                        color: shell.panelAlt
                        border.color: shell.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                id: modelPicker
                                Layout.fillWidth: true
                                text: Runtime.checkpointModelChoices.length > 0
                                    ? Runtime.checkpointModelChoices[0].text
                                    : qsTr("No NeurX checkpoints were found under the configured run directory.")
                                color: shell.textPrimary
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideMiddle
                                wrapMode: Text.NoWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Runtime.localModelSummary
                                color: shell.textMuted
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Runtime.checkpointModelChoices.length > 0
                                    ? qsTr("Latest NeurX checkpoint only. The active agent auto-switches to it.")
                                    : qsTr("No NeurX checkpoints were found under the configured run directory.")
                                color: shell.textMuted
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        radius: 14
                        color: shell.panelAlt
                        border.color: shell.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            Text {
                                text: qsTr("Active agents")
                                color: shell.textPrimary
                                font.bold: true
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: AgentModel
                                spacing: 8
                                clip: true

                                delegate: Rectangle {
                                    required property string agentId
                                    required property string name
                                    required property string status

                                    width: ListView.view.width
                                    height: 68
                                    radius: 12
                                    color: shell.editorBg
                                    border.color: shell.border

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        Text {
                                            text: name
                                            color: shell.textPrimary
                                            font.bold: true
                                        }

                                        Text {
                                            text: agentId
                                            color: shell.textMuted
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            text: status
                                            color: shell.accent
                                            elide: Text.ElideRight
                                            width: parent.width
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: qsTr("Prompt")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 132
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
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 36
                            radius: 10
                            color: shell.agentRunning ? shell.panelHover : shell.accent

                            Text {
                                anchors.centerIn: parent
                                text: shell.agentRunning ? qsTr("Running...") : qsTr("Run Agent")
                                color: shell.bg
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !shell.agentRunning
                                onClicked: {
                                    if (shell.agentRunning) {
                                        return
                                    }
                                    var prompt = promptEditor.text.trim()
                                    if (!prompt) {
                                        prompt = "hello"
                                    }
                                    shell.agentRunning = true
                                    runtimeStatus.text = qsTr("running")
                                    try {
                                        resultOutput.text = Runtime.run_agent(prompt, shell.runSteps)
                                        runtimeStatus.text = qsTr("done")
                                    } catch (e) {
                                        resultOutput.text = qsTr("run_agent_failed: ") + e
                                        runtimeStatus.text = qsTr("failed")
                                    } finally {
                                        shell.agentRunning = false
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 36
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: qsTr("Steps")
                                    color: shell.textPrimary
                                    font.bold: true
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
                            Layout.preferredWidth: 136
                            Layout.preferredHeight: 36
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Refresh Status")
                                color: shell.textPrimary
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: runtimeStatus.text = Runtime.ping()
                            }
                        }
                    }

                    Text {
                        text: qsTr("Result")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        radius: 12
                        color: shell.editorBg
                        border.color: shell.border

                        TextEdit {
                            id: resultOutput
                            anchors.fill: parent
                            anchors.margins: 10
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            text: qsTr("Run the agent to see output here.")
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: 12
                        color: shell.panelAlt
                        border.color: shell.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 2

                            Text {
                                text: qsTr("Checkpoint file: ") + (parseResultField(resultOutput.text, "checkpoint_file") || qsTr("(none)"))
                                color: shell.textMuted
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: qsTr("Checkpoint step: ") + (parseResultField(resultOutput.text, "checkpoint_step") || qsTr("(n/a)"))
                                color: shell.textMuted
                                font.pixelSize: 11
                            }
                        }
                    }

                    Text {
                        text: qsTr("Runtime Log")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: shell.panelAlt
                        border.color: shell.border

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 12
                            model: LogModel
                            spacing: 8
                            clip: true

                            delegate: Row {
                                required property string time
                                required property string level
                                required property string tag
                                required property string message

                                width: ListView.view.width
                                spacing: 8

                                Text {
                                    text: time
                                    color: shell.textMuted
                                    width: 64
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: level
                                    color: level === "error" ? "#ff6b6b" : (level === "warning" ? "#ffb347" : shell.accent)
                                    width: 56
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: tag
                                    color: shell.textPrimary
                                    width: 64
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: message
                                    color: shell.textMuted
                                    width: Math.max(0, parent.width - 220)
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
