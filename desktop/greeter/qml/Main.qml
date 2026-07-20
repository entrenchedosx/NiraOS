import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: greeterWindow
    width: Screen.width > 0 ? Screen.width : 1920
    height: Screen.height > 0 ? Screen.height : 1080
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "#000000"
    property string selectedUsername: ""

    Image {
        anchors.fill: parent
        source: "file:///usr/share/niraos/wallpaper-lock.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.03, 0.06, 0.60)
    }

    Rectangle {
        id: loginCard
        width: 380
        height: 440
        anchors.centerIn: parent
        radius: 16
        color: Qt.rgba(0.10, 0.10, 0.14, 0.88)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 12

            Image {
                source: "file:///usr/share/niraos/nira-logo.svg"
                sourceSize: Qt.size(64, 64)
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 64
                Layout.preferredWidth: 64
                fillMode: Image.PreserveAspectFit
                opacity: 0.9
            }

            Text {
                text: "NiraOS"
                color: "#FFFFFF"
                font.pixelSize: 24
                font.weight: Font.Light
                font.letterSpacing: 1
                Layout.alignment: Qt.AlignHCenter
                opacity: 0.9
            }

            Item { Layout.fillHeight: true }

            ListView {
                id: userList
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                clip: true
                spacing: 3
                model: userModel
                visible: userList.count > 0

                delegate: ItemDelegate {
                    width: userList.width
                    height: 48
                    highlighted: ListView.isCurrentItem

                    background: Rectangle {
                        radius: 10
                        color: highlighted ? Qt.rgba(1, 1, 1, 0.08)
                                           : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10

                        Image {
                            source: model.avatarPath
                            sourceSize: Qt.size(32, 32)
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: model.displayName || model.username
                                color: "#FFFFFF"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            Text {
                                text: model.username
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 11
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            userList.currentIndex = index
                            greeterWindow.selectedUsername = model.username
                            passwordField.forceActiveFocus()
                        }
                    }
                }
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                enabled: !greeterIPC.authenticated && (!greeterIPC.busy || greeterIPC.awaitingResponse)
                color: "#FFFFFF"
                font.pixelSize: 13
                padding: 12
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: passwordField.activeFocus ? "#00E5FF" : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }
                onAccepted: loginBtn.clicked()
            }

            Button {
                id: loginBtn
                Layout.fillWidth: true
                height: 40
                enabled: !greeterIPC.authenticated && (!greeterIPC.busy || greeterIPC.awaitingResponse)

                background: Rectangle {
                    radius: 8
                    color: loginBtn.enabled
                           ? (loginBtn.hovered ? "#7000FF" : "#5500CC")
                           : Qt.rgba(0.5, 0, 0.8, 0.25)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                contentItem: Text {
                    text: greeterIPC.authenticated ? "Starting session…"
                          : (greeterIPC.awaitingResponse ? "Continue" : "Sign In")
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (greeterIPC.awaitingResponse) {
                        greeterIPC.submitPassword(passwordField.text)
                        passwordField.clear()
                        return
                    }
                    var user = greeterWindow.selectedUsername
                    if (user === "" && userList.count > 0) {
                        var idx = userList.currentIndex >= 0 ? userList.currentIndex : 0
                        user = userModel.data(userModel.index(idx, 0), 0x0101)
                    }
                    if (user !== "") {
                        greeterWindow.selectedUsername = user
                        greeterIPC.startAuth(user, passwordField.text)
                        passwordField.clear()
                    }
                }
            }

            Text {
                id: statusText
                Layout.fillWidth: true
                text: greeterIPC.statusMessage
                color: Qt.rgba(1, 1, 1, 0.65)
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text !== ""
            }

            Item { Layout.fillHeight: true }
        }
    }

    Rectangle {
        id: fadeOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        visible: false

        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim
                duration: 500
                easing.type: Easing.InCubic
                onRunningChanged: {
                    if (!running && fadeOverlay.opacity >= 1.0)
                        greeterIPC.startSession()
                }
            }
        }
    }

    Connections {
        target: greeterIPC
        function onAuthSucceeded() {
            fadeOverlay.visible = true
            fadeOverlay.opacity = 1.0
        }
        function onAuthFailed(reason) {
            statusText.color = "#FF453A"
            passwordField.forceActiveFocus()
            passwordField.selectAll()
        }
    }

    // ── Software cursor sprite ────────────────────────────────────────────
    // The greeter runs standalone under eglfs_kms.  We draw the cursor using
    // QML primitives (a white arrow with dark outline) positioned at the
    // Window's mouseX/mouseY — these track the pointer without consuming any
    // events (unlike a MouseArea which would steal hover events from UI
    // elements below).  This approach has zero file dependencies.
    Item {
        id: cursorSprite
        x: Math.max(0, greeterWindow.mouseX)
        y: Math.max(0, greeterWindow.mouseY)
        z: 10001
        width: 20
        height: 26

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(0, 20)
                ctx.lineTo(5, 16)
                ctx.lineTo(9, 24)
                ctx.lineTo(13, 22)
                ctx.lineTo(9, 14)
                ctx.lineTo(16, 14)
                ctx.closePath()
                ctx.lineWidth = 1.2
                ctx.strokeStyle = "#1A1A1A"
                ctx.stroke()
                ctx.fillStyle = "#F0F0F0"
                ctx.fill()
                ctx.restore()
            }
            Component.onCompleted: requestPaint()
        }
    }
}
