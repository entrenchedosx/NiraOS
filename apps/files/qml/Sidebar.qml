import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: root
    signal navigate(string path)

    property string currentPath: fileModel.currentPath

    Rectangle {
        anchors.fill: parent
        color: "#0D0D10"

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 8
            spacing: 4

            Text {
                text: qsTr("PLACES")
                color: "#5A5A64"
                font.pixelSize: 10
                font.letterSpacing: 1
                textFormat: Text.PlainText
                Layout.leftMargin: 16
                Layout.bottomMargin: 4
                Layout.topMargin: 8
            }

            Repeater {
                model: ListModel {
                    // The "icon" field is a freedesktop theme icon name.
                    // DesktopView's ThemeIconProvider now checks NiraOS qrc
                    // assets first, so "user-home" resolves to sidebar-home.svg
                    // from the file manager's qrc when the theme lacks it.
                    ListElement { label: "Home"; icon: "user-home" }
                    ListElement { label: "Desktop"; icon: "user-desktop" }
                    ListElement { label: "Documents"; icon: "folder-documents" }
                    ListElement { label: "Downloads"; icon: "folder-download" }
                    ListElement { label: "Pictures"; icon: "folder-image" }
                    ListElement { label: "Videos"; icon: "folder-video" }
                    ListElement { label: "Music"; icon: "folder-music" }
                }

                delegate: SidebarItem {
                    label: model.label
                    iconName: model.icon
                    isActive: root.currentPath === getPlacePath(model.label)
                    onItemClicked: root.navigate(getPlacePath(model.label))

                    function getPlacePath(place) {
                        var sp = standardPaths
                        switch (place) {
                            case "Home": return sp.home
                            case "Desktop": return sp.desktop
                            case "Documents": return sp.documents
                            case "Downloads": return sp.downloads
                            case "Pictures": return sp.pictures
                            case "Videos": return sp.videos
                            case "Music": return sp.music
                            default: return sp.home
                        }
                    }
                }
            }

            Rectangle {
                height: 1
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                color: "#1E1E24"
            }

            Text {
                text: qsTr("DRIVES")
                color: "#5A5A64"
                font.pixelSize: 10
                font.letterSpacing: 1
                textFormat: Text.PlainText
                Layout.leftMargin: 16
                Layout.bottomMargin: 4
            }

            ListView {
                id: drivesList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: storageManager ? storageManager.drives : []
                clip: true
                delegate: SidebarItem {
                    label: model.name || model.path
                    iconName: "drive-harddisk"
                    sublabel: root.formatSize(model.freeBytes) + " free"
                    isActive: root.currentPath === model.mountPoint
                    onItemClicked: root.navigate(model.mountPoint)
                }
            }

            Rectangle {
                height: 1
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: "#1E1E24"
            }

            SidebarItem {
                label: qsTr("Trash")
                iconName: "user-trash"
                isActive: false
                onItemClicked: {
                    root.navigate(standardPaths.trash)
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    function formatSize(bytes) {
        if (!bytes) return "0 B"
        if (bytes < 1024) return bytes + " B"
        var kb = bytes / 1024
        if (kb < 1024) return kb.toFixed(1) + " KB"
        var mb = kb / 1024
        if (mb < 1024) return mb.toFixed(1) + " MB"
        var gb = mb / 1024
        return gb.toFixed(2) + " GB"
    }

    Connections {
        target: storageManager
        function onDrivesChanged() {
            drivesList.model = storageManager ? storageManager.drives : []
        }
    }
}
