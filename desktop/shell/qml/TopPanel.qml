import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import NiraOS

// NiraOS Top Panel.
//
// Layout: [Logo + Start button | Browser] [Taskbar] [Clock] [Workspaces]
//         [Volume | Battery | Network | Notifications | AI]
//
// The panel uses the existing compositor D-Bus taskbar model and the AI
// client, plus the new status helpers (PowerStatus, VolumeControl,
// WorkspaceController, NotificationClient) exposed from main.cpp.  Every
// status control degrades gracefully: if a helper reports it's unavailable
// (no battery, no pactl, single workspace), the corresponding tray icon is
// hidden rather than shown as a dead widget.

Item {
    id: root
    height: NiraTheme.panelHeight + NiraTheme.paddingMedium
    property date currentTime: new Date()

    signal toggleAi()
    signal toggleLauncher()
    signal toggleNotifications()
    signal toggleWallpaperPicker()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: NiraTheme.paddingSmall
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        color: NiraTheme.glassBackground
        radius: NiraTheme.radiusMedium
        border.color: NiraTheme.glassBorder
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: NiraTheme.paddingSmall
            anchors.rightMargin: NiraTheme.paddingSmall
            spacing: NiraTheme.paddingSmall

            // ── Left: logo + Start (launcher) + Browser shortcut ────────
            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Image {
                    source: "qrc:/nira/brand/nira-logo.svg"
                    sourceSize: Qt.size(20, 20)
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Button {
                    id: launcherButton
                    text: "Nira"
                    font.bold: true
                    font.pixelSize: 14
                    onClicked: root.toggleLauncher()
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: launcherButton.text
                        color: launcherButton.hovered ? NiraTheme.accentPrimary : NiraTheme.textPrimary
                        font: launcherButton.font
                    }
                }

                Rectangle {
                    width: 1; height: 20
                    color: NiraTheme.glassBorder
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }

                Button {
                    id: browserButton
                    text: "Browser"
                    font.pixelSize: 11
                    onClicked: processLauncher.launch("falkon")
                    ToolTip.visible: hovered
                    ToolTip.text: "Open Falkon"
                    background: Rectangle {
                        color: browserButton.hovered ? NiraTheme.glassHighlight : "transparent"
                        radius: NiraTheme.radiusSmall
                        Behavior on color { ColorAnimation { duration: NiraTheme.animMicro } }
                    }
                    contentItem: Text {
                        text: browserButton.text
                        color: browserButton.hovered ? NiraTheme.accentPrimary : NiraTheme.textSecondary
                        font: browserButton.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Layout.preferredWidth: 62
                    Layout.preferredHeight: 26
                }
            }

            // ── Taskbar: running windows ────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 80
                Layout.preferredWidth: 300
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 500
                clip: true

                ListView {
                    id: taskList
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 2
                    clip: true
                    model: taskbarModel

                    delegate: Rectangle {
                        id: taskBtn
                        required property int index
                        required property string title
                        required property bool isFocused
                        required property bool isMinimized
                        width: 120
                        height: taskList.height
                        radius: 4
                        color: {
                            if (taskBtn.isFocused) return Qt.rgba(0, 0.898, 1, 0.18)
                            if (taskBtn.isMinimized) return Qt.rgba(1, 1, 1, 0.03)
                            if (ma.containsMouse) return NiraTheme.glassHighlight
                            return "transparent"
                        }
                        Behavior on color { ColorAnimation { duration: NiraTheme.animMicro } }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 2
                            color: taskBtn.isFocused ? NiraTheme.accentPrimary
                                  : taskBtn.isMinimized ? NiraTheme.textMuted
                                  : "transparent"
                            radius: 1
                            Behavior on color { ColorAnimation { duration: NiraTheme.animQuick } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            Text {
                                text: (taskBtn.title || "?").charAt(0).toUpperCase()
                                color: NiraTheme.textPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                text: taskBtn.title || ""
                                color: taskBtn.isFocused ? NiraTheme.textPrimary : NiraTheme.textSecondary
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    taskItemMenu.targetIndex = taskBtn.index
                                    taskItemMenu.popup()
                                    return
                                }
                                taskbarModel.toggle(taskBtn.index)
                            }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: taskList.count === 0
                    text: "No windows"
                    color: NiraTheme.textMuted
                    font.pixelSize: 10
                    font.italic: true
                }
            }

            Item { Layout.fillWidth: true }

            // ── Center: clock with date ─────────────────────────────────
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Text {
                    text: Qt.formatTime(root.currentTime, "hh:mm AP")
                    color: NiraTheme.textPrimary
                    font.pixelSize: 16
                    font.bold: true
                    font.letterSpacing: 0.5
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: Qt.formatDate(root.currentTime, "ddd MMM d")
                    color: NiraTheme.textMuted
                    font.pixelSize: 9
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Item { Layout.fillWidth: true }

            // ── Workspace switcher (only if > 1 workspace exists) ───────
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                visible: workspaceController.count > 1

                Repeater {
                    model: workspaceController.count
                    delegate: Rectangle {
                        required property int index
                        width: 22
                        height: 22
                        radius: 4
                        color: workspaceController.current === index
                            ? NiraTheme.accentPrimary
                            : (wsMa.containsMouse ? NiraTheme.glassHighlight : "transparent")
                        border.color: workspaceController.current === index ? "transparent" : NiraTheme.glassBorder
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: (parent.index + 1).toString()
                            color: workspaceController.current === parent.index ? NiraTheme.background : NiraTheme.textSecondary
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: workspaceController.switchTo(parent.index)
                        }
                    }
                }
            }

            // ── Right: system tray ──────────────────────────────────────
            RowLayout {
                spacing: NiraTheme.paddingSmall
                Layout.alignment: Qt.AlignVCenter

                // Volume control (hidden if pactl unavailable).
                Item {
                    visible: volumeControl.available
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter

                    Button {
                        id: volumeButton
                        anchors.fill: parent
                        flat: true
                        onClicked: volumePopup.visible ? volumePopup.close() : volumePopup.open()
                        background: Rectangle { color: volumeButton.hovered ? NiraTheme.glassHighlight : "transparent"; radius: NiraTheme.radiusSmall }
                        contentItem: Image {
                            source: volumeControl.muted
                                ? "qrc:/nira/icons/network.svg"
                                : "image://icon/audio-volume-high"
                            sourceSize: Qt.size(16, 16)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            // Fallback to a simple text glyph if the theme
                            // doesn't have the audio-volume icon.
                            Text {
                                anchors.centerIn: parent
                                text: volumeControl.muted ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                                color: NiraTheme.textPrimary
                                font.pixelSize: 13
                                visible: parent.status === Image.Error
                            }
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: volumeControl.muted ? qsTr("Muted") : qsTr("Volume: %1%").arg(volumeControl.volume)
                    }

                    Popup {
                        id: volumePopup
                        x: (volumeButton.width - width) / 2
                        y: -height - 6
                        width: 160
                        height: 60
                        background: Rectangle { color: NiraTheme.surface; radius: NiraTheme.radiusMedium; border.color: NiraTheme.glassBorder; border.width: 1 }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: volumeControl.muted ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                                    color: NiraTheme.textPrimary
                                    font.pixelSize: 14
                                }
                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 100
                                    value: volumeControl.volume
                                    onMoved: volumeControl.setVolume(Math.round(value))
                                }
                            }
                            Button {
                                id: muteBtn
                                text: volumeControl.muted ? qsTr("Unmute") : qsTr("Mute")
                                Layout.fillWidth: true
                                flat: true
                                onClicked: volumeControl.toggleMuted()
                                contentItem: Text { text: muteBtn.text; color: NiraTheme.textSecondary; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
                                background: Rectangle { color: muteBtn.hovered ? NiraTheme.glassHighlight : "transparent"; radius: 4 }
                            }
                        }
                    }
                }

                // Battery (only on systems that report a battery).
                Item {
                    visible: powerStatus.present
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        anchors.fill: parent
                        spacing: 2
                        Text {
                            text: powerStatus.charging ? "\u26A1" : "\uD83D\uDD0B"
                            color: NiraTheme.textPrimary
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: powerStatus.percent + "%"
                            color: powerStatus.percent < 20 ? NiraTheme.accentDanger
                                  : powerStatus.percent < 40 ? NiraTheme.accentWarning
                                  : NiraTheme.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                    ToolTip.visible: batteryMa.containsMouse
                    ToolTip.text: powerStatus.charging
                        ? qsTr("Charging: %1%").arg(powerStatus.percent)
                        : qsTr("Battery: %1%").arg(powerStatus.percent)
                    MouseArea {
                        id: batteryMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                // Network (always visible; shows the connection state).
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/nira/icons/network.svg"
                        sourceSize: Qt.size(16, 16)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    ToolTip.visible: netMa.containsMouse
                    ToolTip.text: qsTr("Network")
                    MouseArea {
                        id: netMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                Rectangle {
                    width: 1; height: 20
                    color: NiraTheme.glassBorder
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }

                // Notifications bell with unread badge.
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter

                    Button {
                        id: notifButton
                        anchors.fill: parent
                        flat: true
                        onClicked: root.toggleNotifications()
                        background: Rectangle { color: notifButton.hovered ? NiraTheme.glassHighlight : "transparent"; radius: NiraTheme.radiusSmall }
                        contentItem: Image {
                            source: "qrc:/nira/nira/chat-bubble.svg"
                            sourceSize: Qt.size(16, 16)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                    // Unread badge.
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.topMargin: 2
                        width: 12
                        height: 12
                        radius: 6
                        color: NiraTheme.accentDanger
                        visible: notificationClient.unreadCount > 0
                        Text {
                            anchors.centerIn: parent
                            text: notificationClient.unreadCount > 9 ? "9+" : notificationClient.unreadCount
                            color: "white"
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }

                // AI button.
                Button {
                    id: aiButton
                    text: "AI"
                    font.bold: true
                    font.pixelSize: 11
                    onClicked: root.toggleAi()
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: 52
                    background: Rectangle {
                        color: aiButton.hovered ? NiraTheme.accentSecondary : "transparent"
                        radius: NiraTheme.radiusSmall
                        border.color: NiraTheme.accentSecondary
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: NiraTheme.animMicro } }
                    }
                    contentItem: Text {
                        text: aiButton.text
                        color: NiraTheme.textPrimary
                        font: aiButton.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // ── Per-window task item context menu ────────────────────────────────
    Menu {
        id: taskItemMenu
        property int targetIndex: -1
        MenuItem {
            text: qsTr("Activate")
            onTriggered: taskbarModel.activate(taskItemMenu.targetIndex)
        }
        MenuItem {
            text: qsTr("Minimize")
            onTriggered: taskbarModel.minimize(taskItemMenu.targetIndex)
        }
        MenuItem {
            text: qsTr("Close")
            onTriggered: taskbarModel.close(taskItemMenu.targetIndex)
        }
    }
}
