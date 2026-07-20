import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NiraOS

// NiraOS Application Launcher (Start Menu).
//
// The launcher is anchored to the top-left under the Start button.  It opens
// with a search-first UX (type to filter, Enter to launch the top result),
// and adds a grid/list toggle and keyboard navigation.  Click-outside and Esc
// both close the launcher.

Item {
    id: root
    width: 560
    height: 520

    // Anchored below the Start button in Main.qml via parent positioning.
    scale: visible ? 1.0 : 0.92
    opacity: visible ? 1.0 : 0.0
    Behavior on scale { NumberAnimation { duration: NiraTheme.animNormal; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: NiraTheme.animFast; easing.type: Easing.OutQuad } }

    property bool gridView: false

    // Click-outside-to-close handler.  Main.qml positions the launcher; the
    // MouseArea below is enabled only when the launcher is visible and lies
    // behind it (z = -1) so clicks on the launcher itself are not stolen.
    MouseArea {
        id: outsideClick
        anchors.fill: parent
        enabled: root.visible
        z: -1
        onClicked: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: NiraTheme.surface
        radius: NiraTheme.radiusLarge
        border.color: NiraTheme.glassBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: NiraTheme.paddingMedium
            spacing: NiraTheme.paddingSmall

            // ── Search + view-toggle row ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: NiraTheme.paddingSmall

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search applications\u2026")
                    color: NiraTheme.textPrimary
                    font.pixelSize: 16
                    padding: 10
                    leftPadding: 14
                    background: Rectangle {
                        color: NiraTheme.background
                        radius: NiraTheme.radiusMedium
                        border.color: searchField.activeFocus ? NiraTheme.accentPrimary : NiraTheme.glassBorder
                        border.width: searchField.activeFocus ? 1.5 : 1
                        Behavior on border.color { ColorAnimation { duration: NiraTheme.animQuick } }
                        Behavior on border.width { NumberAnimation { duration: NiraTheme.animQuick } }
                    }

                    onTextChanged: debounceTimer.restart()
                    Keys.onEscapePressed: root.visible = false

                    Timer {
                        id: debounceTimer
                        interval: 150
                        onTriggered: appModel.filter = searchField.text
                    }

                    onVisibleChanged: { if (visible) { forceActiveFocus(); text = "" } }
                }

                Button {
                    id: viewToggle
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    flat: true
                    onClicked: root.gridView = !root.gridView
                    background: Rectangle { color: viewToggle.hovered ? NiraTheme.glassHighlight : "transparent"; radius: NiraTheme.radiusSmall }
                    contentItem: Text {
                        text: root.gridView ? "\u2630" : "\u25A6"
                        color: NiraTheme.textPrimary
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: root.gridView ? qsTr("Switch to list view") : qsTr("Switch to grid view")
                }
            }

            // ── Results: grid OR list ───────────────────────────────────
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.gridView ? 1 : 0

                // List view (default).
                ListView {
                    id: appListView
                    clip: true
                    spacing: 1
                    model: appModel
                    currentIndex: 0

                    Keys.onDownPressed: { if (currentIndex < model.rowCount() - 1) currentIndex++ }
                    Keys.onUpPressed:   { if (currentIndex > 0) currentIndex-- }
                    Keys.onReturnPressed: launchCurrent()
                    Keys.onEscapePressed: root.visible = false

                    delegate: ItemDelegate {
                        width: appListView.width
                        height: 44
                        highlighted: ListView.isCurrentItem

                        background: Rectangle {
                            color: highlighted ? NiraTheme.glassHighlight : (hovered ? Qt.rgba(1,1,1,0.06) : "transparent")
                            radius: NiraTheme.radiusSmall
                            Behavior on color { ColorAnimation { duration: NiraTheme.animMicro } }
                        }

                        contentItem: RowLayout {
                            spacing: NiraTheme.paddingSmall
                            anchors.leftMargin: 6

                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: {
                                        var icon = model.iconName
                                        if (icon.startsWith("/"))
                                            return "file://" + icon
                                        return "image://icon/" + icon
                                    }
                                    sourceSize: Qt.size(28, 28)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status !== Image.Error
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: (model.name || "?").charAt(0).toUpperCase()
                                    color: NiraTheme.textMuted
                                    font.pixelSize: 14
                                    font.bold: true
                                    visible: appIcon.status === Image.Error || model.iconName === ""
                                }
                            }

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: model.name || ""
                                    color: NiraTheme.textPrimary
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.genericName || ""
                                    color: NiraTheme.textMuted
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        onClicked: {
                            appListView.currentIndex = index
                            launchCurrent()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: appModel.filter !== ""
                            ? qsTr("No results for \"%1\"").arg(appModel.filter)
                            : qsTr("Start typing to search")
                        color: NiraTheme.textMuted
                        font.pixelSize: 12
                        visible: appListView.count === 0
                    }
                }

                // Grid view (toggle on).
                GridView {
                    id: appGrid
                    clip: true
                    cellWidth: 110
                    cellHeight: 110
                    model: appModel
                    currentIndex: 0

                    Keys.onDownPressed: { if (currentIndex < model.rowCount() - 1) currentIndex++ }
                    Keys.onUpPressed:   { if (currentIndex > 0) currentIndex-- }
                    Keys.onReturnPressed: launchCurrent()
                    Keys.onEscapePressed: root.visible = false

                    delegate: Item {
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight
                        required property int index

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            color: GridView.isCurrentItem ? NiraTheme.glassHighlight
                                  : (gridMa.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                            radius: NiraTheme.radiusSmall
                            Behavior on color { ColorAnimation { duration: NiraTheme.animMicro } }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            Image {
                                id: gridIcon
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                source: {
                                    var icon = model.iconName
                                    if (icon.startsWith("/")) return "file://" + icon
                                    return "image://icon/" + icon
                                }
                                sourceSize: Qt.size(48, 48)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status !== Image.Error
                            }
                            Text {
                                Layout.fillWidth: true
                                text: model.name || ""
                                color: NiraTheme.textPrimary
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                visible: gridIcon.status !== Image.Error || model.iconName !== ""
                            }
                        }

                        MouseArea {
                            id: gridMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                appGrid.currentIndex = parent.index
                                launchCurrent()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: appModel.filter !== ""
                            ? qsTr("No results for \"%1\"").arg(appModel.filter)
                            : qsTr("Start typing to search")
                        color: NiraTheme.textMuted
                        font.pixelSize: 12
                        visible: appGrid.count === 0
                    }
                }
            }
        }
    }

    function launchCurrent() {
        var idx = root.gridView ? appGrid.currentIndex : appListView.currentIndex
        if (idx < 0) return
        var exec = appModel.execAt(idx)
        if (typeof processLauncher !== "undefined" && exec !== "") {
            processLauncher.launch(exec)
        }
        root.visible = false
    }
}
