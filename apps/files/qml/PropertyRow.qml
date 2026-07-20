import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    id: propRow
    property string label: ""
    property string value: ""
    spacing: 16
    Layout.fillWidth: true

    Text {
        text: propRow.label + ":"
        color: "#8E8E98"
        font.pixelSize: 12
        Layout.preferredWidth: 100
        Layout.alignment: Qt.AlignTop
    }

    TextEdit {
        text: propRow.value
        color: "#F0F0F5"
        font.pixelSize: 12
        wrapMode: TextEdit.Wrap
        readOnly: true
        selectByMouse: true
        selectionColor: "#00E5FF"
        selectedTextColor: "#FFFFFF"
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
    }
}
