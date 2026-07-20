import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

// NiraOS Settings — two-pane glassmorphism control panel.
// Talks to the Rust settings-service via gRPC (through SettingsClient C++).

Window {
    id: settingsWindow
    width: 900
    height: 600
    minimumWidth: 700
    minimumHeight: 450
    visible: true
    title: "NiraOS Settings"
    color: "#0D0D10"

    // ── Page stack ──────────────────────────────────────────────────────
    property int currentPage: 0
    readonly property var pageNames: ["Appearance", "Network", "Displays", "Audio", "About"]

    // ── Root layout ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#0D0D10"

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── Sidebar ─────────────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: Qt.rgba(0.08, 0.08, 0.10, 0.90)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 24
                    spacing: 4

                    // Header
                    Text {
                        text: "Settings"
                        color: "#FFFFFF"
                        font.pixelSize: 20
                        font.weight: Font.Light
                        Layout.leftMargin: 20
                        Layout.bottomMargin: 16
                    }

                    // Navigation items with icons
                    Repeater {
                        model: [
                            { name: "Appearance", icon: "preferences-desktop" },
                            { name: "Network",    icon: "network" },
                            { name: "Displays",   icon: "desktop" },
                            { name: "Audio",      icon: "audio-speakers" },
                            { name: "About",      icon: "preferences-system" }
                        ]

                        Rectangle {
                            id: navItem
                            width: parent.width
                            height: 40
                            color: index === settingsWindow.currentPage
                                ? Qt.rgba(0, 0.898, 1, 0.10)
                                : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                            radius: 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                spacing: 10

                                Image {
                                    source: "image://icon/" + modelData.icon
                                    sourceSize: Qt.size(18, 18)
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    Layout.alignment: Qt.AlignVCenter
                                    asynchronous: true
                                }

                                Text {
                                    text: modelData.name
                                    color: index === settingsWindow.currentPage ? "#00E5FF" : "#AAAAAA"
                                    font.pixelSize: 14
                                    font.weight: index === settingsWindow.currentPage ? Font.Medium : Font.Normal
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    for (var i = 0; i < settingsWindow.pageNames.length; i++) {
                                        if (settingsWindow.pageNames[i] === modelData.name) {
                                            settingsWindow.currentPage = i
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Version footer
                    Text {
                        text: "NiraOS Core v1.0"
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.pixelSize: 11
                        Layout.leftMargin: 20
                        Layout.bottomMargin: 20
                    }
                }
            }

            // ── Content area ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#121216"

                clip: true

                // Page content — stack via opacity
                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    anchors.margins: 32
                    sourceComponent: {
                        switch (settingsWindow.currentPage) {
                        case 0: return appearancePage
                        case 1: return networkPage
                        case 2: return displayPage
                        case 3: return audioPage
                        case 4: return aboutPage
                        default: return appearancePage
                        }
                    }
                }
            }
        }
    }

    // ── Appearance page ─────────────────────────────────────────────────
    Component {
        id: appearancePage
        ColumnLayout {
            spacing: 20

            Text { text: "Appearance"; color: "#FFFFFF"; font.pixelSize: 22; font.weight: Font.Light }

            // Dark Mode toggle
            Rectangle {
                Layout.fillWidth: true
                height: 60
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    Text { text: "Dark Mode"; color: "#DDDDDD"; font.pixelSize: 14 }
                    Item { Layout.fillWidth: true }
                    Switch {
                        checked: true
                        onCheckedChanged: settingsClient.setSetting("appearance.darkMode", checked ? "true" : "false")
                    }
                }
            }

            // Accent Color selector
            Rectangle {
                Layout.fillWidth: true
                height: 60
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    Text { text: "Accent Color"; color: "#DDDDDD"; font.pixelSize: 14 }
                    Item { Layout.fillWidth: true }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: ["#00E5FF", "#7000FF", "#FF5555", "#FFAA00", "#00CC66"]
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: modelData
                                border.width: modelData === "#00E5FF" ? 2 : 0
                                border.color: "#FFFFFF"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsClient.setSetting("appearance.accentColor", modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Placeholder pages ───────────────────────────────────────────────
    Component {
        id: networkPage
        ColumnLayout {
            spacing: 20
            Text { text: "Network"; color: "#FFFFFF"; font.pixelSize: 22; font.weight: Font.Light }
            Text { text: "Network settings will be available in a future update."; color: "#888888"; font.pixelSize: 13 }
        }
    }

    Component {
        id: displayPage
        ColumnLayout {
            spacing: 20
            Text { text: "Displays"; color: "#FFFFFF"; font.pixelSize: 22; font.weight: Font.Light }
            Text { text: "Display configuration will be available in a future update."; color: "#888888"; font.pixelSize: 13 }
        }
    }

    Component {
        id: audioPage
        ColumnLayout {
            spacing: 20
            Text { text: "Audio"; color: "#FFFFFF"; font.pixelSize: 22; font.weight: Font.Light }
            Text { text: "Audio settings will be available in a future update."; color: "#888888"; font.pixelSize: 13 }
        }
    }

    Component {
        id: aboutPage
        ColumnLayout {
            spacing: 16

            Image {
                source: "qrc:/nira/icons/nira-logo.svg"
                sourceSize: Qt.size(64, 64)
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                fillMode: Image.PreserveAspectFit
            }

            Text { text: "NiraOS"; color: "#FFFFFF"; font.pixelSize: 24; font.weight: Font.Light }
            Text { text: "Core v1.0"; color: "#00E5FF"; font.pixelSize: 14 }
            Text { text: "An AI-native Linux operating system."; color: "#888888"; font.pixelSize: 13; Layout.topMargin: 8 }
            Text {
                text: "NiraOS combines a Qt6/Wayland compositor with a suite of Rust daemons\nproviding AI-powered desktop capabilities."
                color: "#666666"; font.pixelSize: 11; Layout.topMargin: 4
            }
        }
    }
}
