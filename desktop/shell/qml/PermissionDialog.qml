import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: permissionDialog
    width: 400
    height: 200
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    
    background: Rectangle {
        color: "#2a2a35"
        radius: 8
        border.color: "#3a3a4f"
    }
    
    property string requestText: "Nira AI wants to read a file."
    
    signal allowedAlways()
    signal allowedOnce()
    signal denied()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        Text {
            Layout.fillWidth: true
            text: "Security Request"
            color: "white"
            font.bold: true
            font.pixelSize: 18
        }
        
        Text {
            Layout.fillWidth: true
            text: permissionDialog.requestText
            color: "lightgray"
            wrapMode: Text.WordWrap
        }
        
        Item { Layout.fillHeight: true } // spacer
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Button {
                text: "Deny"
                onClicked: { permissionDialog.denied(); permissionDialog.close(); }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "Allow Once"
                onClicked: { permissionDialog.allowedOnce(); permissionDialog.close(); }
            }
            
            Button {
                text: "Allow Always"
                onClicked: { permissionDialog.allowedAlways(); permissionDialog.close(); }
            }
        }
    }
}
