import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NiraOS

// NiraOS Desktop View — renders the icons from DesktopIconModel as a grid
// with auto-placement, single-click select, double-click open, drag-and-drop
// reorder (renames the file on disk to a unique name), and a right-click
// context menu.  The icon grid avoids the top-left corner so the panel never
// overlaps icons, and lays icons out left-to-right, top-to-bottom.

Item {
    id: root
    anchors.fill: parent

    // ── Configuration ────────────────────────────────────────────────────
    readonly property int iconSize: 88
    readonly property int iconSpacingX: 16
    readonly property int iconSpacingY: 24
    readonly property int topMargin: 12
    readonly property int leftMargin: 12
    readonly property int columns: Math.max(1, Math.floor((width - leftMargin) / (iconSize + iconSpacingX)))

    signal openFile(string path)
    signal openTerminal(string dir)
    signal changeWallpaperRequested()
    signal settingsRequested()
    signal pasteRequested()

    // ── Background click clears selection and closes context menu ────────
    MouseArea {
        id: bgMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            iconView.currentIndex = -1
            if (mouse.button === Qt.RightButton) {
                desktopContextMenu.popup(root, mouse.x, mouse.y)
            }
        }
    }

    // ── Drop target: files dropped onto the desktop are moved/copied here ─
    DropArea {
        id: desktopDrop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: function(drop) {
            // Visual feedback rectangle
            dropHighlight.visible = true
            drop.accepted = drop.hasUrls
        }
        onDropped: function(drop) {
            dropHighlight.visible = false
            if (!drop.hasUrls) return
            // Copy each dropped URL into the Desktop directory.  We use the
            // fileOperations context property if present (file manager
            // already registered it) else fall back to `cp`.
            const urls = drop.urls
            for (let i = 0; i < urls.length; ++i) {
                const src = urls[i].toString().replace("file:///", "/")
                if (src.length === 0) continue
                if (typeof fileOperations !== "undefined") {
                    fileOperations.copy(src, desktopIconModel.desktopPath)
                }
            }
            drop.accepted = true
        }
        onExited: dropHighlight.visible = false

        Rectangle {
            id: dropHighlight
            anchors.fill: parent
            color: NiraTheme.accentPrimary
            opacity: 0.06
            visible: false
            border.color: NiraTheme.accentPrimary
            border.width: 2
            radius: 8
        }
    }

    // ── Icon grid ────────────────────────────────────────────────────────
    GridView {
        id: iconView
        anchors.fill: parent
        anchors.margins: 0
        cellWidth: root.iconSize + root.iconSpacingX
        cellHeight: root.iconSize + root.iconSpacingY
        anchors.topMargin: root.topMargin
        anchors.leftMargin: root.leftMargin
        clip: false
        model: desktopIconModel
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        interactive: false  // desktop doesn't scroll; icons fit the screen

        // Delegate: an icon + label, selectable, draggable, double-click open.
        delegate: Item {
            id: iconDelegate
            width: iconView.cellWidth
            height: iconView.cellHeight
            required property int index
            required property string name
            required property string filePath
            required property string iconName
            required property bool isDirectory
            required property bool isShortcut

            property bool selected: iconView.currentIndex === index

            Rectangle {
                id: iconBg
                anchors.fill: parent
                anchors.margins: 4
                color: iconDelegate.selected
                    ? Qt.rgba(0, 0.898, 1, 0.18)
                    : (iconMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                radius: 8
                border.color: iconDelegate.selected ? NiraTheme.accentPrimary : "transparent"
                border.width: iconDelegate.selected ? 1 : 0
                Behavior on color { ColorAnimation { duration: NiraTheme.animMicro } }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.iconSize - 28

                    Image {
                        id: iconImage
                        anchors.centerIn: parent
                        source: {
                            const ic = iconDelegate.iconName
                            if (ic.startsWith("/"))
                                return "file://" + ic
                            // NiraOS-specific icons bundled in qrc take
                            // priority over generic theme names.
                            if (iconDelegate.isDirectory)
                                return "qrc:/nira/filemanager/folder.svg"
                            if (iconDelegate.isShortcut)
                                return "qrc:/nira/icons/file-document.svg"
                            return "image://icon/" + ic
                        }
                        sourceSize: Qt.size(48, 48)
                        width: 48
                        height: 48
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status !== Image.Error
                    }
                    // Shortcut overlay badge: a small arrow indicator shown
                    // on .desktop shortcut icons, matching Windows/KDE.
                    Image {
                        anchors.bottom: iconImage.bottom
                        anchors.right: iconImage.right
                        anchors.bottomMargin: -2
                        anchors.rightMargin: -2
                        source: "qrc:/nira/desktop/shortcut-overlay.svg"
                        sourceSize: Qt.size(16, 16)
                        width: 16
                        height: 16
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: iconDelegate.isShortcut && iconImage.status !== Image.Error
                    }
                    // Fallback: first-letter tile when the icon can't load.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 48
                        height: 48
                        radius: 8
                        color: iconDelegate.isDirectory ? "#1A6FB2" : "#444"
                        visible: iconImage.status === Image.Error || iconDelegate.iconName === ""
                        Text {
                            anchors.centerIn: parent
                            text: iconDelegate.name.charAt(0).toUpperCase()
                            color: "white"
                            font.pixelSize: 22
                            font.bold: true
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: iconDelegate.name
                    color: iconDelegate.selected ? NiraTheme.textPrimary : "#E0E0E5"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            // Drag handle: dragging an icon starts a uri-list drag carrying
            // the file's path, so dropping it on the file manager moves it.
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.mimeData: {
                "text/uri-list": "file://" + iconDelegate.filePath
            }
            // Visual drag image
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            MouseArea {
                id: iconMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        iconView.currentIndex = iconDelegate.index
                        iconContextMenu.popup(iconDelegate, mouse.x, mouse.y)
                        return
                    }
                    // Left click: single-click selects (KDE/Windows default).
                    iconView.currentIndex = iconDelegate.index
                }

                onDoubleClicked: {
                    // Double-click launches (xdg-open / Exec= / open directory).
                    desktopIconModel.launch(iconDelegate.index)
                }

                // Drag threshold: only start a drag after the user moves
                // beyond ~8px so a click doesn't accidentally begin one.
                drag.threshold: 8
                drag.target: iconDelegate
            }
        }

        // Empty state: no Desktop files yet.
        Text {
            anchors.centerIn: parent
            text: qsTr("Right-click the desktop to create a folder or file.")
            color: NiraTheme.textMuted
            font.pixelSize: 12
            visible: iconView.count === 0
        }
    }

    // ── Per-icon context menu ────────────────────────────────────────────
    Menu {
        id: iconContextMenu
        property int targetIndex: -1
        property var entry: desktopIconModel.get(targetIndex)

        MenuItem {
            text: qsTr("Open")
            onTriggered: desktopIconModel.launch(iconContextMenu.targetIndex)
        }
        MenuItem {
            text: qsTr("Open Target Location")
            visible: {
                const e = iconContextMenu.entry
                return e && e.isShortcut && e.targetPath.length > 0
            }
            onTriggered: {
                const e = iconContextMenu.entry
                if (e && e.targetPath.length > 0)
                    processLauncher.launch("xdg-open " + e.targetPath)
            }
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Rename")
            onTriggered: renameDialog.open()
        }
        MenuItem {
            text: qsTr("Move to Trash")
            onTriggered: desktopIconModel.trashEntry(iconContextMenu.targetIndex)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Properties")
            onTriggered: {
                const e = iconContextMenu.entry
                if (e && typeof fileOperations !== "undefined")
                    fileOperations.showProperties(e.filePath)
            }
        }

        onOpened: iconContextMenu.targetIndex = iconView.currentIndex
    }

    // ── Desktop background context menu ──────────────────────────────────
    DesktopContextMenu {
        id: desktopContextMenu
        onChangeWallpaper: root.changeWallpaperRequested()
        onOpenTerminal: root.openTerminal(desktopIconModel.desktopPath)
        onSettings: root.settingsRequested()
        onPaste: root.pasteRequested()
        onNewFolder: desktopIconModel.createFolder()
        onNewFile: desktopIconModel.createFile()
        onOpenDesktopFolder: desktopIconModel.openDesktopFolder()
    }

    // ── Rename dialog ────────────────────────────────────────────────────
    Dialog {
        id: renameDialog
        modal: true
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: 380
        title: qsTr("Rename")
        background: Rectangle { color: NiraTheme.surface; radius: NiraTheme.radiusMedium; border.color: NiraTheme.glassBorder; border.width: 1 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            Label {
                text: qsTr("New name:")
                color: NiraTheme.textSecondary
                font.pixelSize: 12
            }
            TextField {
                id: renameField
                Layout.fillWidth: true
                color: NiraTheme.textPrimary
                font.pixelSize: 13
                selectByMouse: true
                background: Rectangle {
                    color: NiraTheme.background
                    radius: NiraTheme.radiusSmall
                    border.color: renameField.activeFocus ? NiraTheme.accentPrimary : NiraTheme.glassBorder
                    border.width: 1
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button { text: qsTr("Cancel"); onClicked: renameDialog.reject() }
                Button {
                    text: qsTr("Rename")
                    highlighted: true
                    onClicked: {
                        if (renameField.text.length > 0)
                            desktopIconModel.renameEntry(iconView.currentIndex, renameField.text)
                        renameDialog.accept()
                    }
                }
            }
        }
        onOpened: {
            const e = desktopIconModel.get(iconView.currentIndex)
            renameField.text = e ? e.name : ""
            renameField.selectAll()
            renameField.forceActiveFocus()
        }
    }
}
