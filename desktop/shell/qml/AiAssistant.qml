import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NiraOS

Item {
    id: root
    width: 320
    property string aiState: "Idle"
    property string streamingText: ""

    x: visible ? parent.width - width : parent.width
    Behavior on x { NumberAnimation { duration: NiraTheme.animNormal; easing.type: Easing.OutQuint } }

    onVisibleChanged: {
        if (typeof aiClient !== "undefined") {
            if (visible) {
                aiClient.panelOpen = true
                aiClient.shellInactivityTimer.stop()
                if (aiClient.aiState === "unloaded" && aiClient.aiMode === "ondemand") {
                    root.aiState = "Loading…"
                }
            } else {
                aiClient.panelOpen = false
                aiClient.shellInactivityTimer.start(300000)
            }
        }
    }

    onStreamingTextChanged: Qt.callLater(function() { messagesView.positionViewAtEnd() })

    ListModel {
        id: chatModel
        ListElement { role: "assistant"; text: "I'm ready. How can I help you manage the system?" }
    }

    function appendMessage(role, text) {
        chatModel.append({ role: role, text: text })
    }

    function sendPrompt(text) {
        if (text === "") return
        // Always show the user's message and reset the streaming buffer, even
        // when the model is unloaded. The previous early-return path sent the
        // prompt but dropped the user's message from the chat and left
        // streamingText pointing at the previous reply, so the next tokens
        // appended to stale text.
        appendMessage("user", text)
        streamingText = ""
        if (typeof aiClient !== "undefined" && aiClient.aiState === "unloaded") {
            root.aiState = "Loading…"
            aiClient.streamGenerate(text, 0.7, 256)
            return
        }
        root.aiState = "Thinking"
        if (typeof aiClient !== "undefined")
            aiClient.streamGenerate(text, 0.7, 256)
        else {
            appendMessage("assistant", "_[AI disconnected]_")
            root.aiState = "Idle"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: NiraTheme.glassBackground
        border.color: NiraTheme.glassBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: NiraTheme.paddingSmall
            spacing: NiraTheme.paddingSmall

            // ── Header ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: NiraTheme.paddingSmall
                Layout.topMargin: NiraTheme.paddingSmall

                Image {
                    source: "qrc:/nira/nira/assistant-logo.svg"
                    sourceSize: Qt.size(28, 28)
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Nira Intelligence"
                        color: NiraTheme.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: {
                            if (typeof aiClient === "undefined") return "No model loaded"
                            if (aiClient.aiState === "unloaded") return "AI unloaded · " + aiClient.aiMode
                            return aiClient.activeModel || "No model loaded"
                        }
                        color: NiraTheme.textSecondary
                        font.pixelSize: 10
                        font.italic: true
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: {
                        if (typeof aiClient !== "undefined" && aiClient.aiState === "loading") return "#ffcc00"
                        if (typeof aiClient !== "undefined" && aiClient.aiState === "unloaded") return "#888888"
                        if (aiClient.isLoading) return "#ffcc00"
                        if (root.aiState === "Thinking" || root.aiState === "Executing" || root.aiState === "Loading…") return NiraTheme.accentPrimary
                        return "#00cc66"
                    }
                }

                Text {
                    text: root.aiState
                    color: NiraTheme.textSecondary
                    font.pixelSize: 10
                }

                Button {
                    id: closeBtn
                    text: "✕"
                    onClicked: root.visible = false
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    background: Rectangle {
                        color: closeBtn.hovered ? NiraTheme.glassHighlight : "transparent"
                        radius: NiraTheme.radiusSmall
                    }
                    contentItem: Text {
                        text: closeBtn.text
                        color: NiraTheme.textSecondary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 1
                color: NiraTheme.glassBorder
            }

            // ── Quick Actions ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.aiState === "Idle"

                Repeater {
                    model: ["Explain this window", "Find my files", "System status"]

                    Rectangle {
                        height: 24
                        radius: 4
                        color: ma.containsMouse ? NiraTheme.glassHighlight : "transparent"
                        border.color: NiraTheme.glassBorder
                        border.width: 1
                        Layout.fillWidth: true

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: NiraTheme.textSecondary
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.sendPrompt(modelData)
                        }
                    }
                }
            }

            // ── Chat messages ────────────────────────────────────────────
            ListView {
                id: messagesView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: chatModel
                spacing: 4
                boundsBehavior: Flickable.StopAtEnd
                onCountChanged: Qt.callLater(function() { messagesView.positionViewAtEnd() })

                delegate: Item {
                    width: messagesView.width
                    height: msgText.height + 4

                    Text {
                        id: msgText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: (role === "user" ? "**You:** " : "**Nira:** ") + model.text
                        textFormat: Text.MarkdownText
                        color: NiraTheme.textPrimary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                footer: Item {
                    width: messagesView.width
                    height: streamingText.length > 0 ? streamingLabel.height + 4 : 0

                    Text {
                        id: streamingLabel
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: "**Nira:** " + root.streamingText
                        textFormat: Text.MarkdownText
                        color: NiraTheme.textPrimary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        visible: streamingText.length > 0
                    }
                }
            }

            // ── VRAM stats ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "VRAM: " + aiClient.vramUsageMb.toFixed(1) + " MB"
                    color: NiraTheme.textMuted
                    font.pixelSize: 9
                }
                Text {
                    text: "Model: " + (aiClient.activeModel || "none")
                    color: NiraTheme.textMuted
                    font.pixelSize: 9
                }
                Item { Layout.fillWidth: true }
            }

            // ── Input row ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                TextField {
                    id: promptInput
                    Layout.fillWidth: true
                    placeholderText: "Ask Nira…"
                    color: NiraTheme.textPrimary
                    font.pixelSize: 12
                    padding: 8
                    background: Rectangle {
                        color: NiraTheme.background
                        opacity: 0.5
                        radius: NiraTheme.radiusMedium
                        border.color: promptInput.activeFocus ? NiraTheme.accentAi : NiraTheme.glassBorder
                        Behavior on border.color { ColorAnimation { duration: NiraTheme.animFast } }
                    }
                    onAccepted: submitBtn.clicked()
                }

                Button {
                    id: submitBtn
                    text: "Send"
                    onClicked: {
                        root.sendPrompt(promptInput.text)
                        promptInput.text = ""
                    }
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 28
                    background: Rectangle {
                        color: submitBtn.hovered ? NiraTheme.accentSecondary : "transparent"
                        radius: NiraTheme.radiusMedium
                        border.color: NiraTheme.accentSecondary
                        border.width: 1
                    }
                    contentItem: Text {
                        text: submitBtn.text
                        color: NiraTheme.textPrimary
                        font.bold: true
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // ── Real-time token receiver ────────────────────────────────────────
    Connections {
        target: typeof aiClient !== "undefined" ? aiClient : null
        function onTokenReceived(token) {
            if (root.aiState === "Thinking") root.aiState = "Executing"
            root.streamingText += token
        }
        function onGenerationFinished() {
            appendMessage("assistant", root.streamingText)
            root.streamingText = ""
            root.aiState = "Idle"
        }
        function onErrorOccurred(msg) {
            appendMessage("assistant", "_Error: " + msg + "_")
            root.streamingText = ""
            root.aiState = "Idle"
        }
        function onStatusChanged() {
            if (aiClient.aiState === "ready" && root.aiState === "Loading…") {
                root.aiState = "Idle"
            }
        }
        function onUnloadSuggested() {
            // Shell-side suggests unloading — the daemon will handle auto-unload
            // via its own inactivity timer, but we surface this to the user
            appendMessage("assistant", "_AI has been idle. Model will unload to free memory._")
        }
    }
}
