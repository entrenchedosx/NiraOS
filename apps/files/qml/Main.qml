import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import NiraFiles

Window {
    id: root
    width: 1200
    height: 800
    minimumWidth: 700
    minimumHeight: 450
    visible: true
    title: qsTr("NiraOS Files — %1").arg(fileModel.currentPath)

    color: "#0D0D10"

    property string searchQuery: ""
    property bool searchActive: false
    property int viewMode: 0 // 0=grid, 1=list, 2=detailed
    property real gridIconSize: 96
    property var selectedPaths: []
    property var clipboardPaths: []
    property bool clipboardIsCut: false
    property string currentDir: fileModel.currentPath

    // ── Open file handler ───────────────────────────────────────────────
    Connections {
        target: fileModel
        function onOpenFileRequested(path) {
            fileOperations.openFile(path)
        }
    }

    // ── Keyboard shortcuts ──────────────────────────────────────────────
    Shortcut { sequence: "Ctrl+C"; onActivated: copySelected() }
    Shortcut { sequence: "Ctrl+X"; onActivated: cutSelected() }
    Shortcut { sequence: "Ctrl+V"; onActivated: pasteClipboard() }
    Shortcut { sequence: "Ctrl+A"; onActivated: selectAll() }
    Shortcut { sequence: "Ctrl+F"; onActivated: searchBar.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+H"; onActivated: fileModel.showHidden = !fileModel.showHidden }
    Shortcut { sequence: "Delete"; onActivated: deleteSelected() }
    Shortcut { sequence: "F2"; onActivated: renameSelected() }
    Shortcut { sequence: "F5"; onActivated: fileModel.refresh() }
    Shortcut { sequence: "Ctrl+W"; onActivated: root.close() }
    Shortcut { sequence: "Escape"; onActivated: clearSelection() }

    // ── Menu bar ────────────────────────────────────────────────────────
    MenuBar {
        id: menuBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        Menu {
            title: qsTr("File")
            Action { text: qsTr("New Folder"); icon.name: "folder-new"; onTriggered: createNewFolder() }
            Action { text: qsTr("New File"); icon.name: "document-new"; onTriggered: createNewFile() }
            MenuSeparator {}
            Action { text: qsTr("Open in Terminal"); onTriggered: fileOperations.openInTerminal(fileModel.currentPath) }
            MenuSeparator {}
            Action { text: qsTr("Close"); icon.name: "window-close"; onTriggered: root.close() }
        }

        Menu {
            title: qsTr("Edit")
            Action { text: qsTr("Cut"); icon.name: "edit-cut"; onTriggered: cutSelected() }
            Action { text: qsTr("Copy"); icon.name: "edit-copy"; onTriggered: copySelected() }
            Action { text: qsTr("Paste"); icon.name: "edit-paste"; onTriggered: pasteClipboard() }
            MenuSeparator {}
            Action { text: qsTr("Select All"); icon.name: "edit-select-all"; onTriggered: selectAll() }
            Action { text: qsTr("Invert Selection"); onTriggered: invertSelection() }
        }

        Menu {
            title: qsTr("View")
            Action { text: qsTr("Grid View"); checkable: true; checked: viewMode === 0; onTriggered: viewMode = 0 }
            Action { text: qsTr("List View"); checkable: true; checked: viewMode === 1; onTriggered: viewMode = 1 }
            Action { text: qsTr("Detailed View"); checkable: true; checked: viewMode === 2; onTriggered: viewMode = 2 }
            MenuSeparator {}
            Action { text: qsTr("Show Hidden Files"); checkable: true; onTriggered: fileModel.showHidden = checked }
        }

        Menu {
            title: qsTr("Go")
            Action { text: qsTr("Home"); icon.name: "go-home"; onTriggered: fileModel.setCurrentPath(standardPaths.home) }
            Action { text: qsTr("Documents"); onTriggered: fileModel.setCurrentPath(standardPaths.documents) }
            Action { text: qsTr("Downloads"); onTriggered: fileModel.setCurrentPath(standardPaths.downloads) }
            Action { text: qsTr("Pictures"); onTriggered: fileModel.setCurrentPath(standardPaths.pictures) }
            Action { text: qsTr("Videos"); onTriggered: fileModel.setCurrentPath(standardPaths.videos) }
            Action { text: qsTr("Music"); onTriggered: fileModel.setCurrentPath(standardPaths.music) }
            MenuSeparator {}
            Action { text: qsTr("Up"); icon.name: "go-up"; onTriggered: fileModel.navigateUp() }
            Action { text: qsTr("Back"); icon.name: "go-previous"; enabled: historyIndex > 0; onTriggered: historyBack() }
            Action { text: qsTr("Forward"); icon.name: "go-next"; enabled: historyIndex < history.length - 1; onTriggered: historyForward() }
        }

        Menu {
            title: qsTr("Help")
            Action { text: qsTr("About NiraOS Files"); onTriggered: aboutDialog.open() }
        }
    }

    // ── Toolbar ─────────────────────────────────────────────────────────
    Rectangle {
        id: toolbar
        anchors.top: menuBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: "#141418"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            // Back / Forward / Up / Refresh
            ToolButton {
                enabled: historyIndex > 0
                onClicked: historyBack()
                contentItem: Image {
                    source: "image://icon/nav-back"
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }
            }
            ToolButton {
                enabled: historyIndex < history.length - 1
                onClicked: historyForward()
                contentItem: Image {
                    source: "image://icon/nav-forward"
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }
            }
            ToolButton {
                onClicked: fileModel.navigateUp()
                contentItem: Image {
                    source: "image://icon/nav-up"
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }
            }
            ToolButton {
                onClicked: fileModel.refresh()
                contentItem: Image {
                    source: "image://icon/nav-refresh"
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }
            }

            // Breadcrumb / Address bar
            BreadcrumbBar {
                id: breadcrumbBar
                currentPath: fileModel.currentPath
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                onNavigate: (path) => fileModel.setCurrentPath(path)
            }

            // Search bar
            Rectangle {
                id: searchContainer
                Layout.preferredWidth: 240
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter
                color: "#1E1E24"
                radius: 6
                border.color: searchBar.activeFocus ? "#00E5FF" : "#2A2A30"
                border.width: 1

                TextField {
                    id: searchBar
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#F0F0F5"
                    font.pixelSize: 12
                    placeholderText: qsTr("Search...")
                    selectByMouse: true
                    background: null

                    onTextChanged: {
                        searchTimer.restart()
                    }

                    Timer {
                        id: searchTimer
                        interval: 300
                        onTriggered: {
                            if (searchBar.text.trim().length > 0) {
                                searchIndexer.search(fileModel.currentPath, searchBar.text)
                                searchActive = true
                            } else {
                                searchActive = false
                                searchIndexer.cancel()
                            }
                        }
                    }
                }
            }

            // View mode buttons
            ToolButton {
                checked: viewMode === 0
                onClicked: viewMode = 0
                contentItem: Image {
                    source: "image://icon/view-grid"
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }
            }
            ToolButton {
                checked: viewMode === 1
                onClicked: viewMode = 1
                contentItem: Image {
                    source: "image://icon/view-list"
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }
            }
            ToolButton {
                checked: viewMode === 2
                onClicked: viewMode = 2
                contentItem: Image {
                    source: "image://icon/view-detailed"
                    sourceSize: Qt.size(20, 20)
                    fillMode: Image.PreserveAspectFit
                }
            }
        }
    }

    // ── Main content area ───────────────────────────────────────────────
    RowLayout {
        anchors.top: toolbar.bottom
        anchors.bottom: statusBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // Sidebar
        Sidebar {
            id: sidebar
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            onNavigate: (path) => fileModel.setCurrentPath(path)
        }

        // Vertical divider
        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: "#1E1E24"
        }

        // File view area
        FileView {
            id: fileView
            Layout.fillWidth: true
            Layout.fillHeight: true
            viewMode: root.viewMode
            gridIconSize: root.gridIconSize
            onNavigate: (path) => fileModel.setCurrentPath(path)
            onOpenFile: (path) => fileOperations.openFile(path)
            onSelectionChanged: (paths) => root.selectedPaths = paths
        }
    }

    // ── Search results overlay ─────────────────────────────────────────
    Popup {
        id: searchPopup
        x: searchContainer.x
        y: toolbar.y + toolbar.height + 4
        width: Math.max(400, searchContainer.width)
        height: Math.min(400, fileView.height - 40)
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        visible: searchActive && searchResults.length > 0

        property var searchResults: []

        background: Rectangle {
            color: "#141418"
            radius: 8
            border.color: "#2A2A30"
            border.width: 1
        }

        contentItem: ListView {
            clip: true
            model: searchPopup.searchResults
            spacing: 2

            delegate: Rectangle {
                width: searchPopup.width
                height: 36
                color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Image {
                        source: "image://icon/" + (modelData.isDir ? "folder" : "text-x-generic")
                        sourceSize: Qt.size(20, 20)
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        Layout.alignment: Qt.AlignVCenter
                        asynchronous: true
                    }

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        Text {
                            text: modelData.name || ""
                            color: "#F0F0F5"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.path || ""
                            color: "#5A5A64"
                            font.pixelSize: 9
                            elide: Text.ElideLeft
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: modelData.sizeHuman || ""
                        color: "#8E8E98"
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.isDir)
                            fileModel.setCurrentPath(modelData.path)
                        else
                            fileOperations.openFile(modelData.path)
                        searchBar.text = ""
                        searchActive = false
                        searchPopup.visible = false
                    }
                }
            }
        }
    }

    Connections {
        target: searchIndexer
        function onResultsFound(results) {
            searchPopup.searchResults = results
            if (searchActive)
                searchPopup.open()
        }
        function onSearchFinished(cancelled) {
            if (!cancelled && searchPopup.searchResults.length === 0)
                searchPopup.close()
        }
    }

    // ── Status bar ──────────────────────────────────────────────────────
    StatusBar {
        id: statusBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        currentPath: fileModel.currentPath
        itemCount: fileModel.rowCount()
        selectedCount: root.selectedPaths.length
        viewModeText: root.viewMode === 0 ? qsTr("Grid") : root.viewMode === 1 ? qsTr("List") : qsTr("Details")
    }

    // ── Properties Dialog ───────────────────────────────────────────────
    PropertiesDialog {
        id: propertiesDialog
    }

    // ── About Dialog ────────────────────────────────────────────────────
    Dialog {
        id: aboutDialog
        modal: true
        standardButtons: Dialog.Close
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 360
        height: 280
        title: qsTr("About NiraOS Files")
        background: Rectangle {
            color: "#141418"
            radius: 12
            border.color: "#2A2A30"
            border.width: 1
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Image {
                source: "image://icon/system-file-manager"
                sourceSize: Qt.size(48, 48)
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
            }

            Text {
                text: qsTr("NiraOS Files")
                color: "#F0F0F5"
                font.pixelSize: 20
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: qsTr("Version 0.1.0")
                color: "#00E5FF"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: qsTr("A modern file manager for NiraOS")
                color: "#8E8E98"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── Go menu actions use standardPaths from C++ context property ────
    // standardPaths is a QVariantMap exposed in main.cpp with keys:
    // home, documents, downloads, pictures, videos, music, desktop, trash

    // ── History navigation ──────────────────────────────────────────────
    property var history: []
    property int historyIndex: -1

    function historyNavigate(path) {
        if (historyIndex >= 0 && historyIndex < history.length - 1) {
            history = history.slice(0, historyIndex + 1)
        }
        history.push(path)
        historyIndex = history.length - 1
        fileModel.setCurrentPath(path)
    }

    Connections {
        target: fileModel
        function onCurrentPathChanged() {
            if (history.length === 0 || history[history.length - 1] !== fileModel.currentPath) {
                history.push(fileModel.currentPath)
                historyIndex = history.length - 1
            }
            currentDir = fileModel.currentPath
        }
    }

    function historyBack() {
        if (historyIndex > 0) {
            historyIndex--
            fileModel.setCurrentPath(history[historyIndex])
        }
    }

    function historyForward() {
        if (historyIndex < history.length - 1) {
            historyIndex++
            fileModel.setCurrentPath(history[historyIndex])
        }
    }

    // ── Selection operations ────────────────────────────────────────────
    // Delegate to FileView, which owns the clipboard state and the real
    // copy/cut/paste logic. The previous stubs were empty no-ops, so the
    // Ctrl+C / Ctrl+X / Ctrl+V shortcuts did nothing.
    function copySelected() { fileView.copySelected() }
    function cutSelected() { fileView.cutSelected() }
    function pasteClipboard() { fileView.pasteClipboard() }
    function selectAll() { fileView.selectAll() }
    function clearSelection() { fileView.clearSelection() }
    function invertSelection() { fileView.invertSelection() }
    function deleteSelected() { fileView.deleteSelected() }
    function renameSelected() { fileView.renameSelected() }

    function createNewFolder() {
        fileOperations.createFolder(fileModel.currentPath, qsTr("New Folder"))
    }

    function createNewFile() {
        fileOperations.createFile(fileModel.currentPath, qsTr("New File"))
    }

    // Ensure file system watcher updates
    Connections {
        target: fileSystemWatcher
        function onDirectoryChanged(path) {
            if (path === fileModel.currentPath)
                fileModel.refresh()
        }
    }
}
