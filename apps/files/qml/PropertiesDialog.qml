import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Dialog {
    id: root
    modal: true
    standardButtons: Dialog.Close
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: 460
    height: 520
    title: qsTr("Properties")

    property string targetPath: ""
    property var info: ({})

    background: Rectangle {
        color: "#141418"
        radius: 12
        border.color: "#2A2A30"
        border.width: 1
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        RowLayout {
            spacing: 16
            Layout.fillWidth: true

            Image {
                id: propIcon
                source: "image://icon/" + (root.info.isDir ? "folder" : "text-x-generic")
                sourceSize: Qt.size(48, 48)
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                asynchronous: true
            }

            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true

                Text {
                    text: root.info.name || ""
                    color: "#F0F0F5"
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.info.isDir ? qsTr("Folder") : qsTr("File")
                    color: "#8E8E98"
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            height: 1
            Layout.fillWidth: true
            color: "#1E1E24"
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                PropertyRow { label: qsTr("Name"); value: root.info.name || "" }
                PropertyRow { label: qsTr("Type"); value: root.info.isDir ? qsTr("Folder") : (root.info.mimeType || "") }
                PropertyRow { label: qsTr("Location"); value: root.info.path || "" }
                PropertyRow { label: qsTr("Size"); value: root.info.sizeHuman || root.formatSize(root.info.size) }
                PropertyRow { label: qsTr("Contains"); value: root.info.isDir ? (root.info.itemCount + " items") : "—" }
                Rectangle { height: 1; Layout.fillWidth: true; color: "#1E1E24" }
                PropertyRow { label: qsTr("Modified"); value: root.info.lastModified ? Qt.formatDateTime(root.info.lastModified, "yyyy-MM-dd hh:mm:ss") : "—" }
                PropertyRow { label: qsTr("Accessed"); value: root.info.lastAccessed ? Qt.formatDateTime(root.info.lastAccessed, "yyyy-MM-dd hh:mm:ss") : "—" }
                PropertyRow { label: qsTr("Created"); value: root.info.created ? Qt.formatDateTime(root.info.created, "yyyy-MM-dd hh:mm:ss") : "—" }
                Rectangle { height: 1; Layout.fillWidth: true; color: "#1E1E24" }
                PropertyRow { label: qsTr("Permissions"); value: root.formatPermissions(root.info) }
                PropertyRow { label: qsTr("Owner"); value: root.info.owner || "—" }
                PropertyRow { label: qsTr("Group"); value: root.info.group || "—" }
                Rectangle { height: 1; Layout.fillWidth: true; color: "#1E1E24" }
                PropertyRow { label: qsTr("Volume"); value: root.info.filesystem || "" }
                PropertyRow { label: qsTr("Free Space"); value: root.formatSize(root.info.fsFree) }
                PropertyRow { label: qsTr("Total Space"); value: root.formatSize(root.info.fsTotal) }
            }
        }
    }

    function showForPath(path) {
        root.targetPath = path
        root.info = fileOperations.getFileInfo(path)
        root.open()
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

    function formatPermissions(info) {
        var perms = ""
        perms += info.isReadable ? "r" : "-"
        perms += info.isWritable ? "w" : "-"
        perms += info.isExecutable ? "x" : "-"
        return perms
    }
}
