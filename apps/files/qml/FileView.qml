import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: root
    property int viewMode: 0 // 0=grid, 1=list, 2=detailed
    property real gridIconSize: 96
    property var selectedIndices: []
    property var selectedPaths: []

    signal navigate(string path)
    signal openFile(string path)
    signal selectionChanged(var paths)

    // ── Context menu ────────────────────────────────────────────────────
    Menu {
        id: contextMenu
        property string targetPath: ""
        property int targetIndex: -1

        MenuItem {
            text: qsTr("Open")
            icon.source: "qrc:/nira/icons/file-document.svg"
            onTriggered: openFile(contextMenu.targetPath)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Cut")
            icon.source: "qrc:/nira/filemanager/toolbar-copy.svg"
            onTriggered: {
                root.clipboardPaths = [contextMenu.targetPath]
                root.clipboardIsCut = true
            }
        }
        MenuItem {
            text: qsTr("Copy")
            icon.source: "qrc:/nira/filemanager/toolbar-copy.svg"
            onTriggered: {
                root.clipboardPaths = [contextMenu.targetPath]
                root.clipboardIsCut = false
            }
        }
        MenuItem {
            text: qsTr("Paste")
            icon.source: "qrc:/nira/filemanager/toolbar-paste.svg"
            enabled: root.clipboardPaths.length > 0
            onTriggered: root.pasteTo(contextMenu.targetPath)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Rename")
            icon.source: "qrc:/nira/filemanager/toolbar-rename.svg"
            onTriggered: root.startRename(contextMenu.targetIndex)
        }
        MenuItem {
            text: qsTr("Delete")
            icon.source: "qrc:/nira/filemanager/toolbar-delete.svg"
            onTriggered: root.deletePath(contextMenu.targetPath)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Properties")
            icon.source: "qrc:/nira/icons/file-document.svg"
            onTriggered: propertiesDialog.showForPath(contextMenu.targetPath)
        }
    }

    // ── Grid View ───────────────────────────────────────────────────────
    GridView {
        id: gridView
        visible: viewMode === 0
        anchors.fill: parent
        anchors.margins: 8
        cellWidth: gridIconSize + 32
        cellHeight: gridIconSize + 48
        clip: true
        model: fileModel
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: gridDelegate
            width: gridView.cellWidth
            height: gridView.cellHeight

            property bool isSelected: root.selectedIndices.includes(index)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: gridDelegate.isSelected ? Qt.rgba(0, 0.898, 1, 0.10)
                                               : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                radius: 8
                border.color: gridDelegate.isSelected ? "#00E5FF" : "transparent"
                border.width: gridDelegate.isSelected ? 1 : 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Item { Layout.fillHeight: true }

                    Image {
                        id: thumbImage
                        Layout.alignment: Qt.AlignHCenter
                        source: model.thumbnail ? model.thumbnail : "image://icon/" + model.iconName
                        sourceSize: Qt.size(Math.min(root.gridIconSize, 64), Math.min(root.gridIconSize, 64))
                        width: Math.min(root.gridIconSize, 64)
                        height: Math.min(root.gridIconSize, 64)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        text: model.fileName
                        color: gridDelegate.isSelected ? "#00E5FF" : "#F0F0F5"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.formatSize(model.fileSize)
                        color: "#5A5A64"
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                        visible: model.fileType === "file"
                    }

                    Item { Layout.fillHeight: true }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            contextMenu.targetPath = model.filePath
                            contextMenu.targetIndex = index
                            contextMenu.popup()
                            return
                        }

                        if (mouse.modifiers & Qt.ControlModifier) {
                            root.toggleSelection(index)
                        } else if (mouse.modifiers & Qt.ShiftModifier) {
                            root.rangeSelection(index)
                        } else {
                            root.clearSelection()
                            root.toggleSelection(index)
                        }
                    }

                    onDoubleClicked: {
                        if (model.fileType === "directory")
                            root.navigate(model.filePath)
                        else
                            root.openFile(model.filePath)
                    }
                }
            }
        }
    }

    // ── List View ───────────────────────────────────────────────────────
    ListView {
        id: listView
        visible: viewMode === 1
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        model: fileModel
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: listDelegate
            width: listView.width
            height: 36
            color: isSelected ? Qt.rgba(0, 0.898, 1, 0.08)
                              : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
            radius: 4

            property bool isSelected: root.selectedIndices.includes(index)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Image {
                    source: model.thumbnail ? model.thumbnail : "image://icon/" + model.iconName
                    sourceSize: Qt.size(24, 24)
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    asynchronous: true
                }

                Text {
                    text: model.fileName
                    color: isSelected ? "#00E5FF" : "#F0F0F5"
                    font.pixelSize: 12
                    font.weight: model.fileType === "directory" ? Font.Bold : Font.Normal
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.formatSize(model.fileSize)
                    color: "#8E8E98"
                    font.pixelSize: 11
                    Layout.preferredWidth: 80
                    Layout.alignment: Qt.AlignVCenter
                    visible: model.fileType === "file"
                }

                Text {
                    text: model.lastModified ? Qt.formatDateTime(model.lastModified, "yyyy-MM-dd hh:mm") : ""
                    color: "#8E8E98"
                    font.pixelSize: 11
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        contextMenu.targetPath = model.filePath
                        contextMenu.targetIndex = index
                        contextMenu.popup()
                        return
                    }
                    if (mouse.modifiers & Qt.ControlModifier) {
                        root.toggleSelection(index)
                    } else if (mouse.modifiers & Qt.ShiftModifier) {
                        root.rangeSelection(index)
                    } else {
                        root.clearSelection()
                        root.toggleSelection(index)
                    }
                }

                onDoubleClicked: {
                    if (model.fileType === "directory")
                        root.navigate(model.filePath)
                    else
                        root.openFile(model.filePath)
                }
            }
        }
    }

    // ── Detailed Table View ─────────────────────────────────────────────
    TableView {
        id: tableView
        visible: viewMode === 2
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        model: fileModel
        boundsBehavior: Flickable.StopAtBounds
        columnWidthProvider: function(column) {
            switch (column) {
                case 0: return 300  // Name
                case 1: return 100  // Size
                case 2: return 180  // Type
                case 3: return 160  // Modified
                default: return 80
            }
        }

        delegate: Rectangle {
            id: tableDelegate
            height: 32
            color: isSelected ? Qt.rgba(0, 0.898, 1, 0.08)
                              : (marea.containsMouse ? Qt.rgba(1, 1, 1, 0.03) : "transparent")

            property bool isSelected: root.selectedIndices.includes(index)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                spacing: 8

                // Name column
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 280
                    spacing: 6

                    Image {
                        source: model.thumbnail ? model.thumbnail : "image://icon/" + model.iconName
                        sourceSize: Qt.size(20, 20)
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        Layout.alignment: Qt.AlignVCenter
                        asynchronous: true
                    }

                    Text {
                        text: model.fileName
                        color: isSelected ? "#00E5FF" : "#F0F0F5"
                        font.pixelSize: 11
                        font.weight: model.fileType === "directory" ? Font.Bold : Font.Normal
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // Size column
                Text {
                    text: model.fileType === "directory" ? "—" : root.formatSize(model.fileSize)
                    color: "#8E8E98"
                    font.pixelSize: 11
                    Layout.preferredWidth: 90
                    Layout.alignment: Qt.AlignVCenter
                }

                // Type column
                Text {
                    text: model.mimeType ? model.mimeType.split("/")[1] || model.mimeType : model.fileType
                    color: "#8E8E98"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.preferredWidth: 170
                    Layout.alignment: Qt.AlignVCenter
                }

                // Modified column
                Text {
                    text: model.lastModified ? Qt.formatDateTime(model.lastModified, "yyyy-MM-dd hh:mm") : ""
                    color: "#8E8E98"
                    font.pixelSize: 11
                    Layout.preferredWidth: 150
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                id: marea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        contextMenu.targetPath = model.filePath
                        contextMenu.targetIndex = index
                        contextMenu.popup()
                        return
                    }
                    if (mouse.modifiers & Qt.ControlModifier)
                        root.toggleSelection(index)
                    else if (mouse.modifiers & Qt.ShiftModifier)
                        root.rangeSelection(index)
                    else {
                        root.clearSelection()
                        root.toggleSelection(index)
                    }
                }

                onDoubleClicked: {
                    if (model.fileType === "directory")
                        root.navigate(model.filePath)
                    else
                        root.openFile(model.filePath)
                }
            }
        }
    }

    // ── Loading indicator ───────────────────────────────────────────────
    BusyIndicator {
        id: busyIndicator
        anchors.centerIn: parent
        running: fileModel.loading
        visible: running
    }

    // ── Empty state ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        visible: fileModel.rowCount() === 0 && !fileModel.loading
        spacing: 8

        Text {
            text: qsTr("This folder is empty")
            color: "#5A5A64"
            font.pixelSize: 16
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: qsTr("Press Ctrl+N to create a new folder")
            color: "#3A3A44"
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // ── Selection management ────────────────────────────────────────────
    function toggleSelection(index) {
        var pos = selectedIndices.indexOf(index)
        if (pos >= 0) {
            selectedIndices.splice(pos, 1)
        } else {
            selectedIndices.push(index)
        }
        updateSelectedPaths()
    }

    function rangeSelection(index) {
        if (selectedIndices.length === 0) {
            toggleSelection(index)
            return
        }
        var last = selectedIndices[selectedIndices.length - 1]
        var start = Math.min(last, index)
        var end = Math.max(last, index)
        for (var i = start; i <= end; i++) {
            if (!selectedIndices.includes(i))
                selectedIndices.push(i)
        }
        updateSelectedPaths()
    }

    function selectAll() {
        selectedIndices = []
        for (var i = 0; i < fileModel.rowCount(); i++)
            selectedIndices.push(i)
        updateSelectedPaths()
    }

    function clearSelection() {
        selectedIndices = []
        updateSelectedPaths()
    }

    function invertSelection() {
        var newSelection = []
        for (var i = 0; i < fileModel.rowCount(); i++) {
            if (!selectedIndices.includes(i))
                newSelection.push(i)
        }
        selectedIndices = newSelection
        updateSelectedPaths()
    }

    function updateSelectedPaths() {
        var paths = []
        for (var i = 0; i < selectedIndices.length; i++) {
            var idx = selectedIndices[i]
            if (idx >= 0 && idx < fileModel.rowCount())
                paths.push(fileModel.fileInfoAt(idx).filePath)
        }
        selectedPaths = paths
        selectionChanged(paths)
    }

    function deleteSelected() {
        for (var i = 0; i < selectedPaths.length; i++)
            fileOperations.delete_(selectedPaths[i], false)
    }

    function renameSelected() {
        if (selectedIndices.length === 1)
            startRename(selectedIndices[0])
    }

    function startRename(index) {
        // Can't easily do inline rename without a TextInput overlay,
        // so we use a dialog approach
        renameDialog.targetIndex = index
        renameDialog.oldName = fileModel.fileInfoAt(index).fileName
        renameDialog.open()
    }

    function deletePath(path) {
        fileOperations.delete_(path, false)
    }

    property var clipboardPaths: []
    property bool clipboardIsCut: false

    // Clipboard operations driven by both the context menu and the keyboard
    // shortcuts in Main.qml. Previously these existed only on the context-menu
    // path, so Ctrl+C / Ctrl+X / Ctrl+V were silent no-ops.
    function copySelected() {
        clipboardPaths = selectedPaths.slice()
        clipboardIsCut = false
    }

    function cutSelected() {
        clipboardPaths = selectedPaths.slice()
        clipboardIsCut = true
    }

    function pasteClipboard() {
        // Paste into the currently-displayed directory.
        pasteTo(fileModel.currentPath)
    }

    function pasteTo(path) {
        for (var i = 0; i < clipboardPaths.length; i++) {
            if (clipboardIsCut)
                fileOperations.move(clipboardPaths[i], path)
            else
                fileOperations.copy(clipboardPaths[i], path)
        }
        if (clipboardIsCut) {
            clipboardPaths = []
            clipboardIsCut = false
        }
    }

    // ── Rename Dialog ───────────────────────────────────────────────────
    Dialog {
        id: renameDialog
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 400
        title: qsTr("Rename")
        property int targetIndex: -1
        property string oldName: ""

        background: Rectangle {
            color: "#141418"
            radius: 12
            border.color: "#2A2A30"
            border.width: 1
        }

        TextField {
            id: renameField
            text: renameDialog.oldName
            selectByMouse: true
            color: "#F0F0F5"
            font.pixelSize: 13
            background: Rectangle {
                color: "#1E1E24"
                radius: 6
                border.color: renameField.activeFocus ? "#00E5FF" : "#2A2A30"
                border.width: 1
            }
        }

        onOpened: {
            renameField.text = renameDialog.oldName
            renameField.selectAll()
            renameField.forceActiveFocus()
        }

        onAccepted: {
            if (renameField.text.length > 0 && renameField.text !== renameDialog.oldName) {
                var info = fileModel.fileInfoAt(renameDialog.targetIndex)
                if (info)
                    fileOperations.rename(info.filePath, renameField.text)
            }
        }
    }

    // ── Format helper ───────────────────────────────────────────────────
    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return "0 B"
        if (bytes < 1024) return bytes + " B"
        var kb = bytes / 1024
        if (kb < 1024) return kb.toFixed(1) + " KB"
        var mb = kb / 1024
        if (mb < 1024) return mb.toFixed(1) + " MB"
        var gb = mb / 1024
        return gb.toFixed(2) + " GB"
    }
}
