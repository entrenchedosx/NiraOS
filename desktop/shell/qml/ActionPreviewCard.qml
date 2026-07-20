import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NiraOS

Popup {
    id: actionPreviewCard
    width: 450
    height: 250
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    
    background: Rectangle {
        color: NiraTheme.glassBackground
        radius: NiraTheme.radiusLarge
        border.color: NiraTheme.accentAi // Glow color for prompt
        border.width: 1
    }
    
    property string actionName: "Move to archive"
    property string filesCount: "20"
    property string spaceCount: "15GB"
    
    signal approved()
    signal cancelled()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: NiraTheme.paddingLarge
        spacing: NiraTheme.paddingMedium
        
        Text {
            Layout.fillWidth: true
            text: "Nira AI is requesting permission:"
            color: NiraTheme.textSecondary
            font.pixelSize: 14
        }
        
        Text {
            Layout.fillWidth: true
            text: actionPreviewCard.actionName
            color: NiraTheme.textPrimary
            font.bold: true
            font.pixelSize: 22
        }
        
        GridLayout {
            columns: 2
            rowSpacing: NiraTheme.paddingSmall
            columnSpacing: NiraTheme.paddingLarge
            
            Text { text: "Files:"; color: NiraTheme.textSecondary; font.pixelSize: 16 }
            Text { text: actionPreviewCard.filesCount; color: NiraTheme.textPrimary; font.bold: true; font.pixelSize: 16 }
            
            Text { text: "Space:"; color: NiraTheme.textSecondary; font.pixelSize: 16 }
            Text { text: actionPreviewCard.spaceCount; color: NiraTheme.textPrimary; font.bold: true; font.pixelSize: 16 }
        }
        
        Item { Layout.fillHeight: true } // spacer
        
        RowLayout {
            Layout.fillWidth: true
            spacing: NiraTheme.paddingMedium
            
            Button {
                id: cancelButton
                text: "Cancel"
                Layout.fillWidth: true
                onClicked: { actionPreviewCard.cancelled(); actionPreviewCard.close(); }
                background: Rectangle {
                    color: cancelButton.hovered ? "#33FF0000" : "transparent"
                    border.color: NiraTheme.glassBorder
                    radius: NiraTheme.radiusMedium
                }
                contentItem: Text {
                    text: cancelButton.text; color: NiraTheme.textPrimary
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                id: approveButton
                text: "Approve"
                Layout.fillWidth: true
                onClicked: { actionPreviewCard.approved(); actionPreviewCard.close(); }
                background: Rectangle {
                    color: approveButton.hovered ? NiraTheme.accentAi : NiraTheme.glassBorder
                    radius: NiraTheme.radiusMedium
                }
                contentItem: Text {
                    text: approveButton.text; color: NiraTheme.textPrimary; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
