import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: setupWizardWindow
    title: "Welcome to NiraOS"
    width: 800
    height: 600
    visible: true
    color: "#1e1e2e" // Nira dark theme
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        
        Text {
            text: "Welcome to NiraOS"
            color: "white"
            font.bold: true
            font.pixelSize: 32
            Layout.alignment: Qt.AlignHCenter
        }
        
        Text {
            text: "Your AI-Native Operating System."
            color: "#a6adc8"
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter
        }
        
        Item { height: 20 } // Spacer
        
        Text {
            text: "Select Performance Profile:"
            color: "white"
            font.pixelSize: 16
        }
        
        RowLayout {
            spacing: 15
            Layout.alignment: Qt.AlignHCenter
            
            Button { text: "Performance" }
            Button { text: "Balanced (Recommended)" }
            Button { text: "Battery Saver" }
        }
        
        Item { height: 40 } // Spacer
        
        Button {
            text: "Begin Setup"
            Layout.alignment: Qt.AlignHCenter
            onClicked: console.log("Initializing local Qwen weights...")
        }
    }
}
