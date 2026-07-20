import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import NiraOS

// NiraOS Shell — top-level window.
//
// Layout:
//   ┌─────────────────────────────────────────────┐
//   │ TopPanel (panel)                            │  ← z=10
//   ├─────────────────────────────────────────────┤
//   │                                             │
//   │   DesktopView (icons, drag/drop, context)   │
//   │                                             │
//   │   ┌──────────────┐    ┌──────────────────┐  │
//   │   │ AppLauncher  │    │ AiAssistant      │  │
//   │   └──────────────┘    └──────────────────┘  │
//   │                                             │
//   │                          NotificationsPopup │
//   └─────────────────────────────────────────────┘
//
// Multi-monitor: the shell window is sized to the full virtual desktop
// (Screen.width/height on the primary screen).  Qt reports each additional
// connected screen via Screen.onScreenChanged in the application; we expose
// a "screens" property for the panel so a future per-monitor panel can be
// added without restructuring.

Window {
    id: root
    width: Screen.width > 0 ? Screen.width : 1920
    height: Screen.height > 0 ? Screen.height : 1080
    visible: true
    title: qsTr("NiraOS Shell")
    color: NiraTheme.background

    // The current wallpaper is sourced from WallpaperModel so the Settings
    // app and the right-click wallpaper picker share one source of truth.
    property url wallpaperSource: wallpaperModel.currentWallpaper

    // Track connected screens for multi-monitor awareness.  Qt's Screen
    // attached property exposes the primary screen; we expose the count via
    // Qt.application.screens where available.
    property int screenCount: 1
    property string primaryScreenName: Screen.name || "primary"

    Component.onCompleted: {
        if (typeof Qt.application.screens !== "undefined")
            screenCount = Qt.application.screens.length
        // Apply the persisted wallpaper (WallpaperModel.loadCurrent ran in
        // its constructor; this assignment just ensures the Image picks it
        // up after both objects exist).
        wallpaperSource = wallpaperModel.currentWallpaper
    }

    // ── Wallpaper ────────────────────────────────────────────────────────
    Image {
        id: wallpaper
        anchors.fill: parent
        source: wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false

        Behavior on source {
            SequentialAnimation {
                PropertyAction { target: wallpaper; property: "source" }
                NumberAnimation { target: wallpaper; property: "opacity"; from: 0; to: 1; duration: NiraTheme.animSlow; easing.type: Easing.OutQuad }
            }
        }
    }

    // Subtle darkening so icons and toasts are legible over any wallpaper.
    Rectangle {
        anchors.fill: parent
        color: NiraTheme.background
        opacity: 0.15
    }

    // ── Top panel ────────────────────────────────────────────────────────
    TopPanel {
        id: panel
        width: parent.width
        anchors.top: parent.top
        z: 10
        onToggleWallpaperPicker: wallpaperPicker.open()
        onToggleNotifications: notificationsToggle()
    }

    // ── Desktop area (everything below the panel) ────────────────────────
    Rectangle {
        id: desktopArea
        anchors.top: panel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        // Desktop icons + drag/drop + right-click menu.
        DesktopView {
            id: desktopView
            anchors.fill: parent
            onChangeWallpaperRequested: wallpaperPicker.open()
            onSettingsRequested: processLauncher.launch("nira-settings")
            onOpenTerminal: function(dir) {
                const target = dir && dir.length > 0 ? dir : desktopIconModel.desktopPath
                if (typeof fileOperations !== "undefined")
                    fileOperations.openInTerminal(target)
                else
                    processLauncher.launch("qterminal --workdir " + target)
            }
            onPasteRequested: {
                // Desktop paste: the file manager owns the clipboard when
                // running.  When it isn't, paste is disabled in the menu.
            }
        }

        // Application launcher (Start menu), anchored under the Start button.
        AppLauncher {
            id: launcher
            // Position below the panel's Start button: top-left of desktop area
            // with a small gap so it visually attaches to the button.
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 6
            anchors.leftMargin: 6
            visible: false
            z: 20
        }

        // AI assistant overlay (right side, full height).
        AiAssistant {
            id: aiOverlay
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: false
            z: 20
        }

        // Notification toasts (bottom-right, above the panel).
        NotificationsPopup {
            id: notificationsPopup
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 16
            anchors.bottomMargin: 16
            z: 30
        }
    }

    // ── Wallpaper picker dialog ──────────────────────────────────────────
    WallpaperPicker {
        id: wallpaperPicker
        parent: Overlay.overlay
        onWallpaperSelected: function(u) {
            wallpaperSource = u
        }
    }

    // ── Panel signal routing ─────────────────────────────────────────────
    Connections {
        target: panel
        function onToggleAi() {
            aiOverlay.visible = !aiOverlay.visible
        }
        function onToggleLauncher() {
            launcher.visible = !launcher.visible
        }
    }

    // ── Global keyboard shortcuts ────────────────────────────────────────
    // Super+Space toggles the AI overlay (the signature NiraOS hotkey).
    Shortcut {
        sequence: "Meta+Space"
        onActivated: aiOverlay.visible = !aiOverlay.visible
    }
    // Super opens/closes the launcher (Windows/GNOME convention).
    Shortcut {
        sequence: "Meta"
        onActivated: launcher.visible = !launcher.visible
    }
    // Super+L locks the session (delegates to loginctl, which greetd honours).
    Shortcut {
        sequence: "Meta+L"
        onActivated: processLauncher.launch("loginctl lock-session")
    }
    // Super+D / Show Desktop: minimize all windows via the compositor.
    Shortcut {
        sequence: "Meta+D"
        onActivated: {
            for (let i = 0; i < taskbarModel.rowCount(); ++i)
                taskbarModel.minimize(i)
        }
    }
    // Super+E opens the file manager at the home directory.
    Shortcut {
        sequence: "Meta+E"
        onActivated: processLauncher.launch("nira-files")
    }
    // Super+T opens a terminal.
    Shortcut {
        sequence: "Meta+T"
        onActivated: processLauncher.launch("qterminal")
    }
    // Ctrl+Alt+Delete opens a session-quit confirmation dialog.
    Shortcut {
        sequence: "Ctrl+Alt+Delete"
        onActivated: logoutDialog.open()
    }
    // Workspace switching hotkeys (only active if workspaces exist).
    Shortcut {
        sequence: "Meta+Right"
        enabled: workspaceController.count > 1
        onActivated: workspaceController.next()
    }
    Shortcut {
        sequence: "Meta+Left"
        enabled: workspaceController.count > 1
        onActivated: workspaceController.previous()
    }
    // Volume keys (only when pactl is available).
    Shortcut {
        sequence: "VolumeUp"
        enabled: volumeControl.available
        onActivated: volumeControl.setVolume(Math.min(100, volumeControl.volume + 5))
    }
    Shortcut {
        sequence: "VolumeDown"
        enabled: volumeControl.available
        onActivated: volumeControl.setVolume(Math.max(0, volumeControl.volume - 5))
    }
    Shortcut {
        sequence: "VolumeMute"
        enabled: volumeControl.available
        onActivated: volumeControl.toggleMuted()
    }

    // ── Notifications toggle (from panel bell) ───────────────────────────
    function notificationsToggle() {
        // The bell click dismisses the most-recent notification (the toast
        // stack itself is always visible when there are unread toasts).
        // If there are none, it's a no-op.
        if (notificationClient.unreadCount > 0)
            notificationClient.dismiss(0)
    }

    // ── Session logout dialog (Ctrl+Alt+Delete) ──────────────────────────
    Dialog {
        id: logoutDialog
        modal: true
        anchors.centerIn: parent
        width: 360
        height: 180
        title: qsTr("End Session")
        background: Rectangle {
            color: NiraTheme.surface
            radius: NiraTheme.radiusLarge
            border.color: NiraTheme.glassBorder
            border.width: 1
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            Text {
                text: qsTr("Log out of NiraOS?")
                color: NiraTheme.textPrimary
                font.pixelSize: 15
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                text: qsTr("All unsaved work will be lost.")
                color: NiraTheme.textSecondary
                font.pixelSize: 11
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button { text: qsTr("Cancel"); onClicked: logoutDialog.reject() }
                Button {
                    text: qsTr("Log Out")
                    highlighted: true
                    onClicked: {
                        processLauncher.launch("loginctl terminate-session $XDG_SESSION_ID")
                        Qt.quit()
                    }
                }
            }
        }
    }

    // ── Multi-monitor: react to screen changes ───────────────────────────
    // Qt emits a screen change when the window is dragged to another monitor
    // or when the primary screen changes.  We track it for the panel's
    // multi-monitor indicator; the shell itself stays fullscreen across the
    // virtual desktop.
    Screen.onScreenChanged: function() {
        primaryScreenName = Screen.name || "primary"
    }
    // React to monitor hotplug via the application's screen list.
    Connections {
        target: Qt.application
        function onScreenAdded(screen) {
            screenCount = (typeof Qt.application.screens !== "undefined")
                ? Qt.application.screens.length : screenCount + 1
        }
    }

    // ── Wallpaper change relay (Settings app → shell) ────────────────────
    // The Settings app can update the wallpaper by setting
    // wallpaperModel.currentWallpaper; we observe the model and apply it to
    // the Image here so a single binding drives the wallpaper everywhere.
    Connections {
        target: wallpaperModel
        function onCurrentWallpaperChanged() {
            wallpaperSource = wallpaperModel.currentWallpaper
        }
    }
}
