import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import NeurXCode

// ── SettingsPanel ─────────────────────────────────────────────────────────────
//  Side drawer: API key management, safety options, system prompt editor.

Item {
    id: root
    required property var agent

    Rectangle {
        anchors.fill: parent
        color: Theme.surface

        ScrollView {
            anchors.fill: parent
            clip: true

            ColumnLayout {
                width: root.width - 32
                x: 16
                y: 20
                spacing: 16

                Label {
                    text: "Settings"
                    font.pixelSize: Theme.fontLg; font.bold: true
                    color: Theme.textPrimary
                }

                // ── API Keys ──────────────────────────────────────────────
                GroupBox {
                    Layout.fillWidth: true
                    title: "API Keys"
                    background: Rectangle { color: Theme.surfaceAlt; radius: Theme.radius }

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        ColumnLayout {
                            spacing: 4
                            Label {
                                text: "Anthropic API key"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: root.agent.anthropicApiKey
                                placeholderText: "sk-ant-..."
                                echoMode: TextInput.Password
                                color: Theme.textPrimary
                                font: Theme.monoFont
                                background: Rectangle {
                                    color: Theme.surface
                                    border.color: Theme.border
                                    radius: Theme.radius
                                }
                                onEditingFinished: root.agent.anthropicApiKey = text
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Label {
                                text: "OpenAI-compatible API key"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: root.agent.openaiApiKey
                                placeholderText: "sk-..."
                                echoMode: TextInput.Password
                                color: Theme.textPrimary
                                font: Theme.monoFont
                                background: Rectangle {
                                    color: Theme.surface
                                    border.color: Theme.border
                                    radius: Theme.radius
                                }
                                onEditingFinished: root.agent.openaiApiKey = text
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Label {
                                text: "Anthropic endpoint"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: root.agent.anthropicEndpoint
                                placeholderText: "https://api.anthropic.com/v1/messages"
                                color: Theme.textPrimary
                                font: Theme.monoFont
                                background: Rectangle {
                                    color: Theme.surface
                                    border.color: Theme.border
                                    radius: Theme.radius
                                }
                                onEditingFinished: root.agent.anthropicEndpoint = text
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Label {
                                text: "OpenAI-compatible endpoint"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: root.agent.openaiEndpoint
                                placeholderText: "https://api.openai.com/v1/chat/completions"
                                color: Theme.textPrimary
                                font: Theme.monoFont
                                background: Rectangle {
                                    color: Theme.surface
                                    border.color: Theme.border
                                    radius: Theme.radius
                                }
                                onEditingFinished: root.agent.openaiEndpoint = text
                            }
                        }
                    }
                }

                // ── Safety ────────────────────────────────────────────────
                GroupBox {
                    Layout.fillWidth: true
                    title: "Safety"
                    background: Rectangle { color: Theme.surfaceAlt; radius: Theme.radius }

                    RowLayout {
                        width: parent.width
                        Label {
                            text: "Auto-approve tool calls"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontMd
                            Layout.fillWidth: true
                        }
                        Switch {
                            checked: root.agent.autoApproveTools
                            onToggled: root.agent.autoApproveTools = checked
                        }
                    }
                }

                // ── System Prompt ─────────────────────────────────────────
                GroupBox {
                    Layout.fillWidth: true
                    title: "System Prompt"
                    background: Rectangle { color: Theme.surfaceAlt; radius: Theme.radius }

                    ScrollView {
                        width: parent.width
                        height: 160
                        clip: true

                        TextArea {
                            width: parent.width
                            wrapMode: TextArea.Wrap
                            color: Theme.textPrimary
                            font: Theme.monoFont
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.border
                                radius: Theme.radius
                            }
                            placeholderText: "Custom system prompt…"
                        }
                    }
                }
            }
        }
    }
}
