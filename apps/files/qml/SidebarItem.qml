import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebarItem
    property string label: ""
    property string iconName: ""
    property string sublabel: ""
    property bool isActive: false
    signal itemClicked()

    height: 40
    color: isActive ? Qt.rgba(0, 0.898, 1, 0.08)
                    : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
    radius: 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Image {
            source: "image://icon/" + iconName
            sourceSize: Qt.size(18, 18)
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: label
                color: isActive ? "#00E5FF" : (mouseArea.containsMouse ? "#F0F0F5" : "#B0B0B8")
                font.pixelSize: 12
                font.weight: isActive ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: sublabel
                color: "#5A5A64"
                font.pixelSize: 9
                visible: sublabel.length > 0
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: itemClicked()
    }
}
