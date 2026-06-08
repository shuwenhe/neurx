import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

// ── ToolApprovalDialog ────────────────────────────────────────────────────────
//  Modal dialog shown when the agent wants to execute a tool and
//  autoApproveTools is false.

Popup {
    id: root

    modal: true
    closePolicy: Popup.NoAutoClose
    padding: 20
    implicitWidth: isPatchPreview ? 860 : 400

    signal approved(string callId)
    signal rejected(string callId)

    property string pendingCallId
    property string toolName
    property string toolSummary
    property string approvalRisk: "medium"
    property string approvalReason: ""
    property bool isPatchPreview: false
    property string patchPreviewText: ""
    property var touchedFiles: []
    property string patchOperation: ""
    property bool hasVisualDiff: false
    property string diffFileName: ""
    property string diffOriginalText: ""
    property string diffModifiedText: ""

    function show(callId, name, summary, riskLevel, reason) {
        pendingCallId = callId
        toolName      = name
        toolSummary   = summary
        approvalRisk  = riskLevel || "medium"
        approvalReason = reason || ""
        const preview = agent.toolApprovalPreview(callId)
        isPatchPreview = !!preview && !!preview.isPatch
        patchPreviewText = preview && preview.patchText ? preview.patchText : ""
        touchedFiles = preview && preview.touchedFiles ? preview.touchedFiles : []
        patchOperation = preview && preview.operation ? preview.operation : ""
        hasVisualDiff = !!preview && !!preview.hasVisualDiff
        diffFileName = preview && preview.previewFile ? preview.previewFile : ""
        diffOriginalText = preview && preview.originalText ? preview.originalText : ""
        diffModifiedText = preview && preview.modifiedText ? preview.modifiedText : ""
        open()
    }

    background: Rectangle {
        color: Theme.surfaceAlt
        radius: Theme.radius
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0

        Label {
            text: "Tool Execution Request"
            font.pixelSize: Theme.fontMd
            font.bold: true
            color: Theme.textPrimary
        }

        Item { height: 12 }

        Label {
            text: "The agent wants to run:"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 24
            radius: Theme.radius
            color: root.approvalRisk === "critical" ? "#6b1f1f"
                : root.approvalRisk === "high" ? Theme.error
                : root.approvalRisk === "medium" ? Theme.warning
                : Theme.success

            Label {
                anchors.centerIn: parent
                text: root.approvalRisk === "critical" ? "Critical risk"
                    : root.approvalRisk === "high" ? "High risk"
                    : root.approvalRisk === "medium" ? "Medium risk"
                    : "Low risk"
                color: "white"
                font.pixelSize: Theme.fontXs
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: contentColumn.implicitHeight + 24
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border

            Column {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Label {
                    width: parent.width
                    text: root.toolName + "  —  " + root.toolSummary
                    color: Theme.textPrimary
                    font: Theme.monoFont
                    elide: Text.ElideRight
                }

                Label {
                    id: reasonLabel
                    width: parent.width
                    visible: root.approvalReason.length > 0
                    text: root.approvalReason
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                    wrapMode: Text.Wrap
                }
            }
        }

        Item { height: isPatchPreview ? 12 : 0 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: isPatchPreview

            Label {
                text: patchOperation.length > 0 ? "Patch Preview (" + patchOperation + ")" : "Patch Preview"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
            }

            Label {
                Layout.fillWidth: true
                visible: touchedFiles && touchedFiles.length > 0
                text: "Touched files: " + touchedFiles.join(", ")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontXs
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                radius: Theme.radius
                color: "#0f141b"
                border.color: Theme.border

                DiffView {
                    anchors.fill: parent
                    visible: hasVisualDiff
                    originalText: diffOriginalText
                    modifiedText: diffModifiedText
                    fileName: diffFileName
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    visible: !hasVisualDiff

                    TextArea {
                        text: patchPreviewText
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextArea.NoWrap
                        color: "#d7e3f4"
                        font: Theme.monoFont
                        background: null
                    }
                }
            }
        }

        Item { height: 16 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Button {
                text: "Reject"
                onClicked: { root.rejected(root.pendingCallId); root.close() }
                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.error
                }
                contentItem: Label { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Button {
                text: "Approve"
                onClicked: { root.approved(root.pendingCallId); root.close() }
                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.success
                }
                contentItem: Label { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
}
