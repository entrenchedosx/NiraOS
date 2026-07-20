import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NiraOS

// NiraOS Notification toast stack.
//
// Renders the NotificationClient model as a vertical stack of toasts anchored
// to the bottom-right of the desktop area.  Each toast auto-dismisses after
// `timeoutMs` (urgency-critical toasts stay until dismissed).  A close
// button on each toast and a "Clear all" button on the last toast are
// provided.  The stack is purely a view over the model — state lives in
// NotificationClient, so dismissal removes the row and the next toast slides
// up.

Item {
    id: root

    // Toasts live in the desktop area (below the panel), anchored bottom-right.
    anchors.right: parent ? parent.right : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.rightMargin: 16
    anchors.bottomMargin: 16
    width: 360
    height: toastColumn.height

    readonly property int toastWidth: 360
    readonly property int maxVisible: 4
    readonly property int normalTimeoutMs: 6000
    readonly property int lowTimeoutMs: 4000

    // Clip so off-stack toasts during a slide animation don't overflow.
    clip: false

    Column {
        id: toastColumn
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 8
        layoutDirection: Qt.LeftToRight

        Repeater {
            id: repeater
            // Show at most maxVisible toasts; older ones are still in the model
            // and slide in as the user dismisses the visible ones.
            model: notificationClient

            delegate: Item {
                id: toast
                width: root.toastWidth
                height: toastCard.height
                required property int index
                required property uint id
                required property string appName
                required property string summary
                required property string body
                required property string icon
                required property int urgency
                required property var timestamp

                // Slide-in animation.
                opacity: 0
                x: 20
                Component.onCompleted: {
                    opacityAnim.start()
                    xAnim.start()
                    if (urgency < 2) {
                        autoDismissTimer.start()
                    }
                }

                NumberAnimation on opacity { id: opacityAnim; from: 0; to: 1; duration: NiraTheme.animNormal; easing.type: Easing.OutQuad }
                NumberAnimation on x { id: xAnim; from: 20; to: 0; duration: NiraTheme.animNormal; easing.type: Easing.OutQuint }

                Timer {
                    id: autoDismissTimer
                    interval: urgency === 0 ? root.lowTimeoutMs : root.normalTimeoutMs
                    onTriggered: notificationClient.dismiss(toast.index)
                }

                Rectangle {
                    id: toastCard
                    width: root.toastWidth
                    height: column.implicitHeight + 24
                    radius: NiraTheme.radiusMedium
                    color: NiraTheme.surface
                    border.color: urgency === 2 ? NiraTheme.accentDanger
                                : urgency === 0 ? NiraTheme.textMuted
                                : NiraTheme.glassBorder
                    border.width: 1
                    opacity: 0.96

                    // Subtle accent stripe on the left.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 4
                        color: urgency === 2 ? NiraTheme.accentDanger
                              : urgency === 0 ? NiraTheme.textMuted
                              : NiraTheme.accentPrimary
                        radius: 2
                    }

                    ColumnLayout {
                        id: column
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Image {
                                source: toast.icon.length > 0
                                    ? (toast.icon.startsWith("/") ? "file://" + toast.icon
                                                                 : "image://icon/" + toast.icon)
                                    : "image://icon/dialog-information"
                                sourceSize: Qt.size(20, 20)
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                visible: status !== Image.Error
                            }
                            Text {
                                text: toast.appName.length > 0 ? toast.appName : qsTr("Notification")
                                color: NiraTheme.textSecondary
                                font.pixelSize: 10
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            // Per-toast close button.
                            Button {
                                id: closeBtn
                                text: "\u00D7"
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                flat: true
                                onClicked: notificationClient.dismiss(toast.index)
                                background: Rectangle { color: closeBtn.hovered ? NiraTheme.glassHighlight : "transparent"; radius: 4 }
                                contentItem: Text { text: closeBtn.text; color: NiraTheme.textSecondary; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                            }
                        }

                        Text {
                            text: toast.summary
                            color: NiraTheme.textPrimary
                            font.pixelSize: 13
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            visible: text.length > 0
                        }
                        Text {
                            text: toast.body
                            color: NiraTheme.textSecondary
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            visible: text.length > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            // A "Dismiss" button is always present for accessibility.
                            Button {
                                id: dismissBtn
                                text: qsTr("Dismiss")
                                Layout.alignment: Qt.AlignRight
                                flat: true
                                onClicked: notificationClient.dismiss(toast.index)
                                contentItem: Text { text: dismissBtn.text; color: NiraTheme.accentPrimary; font.pixelSize: 11; font.bold: true }
                                background: Rectangle { color: dismissBtn.hovered ? NiraTheme.glassHighlight : "transparent"; radius: 4 }
                            }
                        }
                    }
                }

                // Hovering a toast pauses auto-dismiss so the user can read.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton  // don't steal clicks from buttons
                    onEntered: autoDismissTimer.stop()
                    onExited: {
                        if (urgency < 2) autoDismissTimer.restart()
                    }
                }
            }
        }
    }

    // "Clear all" button below the stack.
    Button {
        id: clearAllBtn
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: qsTr("Clear All")
        visible: notificationClient.unreadCount > 1
        onClicked: notificationClient.dismissAll()
        z: 100
        background: Rectangle { color: clearAllBtn.hovered ? NiraTheme.glassHighlight : NiraTheme.surface; radius: NiraTheme.radiusSmall; border.color: NiraTheme.glassBorder; border.width: 1 }
        contentItem: Text { text: clearAllBtn.text; color: NiraTheme.textSecondary; font.pixelSize: 11 }
    }
}
