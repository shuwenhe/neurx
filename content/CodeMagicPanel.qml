import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

Item {
    id: root

    required property var agent

    readonly property var result: agent.codeMagicResult || {}
    readonly property string targetLabel: agent.codeMagicTargetLabel || (
        agent.currentSelectionText && agent.currentSelectionText.length > 0
            ? (agent.currentSelectionPath || "Selected text")
            : (agent.currentFilePath || "No file selected")
    )
    readonly property bool hasSelection: agent.currentSelectionText && agent.currentSelectionText.length > 0

    function asArray(value) {
        return Array.isArray(value) ? value : []
    }

    function severityLabel(value) {
        switch (value) {
        case 0: return "Info"
        case 1: return "Warning"
        case 2: return "Error"
        case 3: return "Critical"
        default: return "Unknown"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.radius + 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headerColumn.implicitHeight + 18
                color: Theme.surfaceAlt
                radius: Theme.radius + 2
                border.color: Theme.border

                ColumnLayout {
                    id: headerColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: "CodeMagic"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontMd
                                font.bold: true
                            }

                            Label {
                                text: "Target: " + root.targetLabel
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: root.result.error ? Theme.error : Theme.success
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            text: "Analyze"
                            enabled: !!agent.currentFilePath || root.hasSelection
                            onClicked: agent.analyzeCurrentFileWithCodeMagic()
                        }

                        Button {
                            text: "Review"
                            enabled: !!agent.currentFilePath || root.hasSelection
                            onClicked: agent.reviewCurrentFileWithCodeMagic()
                        }

                        Button {
                            text: "Explain"
                            enabled: !!agent.currentFilePath || root.hasSelection
                            onClicked: agent.explainCurrentFileWithCodeMagic()
                        }

                        Item { Layout.fillWidth: true }

                        Label {
                            text: root.hasSelection ? "Using selected text" : "Using current file"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontXs
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.hasSelection
                        color: Theme.surface
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: selectionColumn.implicitHeight + 18

                        ColumnLayout {
                            id: selectionColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Label {
                                text: "Selected text"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                            }

                            TextArea {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 110
                                text: agent.currentSelectionText || ""
                                readOnly: true
                                wrapMode: TextArea.NoWrap
                                color: Theme.textPrimary
                                font: Theme.monoFont
                                background: Rectangle {
                                    color: Theme.bg
                                    radius: Theme.radius
                                    border.color: Theme.border
                                }
                            }
                        }
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: root.width - 24
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        visible: !!root.result.error
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.error
                        implicitHeight: errorColumn.implicitHeight + 18

                        ColumnLayout {
                            id: errorColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Label {
                                text: "Error"
                                color: Theme.error
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }

                            Label {
                                Layout.fillWidth: true
                                text: root.result.error || ""
                                color: Theme.textPrimary
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: summaryColumn.implicitHeight + 18

                        ColumnLayout {
                            id: summaryColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Label {
                                text: "Summary"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }

                            GridLayout {
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 6

                                Label { text: "Kind"; color: Theme.textMuted }
                                Label { text: root.result.kind || "n/a"; color: Theme.textPrimary }

                                Label { text: "Target"; color: Theme.textMuted }
                                Label { text: root.result.targetLabel || root.targetLabel; color: Theme.textPrimary; elide: Text.ElideRight }

                                Label { text: "Result Id"; color: Theme.textMuted }
                                Label { text: root.result.analysisId || root.result.reviewId || root.result.explanationId || "n/a"; color: Theme.textPrimary; elide: Text.ElideRight }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.result.kind === "analysis"
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: analysisColumn.implicitHeight + 18

                        ColumnLayout {
                            id: analysisColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Label {
                                text: "Analysis"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }

                            GridLayout {
                                columns: 4
                                columnSpacing: 12
                                rowSpacing: 6

                                Label { text: "Lines"; color: Theme.textMuted }
                                Label { text: String(root.result.lineCount || 0); color: Theme.textPrimary }
                                Label { text: "Complexity"; color: Theme.textMuted }
                                Label { text: String(root.result.complexity || 0); color: Theme.textPrimary }

                                Label { text: "Quality"; color: Theme.textMuted }
                                Label { text: Number(root.result.quality || 0).toFixed(1); color: Theme.textPrimary }
                                Label { text: "Security"; color: Theme.textMuted }
                                Label { text: Number(root.result.security || 0).toFixed(1); color: Theme.textPrimary }
                            }

                            Label {
                                text: "Issues"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                                visible: root.asArray(root.result.issues).length > 0
                            }

                            Repeater {
                                model: root.asArray(root.result.issues)

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    color: Theme.surface
                                    radius: Theme.radius
                                    border.color: Theme.border
                                    implicitHeight: issueColumn.implicitHeight + 18

                                    ColumnLayout {
                                        id: issueColumn
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Label {
                                                text: root.severityLabel(modelData.severity) + " · " + (modelData.type || "issue")
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontXs
                                                font.bold: true
                                            }
                                            Item { Layout.fillWidth: true }
                                            Label {
                                                text: modelData.lineNumber > 0 ? ("Ln " + modelData.lineNumber) : ""
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontXs
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.message || ""
                                            color: Theme.textPrimary
                                            wrapMode: Text.WordWrap
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            visible: !!modelData.suggestedFix
                                            text: "Fix: " + modelData.suggestedFix
                                            color: Theme.textMuted
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.result.kind === "review"
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: reviewColumn.implicitHeight + 18

                        ColumnLayout {
                            id: reviewColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Label {
                                text: "Review"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }

                            Label {
                                text: "Score: " + Number(root.result.overallScore || 0).toFixed(1)
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontMd
                                font.bold: true
                            }

                            Label {
                                text: "Issues"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                                visible: root.asArray(root.result.issues).length > 0
                            }

                            Repeater {
                                model: root.asArray(root.result.issues)

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    color: Theme.surface
                                    radius: Theme.radius
                                    border.color: Theme.border
                                    implicitHeight: issueColumn.implicitHeight + 18

                                    ColumnLayout {
                                        id: issueColumn
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Label {
                                                text: root.severityLabel(modelData.severity)
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontXs
                                                font.bold: true
                                            }
                                            Item { Layout.fillWidth: true }
                                            Label {
                                                text: modelData.rule || ""
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontXs
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.message || ""
                                            color: Theme.textPrimary
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }

                            Label {
                                text: "Suggestions"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                                visible: root.asArray(root.result.suggestions).length > 0
                            }

                            Repeater {
                                model: root.asArray(root.result.suggestions)
                                delegate: Label {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "• " + modelData
                                    color: Theme.textPrimary
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Label {
                                text: "Praise"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                                visible: root.asArray(root.result.praise).length > 0
                            }

                            Repeater {
                                model: root.asArray(root.result.praise)
                                delegate: Label {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "• " + modelData
                                    color: Theme.textMuted
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.result.kind === "explanation"
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: explanationColumn.implicitHeight + 18

                        ColumnLayout {
                            id: explanationColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Label {
                                text: "Explanation"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }

                            Label {
                                Layout.fillWidth: true
                                text: root.result.summary || ""
                                color: Theme.textPrimary
                                wrapMode: Text.WordWrap
                                visible: !!root.result.summary
                            }

                            Label {
                                Layout.fillWidth: true
                                text: root.result.detailedExplanation || ""
                                color: Theme.textMuted
                                wrapMode: Text.WordWrap
                                visible: !!root.result.detailedExplanation
                            }

                            Label {
                                text: "Key components"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                                visible: root.asArray(root.result.keyComponents).length > 0
                            }

                            Repeater {
                                model: root.asArray(root.result.keyComponents)
                                delegate: Label {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "• " + modelData
                                    color: Theme.textPrimary
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Label {
                                text: "Suggested improvements"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontXs
                                font.bold: true
                                visible: root.asArray(root.result.suggestedImprovements).length > 0
                            }

                            Repeater {
                                model: root.asArray(root.result.suggestedImprovements)
                                delegate: Label {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "• " + modelData
                                    color: Theme.textMuted
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: Theme.border
                        implicitHeight: rawColumn.implicitHeight + 18

                        ColumnLayout {
                            id: rawColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Label {
                                text: "Raw result"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSm
                                font.bold: true
                            }

                            TextArea {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 280
                                text: JSON.stringify(root.result || {}, null, 2)
                                readOnly: true
                                wrapMode: TextArea.NoWrap
                                color: Theme.textPrimary
                                font: Theme.monoFont
                                background: Rectangle {
                                    color: Theme.bg
                                    radius: Theme.radius
                                    border.color: Theme.border
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
