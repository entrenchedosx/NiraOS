import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: storeWindow
    title: "Nira Store"
    width: 1000
    height: 800
    visible: true
    color: "#1e1e2e"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        
        TextField {
            placeholderText: "Search applications (Flatpak)..."
            Layout.fillWidth: true
            color: "white"
            background: Rectangle {
                color: "#313244"
                radius: 4
            }
        }
        
        GridView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 200
            cellHeight: 250
            model: ListModel {
                ListElement { name: "Firefox"; type: "Web Browser"; icon: "firefox" }
                ListElement { name: "Visual Studio Code"; type: "Development"; icon: "vscode" }
                ListElement { name: "Spotify"; type: "Media"; icon: "spotify" }
            }
            delegate: Rectangle {
                width: 180
                height: 230
                color: "#181825"
                radius: 8
                
                ColumnLayout {
                    anchors.centerIn: parent
                    
                    Rectangle {
                        width: 100; height: 100; color: "#313244"; radius: 20
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Text { text: model.name; color: "white"; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                    Text { text: model.type; color: "#a6adc8"; Layout.alignment: Qt.AlignHCenter }
                    Button { text: "Install"; Layout.alignment: Qt.AlignHCenter; onClicked: console.log("flatpak install " + model.name) }
                }
            }
        }
    }
}
