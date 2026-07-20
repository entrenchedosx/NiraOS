import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string currentPath: ""
    signal navigate(string path)

    implicitHeight: 30

    ListView {
        id: breadcrumbList
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: 2
        clip: true
        interactive: false

        model: {
            var parts = root.currentPath.split("/")
            var segments = []
            var accumulated = ""

            if (root.currentPath.startsWith("/")) {
                segments.push({ label: "/", fullPath: "/" })
                accumulated = ""
                // Start from index 1 for root
                for (var i = 1; i < parts.length; i++) {
                    if (parts[i] === "") continue
                    accumulated += "/" + parts[i]
                    if (i === 1) accumulated = "/" + parts[i]
                    segments.push({ label: parts[i], fullPath: accumulated })
                }
            } else {
                for (var i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue
                    if (accumulated.length > 0) accumulated += "/"
                    accumulated += parts[i]
                    segments.push({ label: parts[i], fullPath: accumulated })
                }
            }
            return segments
        }

        delegate: RowLayout {
            spacing: 2
            height: breadcrumbList.height

            Label {
                text: modelData.label
                color: mouseArea.containsMouse ? "#00E5FF" : "#B0B0B8"
                font.pixelSize: 11
                font.weight: index === breadcrumbList.count - 1 ? Font.Bold : Font.Normal
                padding: 4
                background: Rectangle {
                    color: mouseArea.containsMouse ? Qt.rgba(0, 0.898, 1, 0.08) : "transparent"
                    radius: 4
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigate(modelData.fullPath)
                }
            }

            Text {
                text: index < breadcrumbList.count - 1 ? "/" : ""
                color: "#5A5A64"
                font.pixelSize: 11
                visible: index < breadcrumbList.count - 1
            }
        }
    }
}
