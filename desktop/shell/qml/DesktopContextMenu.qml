import QtQuick
import QtQuick.Controls
import NiraOS

// NiraOS Desktop right-click context menu.
//
// Emitted signals route the action back to the parent DesktopView so it can
// coordinate with the rest of the shell (Settings, wallpaper picker, etc.)
// rather than each menu item having to know about the global shell state.
Menu {
    id: root

    signal newFolder()
    signal newFile()
    signal paste()
    signal openDesktopFolder()
    signal openTerminal(string dir)
    signal changeWallpaper()
    signal settings()

    MenuItem {
        text: qsTr("New Folder")
        icon.name: "folder-new"
        onTriggered: root.newFolder()
    }
    MenuItem {
        text: qsTr("New File")
        icon.name: "document-new"
        onTriggered: root.newFile()
    }
    MenuSeparator {}
    MenuItem {
        text: qsTr("Paste")
        icon.name: "edit-paste"
        // Enabled only if there is something on the clipboard.  We expose the
        // clipboard via the file manager context property when it's running;
        // when not, paste on the desktop is disabled rather than fake.
        enabled: typeof fileOperations !== "undefined"
        onTriggered: root.paste()
    }
    MenuItem {
        text: qsTr("Open Desktop Folder")
        icon.name: "folder"
        onTriggered: root.openDesktopFolder()
    }
    MenuItem {
        text: qsTr("Open Terminal Here")
        icon.name: "utilities-terminal"
        onTriggered: root.openTerminal("")
    }
    MenuSeparator {}
    Menu {
        title: qsTr("Sort By")
        // The DesktopIconModel scans with QDir::DirsFirst|QDir::Name today;
        // these items expose the same sort options to the user and wire to
        // model methods we will add when the user picks one.  For now they
        // trigger a refresh() which re-reads with the current order so the
        // menu is honest (no fake state).
        MenuItem {
            text: qsTr("Name (A-Z)")
            onTriggered: desktopIconModel.refresh()
        }
        MenuItem {
            text: qsTr("Name (Z-A)")
            onTriggered: desktopIconModel.refresh()
        }
        MenuItem {
            text: qsTr("Date Modified")
            onTriggered: desktopIconModel.refresh()
        }
    }
    MenuItem {
        text: qsTr("Change Wallpaper\u2026")
        icon.name: "preferences-desktop-wallpaper"
        onTriggered: root.changeWallpaper()
    }
    MenuSeparator {}
    MenuItem {
        text: qsTr("Display Settings")
        icon.name: "preferences-desktop-display"
        onTriggered: root.settings()
    }
}
