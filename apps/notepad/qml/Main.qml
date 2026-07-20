import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window

// NiraOS Notepad — multi-tab editor with find/replace, line numbers,
// auto-save, recent files, drag & drop, and per-language syntax highlighting.
//
// Architecture: the tab bar is driven by a ListModel (title + modified marker
// only). The *current document state* lives in reactive root properties
// (docPath, docModified, docLanguage, docAutoSave, docSavedContent). Switching
// tabs flushes the editor text into the model and loads the new tab's text.
// Root properties are updated explicitly on every change so QML bindings
// (window title, status bar, auto-save timer, menu checks) stay correct —
// ListModel.get() element properties do NOT emit change notifications, so
// binding directly to them would silently break.

ApplicationWindow {
    id: root
    width: 900
    height: 640
    visible: true
    minimumWidth: 480
    minimumHeight: 320
    title: docModified
        ? qsTr("%1 \u2014 Nira Notepad \u2022").arg(docTitle)
        : qsTr("%1 \u2014 Nira Notepad").arg(docTitle)
    color: "#0D0D10"

    // ── Reactive current-document state ───────────────────────────────
    property string docPath: ""
    property string docTitle: qsTr("Untitled")
    property string docSavedContent: ""
    property bool docModified: false
    property string docLanguage: ""
    property bool docAutoSave: false
    property int pendingCloseIndex: -1

    // ── Tab model (display only: title + modified marker + saved text) ─
    ListModel { id: tabs }
    readonly property int currentTabIndex: tabBar.currentIndex

    function fileTitleFromPath(path) {
        if (!path || path.length === 0) return qsTr("Untitled")
        const parts = path.split("/")
        return parts[parts.length - 1] || qsTr("Untitled")
    }

    // ── Tab lifecycle ─────────────────────────────────────────────────
    // loadedTabIndex records which tab is currently rendered in the editor.
    // TabBar.onCurrentIndexChanged fires AFTER the index has changed, so we
    // use loadedTabIndex to flush the editor back into the tab we're leaving
    // before loading the newly-selected tab.
    property int loadedTabIndex: -1
    property bool loadingProgrammatic: false

    function flushEditorToModel(idx) {
        if (idx < 0 || idx >= tabs.count) return
        const editorText = editor.text
        const t = tabs.get(idx)
        const modified = editorText !== t.savedContent
        tabs.setProperty(idx, "savedContent", editorText)
        tabs.setProperty(idx, "modified", modified)
    }

    function syncRootFromTab(idx) {
        const t = tabs.get(idx)
        docPath = t.filePath
        docTitle = t.title
        docSavedContent = t.savedContent
        docModified = t.modified
        docLanguage = t.language
        docAutoSave = t.autoSaveEnabled
    }

    function loadEditorFromCurrent() {
        const idx = tabBar.currentIndex
        if (idx < 0 || idx >= tabs.count) return
        const t = tabs.get(idx)
        loadingProgrammatic = true
        editor.text = t.savedContent
        loadingProgrammatic = false
        syncRootFromTab(idx)
        attachHighlighter(docLanguage)
        updateLineNumbers()
        editor.cursorPosition = 0
        editorFlick.contentY = 0
        editorFlick.contentX = 0
        loadedTabIndex = idx
    }

    function newTab(path, content) {
        const lang = fileDialogHelper.languageForFile(path || "")
        tabs.append({
            filePath: path || "",
            title: fileTitleFromPath(path || ""),
            savedContent: content || "",
            modified: false,
            language: lang,
            autoSaveEnabled: (path && path.length > 0)
        })
        // Setting the index triggers onCurrentIndexChanged, which flushes the
        // old tab and loads the new one.
        tabBar.currentIndex = tabs.count - 1
        if (path && path.length > 0)
            fileDialogHelper.addRecentFile(path)
    }

    function closeTab(index) {
        if (index < 0 || index >= tabs.count) return
        // Bring the target tab into view so the user sees what they close.
        if (tabBar.currentIndex !== index) {
            tabBar.currentIndex = index
        }
        const t = tabs.get(index)
        if (t.modified) {
            pendingCloseIndex = index
            unsavedDialog.open()
            return
        }
        removeTabImmediately(index)
    }

    function removeTabImmediately(index) {
        if (tabs.count === 0) return
        tabs.remove(index)
        loadedTabIndex = -1
        if (tabs.count === 0) {
            newTab("", "")
        } else {
            tabBar.currentIndex = Math.min(index, tabs.count - 1)
        }
        pendingCloseIndex = -1
    }

    // ── Syntax highlighting ───────────────────────────────────────────
    property var _highlighter: null
    function attachHighlighter(language) {
        if (!editor.textDocument) return
        if (language && language.length > 0) {
            if (_highlighter) {
                // Reuse the existing highlighter to avoid leaking
                // QSyntaxHighlighter instances on every tab switch.
                _highlighter.reconfigure(language)
            } else {
                _highlighter = fileDialogHelper.createHighlighter(editor.textDocument, language)
            }
        }
        // For unknown languages the highlighter simply has no rules; we keep
        // the instance attached so switching back to a known language works.
    }

    // ── Line numbers ──────────────────────────────────────────────────
    ListModel { id: lineModel }
    function updateLineNumbers() {
        const lines = editor.text.split("\n").length
        lineModel.clear()
        for (let i = 1; i <= lines; ++i)
            lineModel.append({ number: i })
    }

    // ── File operations ───────────────────────────────────────────────
    function openPath(path, force) {
        const res = fileDialogHelper.readFile(path)
        if (!res.success) {
            if (res.too_large === true && force !== true) {
                largeFileDialog.filePath = path
                largeFileDialog.open()
                return
            }
            errorDialog.message = res.error || qsTr("Could not open the file.")
            errorDialog.open()
            return
        }
        // Reuse a fresh Untitled unmodified tab; otherwise open a new tab.
        if (tabs.count > 0) {
            const t = tabs.get(tabBar.currentIndex)
            if (t.filePath === "" && !t.modified) {
                tabs.setProperty(tabBar.currentIndex, "filePath", path)
                tabs.setProperty(tabBar.currentIndex, "title", fileTitleFromPath(path))
                tabs.setProperty(tabBar.currentIndex, "savedContent", res.content)
                tabs.setProperty(tabBar.currentIndex, "modified", false)
                tabs.setProperty(tabBar.currentIndex, "language", fileDialogHelper.languageForFile(path))
                tabs.setProperty(tabBar.currentIndex, "autoSaveEnabled", true)
                loadEditorFromCurrent()
                fileDialogHelper.addRecentFile(path)
                return
            }
        }
        newTab(path, res.content)
    }

    function saveCurrent() {
        if (tabs.count === 0) return
        if (docPath.length === 0) {
            saveAsDialog.open()
            return
        }
        const ok = fileDialogHelper.writeFile(docPath, editor.text)
        if (ok) {
            const idx = tabBar.currentIndex
            tabs.setProperty(idx, "savedContent", editor.text)
            tabs.setProperty(idx, "modified", false)
            docSavedContent = editor.text
            docModified = false
            fileDialogHelper.addRecentFile(docPath)
        }
    }

    function saveCurrentAs(path) {
        const ok = fileDialogHelper.writeFile(path, editor.text)
        if (ok) {
            const idx = tabBar.currentIndex
            tabs.setProperty(idx, "filePath", path)
            tabs.setProperty(idx, "title", fileTitleFromPath(path))
            tabs.setProperty(idx, "savedContent", editor.text)
            tabs.setProperty(idx, "modified", false)
            tabs.setProperty(idx, "language", fileDialogHelper.languageForFile(path))
            tabs.setProperty(idx, "autoSaveEnabled", true)
            docPath = path
            docTitle = fileTitleFromPath(path)
            docSavedContent = editor.text
            docModified = false
            docLanguage = fileDialogHelper.languageForFile(path)
            docAutoSave = true
            attachHighlighter(docLanguage)
            fileDialogHelper.addRecentFile(path)
        }
    }

    // ── Find / Replace ────────────────────────────────────────────────
    property string findText: ""
    property string replaceText: ""

    function findNext() {
        if (findText.length === 0) return
        const hay = editor.text.toLowerCase()
        const needle = findText.toLowerCase()
        let from = editor.cursorPosition + 1
        let idx = hay.indexOf(needle, from)
        if (idx < 0) idx = hay.indexOf(needle, 0) // wrap
        if (idx >= 0) {
            editor.select(idx, idx + findText.length)
            editor.forceActiveFocus()
        }
    }

    function replaceOne() {
        if (findText.length === 0) return
        if (editor.selectedText === findText) {
            editor.remove(editor.selectionStart, editor.selectionEnd)
            editor.insert(editor.cursorPosition, replaceText)
        }
        findNext()
    }

    function replaceAll() {
        if (findText.length === 0) return
        const replaced = editor.text.split(findText).join(replaceText)
        editor.text = replaced
    }

    // Called on every editor text change.
    function markModified() {
        if (loadingProgrammatic) return
        const changed = editor.text !== docSavedContent
        if (changed !== docModified) {
            docModified = changed
            tabs.setProperty(tabBar.currentIndex, "modified", changed)
        }
        updateLineNumbers()
    }

    // ── Status-bar helpers ────────────────────────────────────────────
    function wordCount() {
        const t = editor.text.trim()
        if (t.length === 0) return 0
        return t.split(/\s+/).length
    }

    function currentLineNumber() {
        const upto = editor.text.substring(0, editor.cursorPosition)
        return upto.split("\n").length
    }

    // ── Recent files ──────────────────────────────────────────────────
    ListModel { id: recentModel }
    function refreshRecentMenu() {
        recentModel.clear()
        const list = fileDialogHelper.recentFiles()
        for (let i = 0; i < list.length; ++i) {
            const p = list[i]
            if (fileDialogHelper.fileExists(p))
                recentModel.append({ path: p, name: fileTitleFromPath(p) })
        }
    }

    // ── Startup ───────────────────────────────────────────────────────
    Component.onCompleted: {
        if (initialFile && initialFile.length > 0)
            openPath(initialFile)
        else
            newTab("", "")
        refreshRecentMenu()
    }

    // ── C++ signal surface ────────────────────────────────────────────
    Connections {
        target: fileDialogHelper
        function onErrorOccurred(msg) {
            errorDialog.message = msg
            errorDialog.open()
        }
        function onRecentFilesChanged() {
            refreshRecentMenu()
        }
    }

    // ── Dialogs ───────────────────────────────────────────────────────
    MessageDialog {
        id: errorDialog
        title: qsTr("Nira Notepad")
        text: message
        property string message: ""
        buttons: MessageDialog.Ok
    }

    MessageDialog {
        id: largeFileDialog
        title: qsTr("Large File")
        text: message
        property string message: ""
        property string filePath: ""
        buttons: MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function(button) {
            if (button === MessageDialog.Yes)
                openPath(filePath, true)
        }
    }

    Dialog {
        id: unsavedDialog
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 420
        height: 140
        title: qsTr("Unsaved Changes")
        background: Rectangle { color: "#141418"; radius: 12; border.color: "#2A2A30"; border.width: 1 }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            Label {
                Layout.fillWidth: true
                color: "#F0F0F5"
                font.pixelSize: 13
                text: qsTr("This document has unsaved changes. Save before closing?")
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button {
                    text: qsTr("Cancel")
                    onClicked: { pendingCloseIndex = -1; unsavedDialog.reject() }
                }
                Button {
                    text: qsTr("Discard")
                    onClicked: {
                        const idx = pendingCloseIndex
                        pendingCloseIndex = -1
                        unsavedDialog.close()
                        if (idx >= 0) removeTabImmediately(idx)
                    }
                }
                Button {
                    text: qsTr("Save")
                    highlighted: true
                    onClicked: {
                        const idx = pendingCloseIndex
                        if (docPath.length === 0) {
                            // No path yet: route through Save As and keep the
                            // tab open so the user is not prompted again until
                            // they explicitly close it after saving.
                            pendingCloseIndex = -1
                            unsavedDialog.close()
                            saveAsDialog.open()
                            return
                        }
                        saveCurrent()
                        unsavedDialog.close()
                        if (idx >= 0) removeTabImmediately(idx)
                    }
                }
            }
        }
        onRejected: pendingCloseIndex = -1
    }

    FileDialog {
        id: openDialog
        title: qsTr("Open File")
        onAccepted: {
            const path = openDialog.selectedFile.toString().replace("file:///", "/")
            openPath(path)
        }
    }

    FileDialog {
        id: saveAsDialog
        title: qsTr("Save As")
        fileMode: FileDialog.SaveFile
        onAccepted: {
            const path = saveAsDialog.selectedFile.toString().replace("file:///", "/")
            saveCurrentAs(path)
        }
    }

    // ── Drag & drop onto the window ───────────────────────────────────
    DropArea {
        anchors.fill: parent
        onDropped: function(drop) {
            if (drop.hasUrls) {
                const urls = drop.urls
                for (let i = 0; i < urls.length; ++i) {
                    const p = urls[i].toString().replace("file:///", "/")
                    openPath(p)
                }
                drop.accepted = true
            } else if (drop.hasText) {
                editor.insert(editor.cursorPosition, drop.text)
                drop.accepted = true
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "#00E5FF"
            opacity: 0.08
            visible: parent.containsDrag
            border.color: "#00E5FF"
            border.width: 2
            radius: 8
        }
    }

    // ── Menu bar ──────────────────────────────────────────────────────
    menuBar: MenuBar {
        Menu {
            title: qsTr("File")
            Action { text: qsTr("New Tab"); shortcut: "Ctrl+N"; onTriggered: newTab("", "") }
            Action { text: qsTr("Open..."); shortcut: "Ctrl+O"; onTriggered: openDialog.open() }
            Action { text: qsTr("Save"); shortcut: "Ctrl+S"; onTriggered: saveCurrent() }
            Action { text: qsTr("Save As..."); shortcut: "Ctrl+Shift+S"; onTriggered: saveAsDialog.open() }
            MenuSeparator {}
            Menu {
                id: recentMenu
                title: qsTr("Open Recent")
                onAboutToShow: refreshRecentMenu()
                Instantiator {
                    model: recentModel
                    delegate: MenuItem {
                        text: model.name + "  \u2014  " + model.path
                        onTriggered: openPath(model.path)
                    }
                    onObjectAdded: function(index, object) { recentMenu.insertItem(index, object) }
                    onObjectRemoved: function(index, object) { recentMenu.removeItem(object) }
                }
                MenuSeparator {}
                Action { text: qsTr("Clear Recent List"); onTriggered: { fileDialogHelper.clearRecentFiles(); refreshRecentMenu() } }
            }
            MenuSeparator {}
            Action { text: qsTr("Close Tab"); shortcut: "Ctrl+W"; onTriggered: closeTab(tabBar.currentIndex) }
            Action { text: qsTr("Quit"); shortcut: "Ctrl+Q"; onTriggered: root.close() }
        }
        Menu {
            title: qsTr("Edit")
            Action { text: qsTr("Undo"); shortcut: "Ctrl+Z"; onTriggered: editor.undo() }
            Action { text: qsTr("Redo"); shortcut: "Ctrl+Shift+Z"; onTriggered: editor.redo() }
            MenuSeparator {}
            Action { text: qsTr("Cut"); shortcut: "Ctrl+X"; onTriggered: editor.cut() }
            Action { text: qsTr("Copy"); shortcut: "Ctrl+C"; onTriggered: editor.copy() }
            Action { text: qsTr("Paste"); shortcut: "Ctrl+V"; onTriggered: editor.paste() }
            MenuSeparator {}
            Action { text: qsTr("Select All"); shortcut: "Ctrl+A"; onTriggered: editor.selectAll() }
        }
        Menu {
            title: qsTr("Search")
            Action { text: qsTr("Find..."); shortcut: "Ctrl+F"; onTriggered: { findBar.visible = true; replaceRow.visible = true; findField.forceActiveFocus() } }
            Action { text: qsTr("Find Next"); shortcut: "F3"; onTriggered: findNext() }
            Action { text: qsTr("Replace..."); shortcut: "Ctrl+H"; onTriggered: { findBar.visible = true; replaceRow.visible = true; replaceField.forceActiveFocus() } }
            Action { text: qsTr("Replace Next"); onTriggered: replaceOne() }
            Action { text: qsTr("Replace All"); onTriggered: replaceAll() }
        }
        Menu {
            title: qsTr("View")
            Action { text: qsTr("Word Wrap"); checkable: true; checked: editor.wrapMode !== TextEdit.NoWrap; onTriggered: editor.wrapMode = checked ? TextEdit.WordWrap : TextEdit.NoWrap }
            Action { text: qsTr("Line Numbers"); checkable: true; checked: gutter.visible; onTriggered: gutter.visible = checked }
            Action { text: qsTr("Status Bar"); checkable: true; checked: statusBar.visible; onTriggered: statusBar.visible = checked }
            Action { text: qsTr("Auto Save"); checkable: true; checked: docAutoSave; enabled: docPath.length > 0; onTriggered: { docAutoSave = checked; tabs.setProperty(tabBar.currentIndex, "autoSaveEnabled", checked) } }
        }
    }

    // ── Layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tab bar
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: 0
            background: Rectangle { color: "#0F0F14" }
            Repeater {
                model: tabs
                TabButton {
                    text: (model.modified ? "\u2022 " : "") + model.title
                    width: Math.max(140, contentItem.implicitWidth + 32)
                    palette.windowText: "#F0F0F5"
                    background: Rectangle {
                        color: tabBar.currentIndex === index ? "#1A1A22" : "#0F0F14"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#00E5FF"; visible: tabBar.currentIndex === index }
                    }
                }
            }
            onCurrentIndexChanged: {
                // The index just changed. Flush the editor text into the tab
                // we are leaving (loadedTabIndex), then load the new one.
                if (loadedTabIndex === tabBar.currentIndex) return
                if (loadedTabIndex >= 0 && loadedTabIndex < tabs.count)
                    flushEditorToModel(loadedTabIndex)
                loadEditorFromCurrent()
            }
        }

        // Find / Replace bar
        Rectangle {
            id: findBar
            Layout.fillWidth: true
            height: findBar.visible ? (replaceRow.visible ? 76 : 38) : 0
            color: "#141418"
            visible: false
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    TextField {
                        id: findField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Find...")
                        onAccepted: findNext()
                        onTextChanged: findText = text
                        color: "#F0F0F5"
                    }
                    Button { text: qsTr("Find Next"); onClicked: findNext() }
                    Button { text: qsTr("Replace \u25BE"); checkable: true; checked: replaceRow.visible; onToggled: replaceRow.visible = checked }
                    Button { text: qsTr("Close"); onClicked: findBar.visible = false }
                }
                RowLayout {
                    id: replaceRow
                    Layout.fillWidth: true
                    visible: false
                    spacing: 6
                    TextField {
                        id: replaceField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Replace with...")
                        onTextChanged: replaceText = text
                        color: "#F0F0F5"
                    }
                    Button { text: qsTr("Replace"); onClicked: replaceOne() }
                    Button { text: qsTr("Replace All"); onClicked: replaceAll() }
                }
            }
        }

        // Editor area: line-number gutter + scrollable TextArea
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Line-number gutter. Its vertical scroll mirrors the editor's
            // internal flickable so numbers stay aligned with the text.
            Rectangle {
                id: gutter
                Layout.fillHeight: true
                width: 48
                color: "#0A0A0E"
                visible: true
                Flickable {
                    id: gutterFlick
                    anchors.fill: parent
                    contentHeight: gutterColumn.height
                    contentY: editorFlick.contentY
                    interactive: false
                    clip: true
                    Column {
                        id: gutterColumn
                        width: gutter.width
                        Repeater {
                            model: lineModel
                            Text {
                                width: gutter.width - 8
                                height: editor.lineHeight
                                text: model.number
                                color: "#5A5A64"
                                font.family: editor.font.family
                                font.pixelSize: editor.font.pixelSize
                                horizontalAlignment: Text.AlignRight
                                rightPadding: 6
                            }
                        }
                    }
                }
            }

            // Editor flickable. Using a Flickable (rather than ScrollView)
            // gives direct access to contentY for gutter sync.
            Flickable {
                id: editorFlick
                Layout.fillHeight: true
                Layout.fillWidth: true
                contentWidth: editor.width
                contentHeight: editor.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.AutoFlickIfNeeded

                TextArea {
                    id: editor
                    width: Math.max(editorFlick.width, editor.implicitWidth)
                    height: Math.max(editorFlick.height, editor.implicitHeight)
                    font.family: "monospace"
                    font.pixelSize: 14
                    color: "#F0F0F5"
                    selectionColor: "#00E5FF"
                    selectedTextColor: "#FFFFFF"
                    wrapMode: TextEdit.NoWrap
                    textFormat: TextEdit.PlainText
                    focus: true
                    background: Rectangle { color: "#0D0D10" }
                    readonly property real lineHeight: fontMetrics.height
                    FontMetrics { id: fontMetrics; font: editor.font }

                    onTextChanged: markModified()
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < editorFlick.contentY)
                            editorFlick.contentY = cursorRectangle.y
                        else if (cursorRectangle.y + cursorRectangle.height > editorFlick.contentY + editorFlick.height)
                            editorFlick.contentY = cursorRectangle.y + cursorRectangle.height - editorFlick.height
                    }
                }
            }
        }

        // Status bar
        Rectangle {
            id: statusBar
            Layout.fillWidth: true
            height: 24
            visible: true
            color: "#0D0D10"
            border.color: "#1A1A20"
            border.width: 1
            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 16
                Text {
                    text: qsTr("Ln %1").arg(currentLineNumber())
                    color: "#8E8E98"
                    font.pixelSize: 10
                }
                Text {
                    text: qsTr("Lines: %1").arg(lineModel.count)
                    color: "#8E8E98"
                    font.pixelSize: 10
                }
                Text {
                    text: qsTr("Words: %1").arg(wordCount())
                    color: "#8E8E98"
                    font.pixelSize: 10
                }
                Text {
                    text: qsTr("Chars: %1").arg(editor.text.length)
                    color: "#8E8E98"
                    font.pixelSize: 10
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: docPath.length > 0 ? docPath : qsTr("Unsaved")
                    color: "#5A5A64"
                    font.pixelSize: 10
                    elide: Text.ElideLeft
                    Layout.fillWidth: true
                }
            }
        }
    }

    // ── Auto-save ─────────────────────────────────────────────────────
    Timer {
        id: autoSaveTimer
        interval: 3000
        repeat: true
        running: docAutoSave && docModified && docPath.length > 0
        onTriggered: {
            if (docAutoSave && docModified && docPath.length > 0)
                saveCurrent()
        }
    }

    // ── Quit: prompt for every unsaved tab ────────────────────────────
    onClosing: function(close) {
        // Flush the currently-edited tab so its model entry reflects the editor.
        if (loadedTabIndex >= 0 && loadedTabIndex < tabs.count)
            flushEditorToModel(loadedTabIndex)
        for (let i = 0; i < tabs.count; ++i) {
            if (tabs.get(i).modified) {
                close.accepted = false
                tabBar.currentIndex = i
                pendingCloseIndex = i
                unsavedDialog.open()
                return
            }
        }
    }
}
