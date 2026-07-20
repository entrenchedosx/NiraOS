import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NiraOS

// NiraOS Wallpaper Picker.
//
// Renders the WallpaperModel as a grid of thumbnails.  Clicking a thumbnail
// calls wallpaperModel.setCurrentWallpaper() and persists the choice via
// saveCurrent().  The dialog closes on selection or Esc.

Dialog {
    id: root
    modal: true
    title: qsTr("Choose Wallpaper")
    width: 720
    height: 480
    anchors.centerIn: parent
    background: Rectangle {
        color: NiraTheme.surface
        radius: NiraTheme.radiusLarge
        border.color: NiraTheme.glassBorder
        border.width: 1
    }

    signal wallpaperSelected(url wallpaper)

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: qsTr("Select a wallpaper")
            color: NiraTheme.textPrimary
            font.pixelSize: 16
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridView {
                id: grid
                cellWidth: 200
                cellHeight: 130
                model: wallpaperModel
                clip: true

                delegate: Item {
                    id: cell
                    width: grid.cellWidth
                    height: grid.cellHeight
                    required property url path
                    required property string name
                    required property bool isUser
                    required property int index

                    property bool selected: wallpaperModel.currentWallpaper === path

                    Rectangle {
                        id: cellBg
                        anchors.fill: parent
                        anchors.margins: 6
                        color: cell.selected ? Qt.rgba(0, 0.898, 1, 0.18) : "transparent"
                        border.color: cell.selected ? NiraTheme.accentPrimary : NiraTheme.glassBorder
                        border.width: cell.selected ? 2 : 1
                        radius: NiraTheme.radiusSmall

                        Image {
                            anchors.fill: parent
                            anchors.margins: 8
                            source: cell.path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status !== Image.Error
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.bottomMargin: 4
                            text: cell.name
                            color: NiraTheme.textPrimary
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            // Subtle background for legibility.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -2
                                color: "#80000000"
                                radius: 3
                                z: -1
                            }
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wallpaperModel.setCurrentWallpaper(cell.path)
                            wallpaperModel.saveCurrent()
                            root.wallpaperSelected(cell.path)
                            root.accept()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8
            Button {
                text: qsTr("Close")
                onClicked: root.reject()
            }
        }
    }
}
