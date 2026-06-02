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
    implicitWidth: 400

    signal approved(string callId)
    signal rejected(string callId)

    property string pendingCallId
    property string toolName
    property string toolSummary
    property string approvalRisk: "medium"

    function show(callId, name, summary, riskLevel) {
        pendingCallId = callId
        toolName      = name
        toolSummary   = summary
        approvalRisk  = riskLevel || "medium"
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
            height: 36
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border

            Label {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: root.toolName + "  —  " + root.toolSummary
                color: Theme.textPrimary
                font: Theme.monoFont
                elide: Text.ElideRight
                width: parent.width - 24
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
