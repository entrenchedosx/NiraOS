import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    height: 28
    color: "#0D0D10"
    border.color: "#1A1A20"
    border.width: 1

    property string currentPath: ""
    property int itemCount: 0
    property int selectedCount: 0
    property string viewModeText: ""

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 16

        // Item count
        Text {
            text: {
                if (root.selectedCount > 0)
                    return qsTr("%1 items — %2 selected").arg(root.itemCount).arg(root.selectedCount)
                return qsTr("%1 items").arg(root.itemCount)
            }
            color: "#8E8E98"
            font.pixelSize: 11
        }

        // Separator
        Rectangle {
            width: 1
            height: 14
            color: "#2A2A30"
            Layout.alignment: Qt.AlignVCenter
        }

        // Current path
        Text {
            text: root.currentPath
            color: "#5A5A64"
            font.pixelSize: 11
            elide: Text.ElideLeft
            Layout.fillWidth: true
        }

        // View mode
        Text {
            text: root.viewModeText
            color: "#5A5A64"
            font.pixelSize: 11
        }

        // Separator
        Rectangle {
            width: 1
            height: 14
            color: "#2A2A30"
            Layout.alignment: Qt.AlignVCenter
        }

        // Free space
        Text {
            id: freeSpaceText
            text: {
                var info = storageManager.driveInfo ? storageManager.driveInfo(root.currentPath) : null
                if (info && info.freeBytes)
                    return qsTr("Free: %1").arg(formatSize(info.freeBytes))
                return ""
            }
            color: "#5A5A64"
            font.pixelSize: 11
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

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: freeSpaceText.text = freeSpaceText.text // force re-eval
    }
}
