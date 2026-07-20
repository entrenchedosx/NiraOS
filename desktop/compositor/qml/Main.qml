import QtQuick
import QtQuick.Window
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import QtWayland.Compositor.WlShell

// NiraOS Wayland compositor.
//
// Architecture: this is a Qt6 QML wayland compositor. It advertises the
// "wayland-0" socket, runs XdgShell + WlShell, and renders every client
// surface into a layered scene that is scanned out via eglfs/KMS.
//
// The shell ("nira-shell") connects as a regular Wayland client. It is
// identified by app_id and rendered fullscreen in the overlay layer; every
// other surface is a normal application window rendered in the window layer
// with simple move/focus/stacking chrome.
WaylandCompositor {
    id: niraCompositor
    socketName: "wayland-0"

    property int __topZ: 1
    property int outputWidth: Screen.width > 0 ? Screen.width : 1280
    property int outputHeight: Screen.height > 0 ? Screen.height : 720
    // Shared with the shell's TopPanel through DesktopMetrics.h. Maximized
    // clients use the desktop work area instead of obscuring system chrome.
    property int reservedTopEdge: desktopMetrics.panelReservedHeight
    // Establish the shell against the physical output first.  Once its first
    // buffer is live, expose the reduced work area for application windows.
    property bool applicationWorkAreaEnabled: false

    // QWaylandCompositor does not expose a compositor-wide
    // activeFocusSurface property. Keyboard focus belongs to the default
    // QWaylandSeat, so mirror its signal into explicit compositor state for
    // chrome rendering, D-Bus updates, and context export.
    property var activeFocusSurface: null
    Connections {
        target: niraCompositor.defaultSeat
        function onKeyboardFocusChanged(newFocus, oldFocus) {
            niraCompositor.activeFocusSurface = newFocus
        }
    }

    // ── Window registry for D-Bus IPC ───────────────────────────────
    property int __windowIdCounter: 0
    property var __windowMap: ({})     // id → chrome item
    // Reverse surface → windowId map for O(1) focus lookup.
    property var __surfaceMap: ({})    // surface → id

    // D-Bus signal handlers — find a chrome by its assigned ID.
    Connections {
        target: wmDBus
        function onActivateRequested(id) {
            var ch = __windowMap[id]
            if (!ch) return
            ch.windowMinimized = false
            ch.visible = true
            ch.takeFocus()
            ch.z = ++niraCompositor.__topZ
        }
        function onMinimizeRequested(id) {
            var ch = __windowMap[id]
            if (!ch) return
            ch.windowMinimized = true
        }
        function onCloseRequested(id) {
            var ch = __windowMap[id]
            if (!ch) return
            if (ch.toplevel) ch.toplevel.sendClose()
        }
    }

    // The shell toplevel once identified.  Stored here so we never
    // accidentally create a second chrome item for it.
    property var shellToplevel: null

    // Keep a single hidden chrome item reserved for the shell so that
    // the shell never appears in the window layer at all — it starts with
    // the correct fullscreen geometry from the very first commit.
    property Item shellChrome: null

    WaylandOutput {
        id: output
        compositor: niraCompositor
        sizeFollowsWindow: true
        // When the screen reports invalid physical dimensions (0x0 mm from
        // virtio-gpu without EDID), the C++ detectOutputScaleFactor() returns
        // 1 to force a correct 1:1 scale.  Otherwise 0 lets Qt auto-detect.
        scaleFactor: outputScaleFactor > 0 ? outputScaleFactor
                    : Math.max(1, Math.ceil(Screen.devicePixelRatio))
        // QtWayland's XDG integration positions maximized surfaces from the
        // output's availableGeometry. Setting only the client size causes the
        // integration to reset the surface origin to (0,0), hiding the panel
        // and leaving the reserved strip at the bottom.
        availableGeometry: Qt.rect(
            0,
            niraCompositor.applicationWorkAreaEnabled
                ? niraCompositor.reservedTopEdge : 0,
            niraCompositor.outputWidth,
            Math.max(200, niraCompositor.outputHeight
                - (niraCompositor.applicationWorkAreaEnabled
                    ? niraCompositor.reservedTopEdge : 0)))

        window: Window {
            id: compositorWindow
            width: niraCompositor.outputWidth
            height: niraCompositor.outputHeight
            visible: true
            color: "#050505"
            title: "NiraOS Compositor"

            Image {
                id: wallpaperImage
                anchors.fill: parent
                source: wallpaperWatcher.wallpaperSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Item { id: backgroundLayer; anchors.fill: parent }
            Item { id: windowLayer; anchors.fill: parent }
            Item { id: overlayLayer; anchors.fill: parent }

            // ── Software cursor sprite ─────────────────────────────────────
            // With llvmpipe OpenGL we render the cursor in QML instead of
            // relying on a hardware cursor plane.  Cursor position is tracked
            // from compositorWindow.mouseX/mouseY — the Window-level properties
            // that track the QPA mouse position without consuming any events
            // (unlike a MouseArea which would interfere with Wayland input
            // routing).  The cursor is drawn with a Canvas (zero file deps).
            property real __cursorX: compositorWindow.width / 2
            property real __cursorY: compositorWindow.height / 2

            Item {
                x: Math.max(0, compositorWindow.mouseX)
                y: Math.max(0, compositorWindow.mouseY)
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
    }

    // ── Shell identification ────────────────────────────────────────────
    // The xdg-toplevel appId is set by the client via set_app_id.
    // QtWaylandClient sends it from QGuiApplication::applicationName.
    // For robustness we also match on title and on process hint.
    function isShellSurface(toplevel) {
        if (!toplevel) return false
        const appId = (toplevel.appId || "").trim()
        if (appId === "nira-shell") return true
        const title = (toplevel.title || "").trim()
        if (title === "NiraOS Shell") return true
        return false
    }

    // ── Surface classification ──────────────────────────────────────────
    // The shell receives a dedicated chrome item in the overlay layer
    // immediately.  If the appId hasn't arrived yet we use the title
    // fallback and later upgrade via onAppIdChanged.
    function adoptToplevel(toplevel, xdgSurface) {
        const isShell = isShellSurface(toplevel)

        // Never create a second shell chrome.
        if (isShell && niraCompositor.shellChrome) {
            console.log("NiraCompositor: shell already adopted, ignoring duplicate")
            return
        }

        // The shell paints the wallpaper and panel, so it is the desktop
        // background. Putting its opaque fullscreen surface in overlayLayer
        // makes every application window render successfully but remain
        // permanently invisible underneath it.
        const layer = isShell ? backgroundLayer : windowLayer

        const item = chromeComponent.createObject(layer, {
            shellSurface: xdgSurface,
            toplevel: toplevel,
            isShell: isShell
        })

        // QWaylandXdgToplevel is assigned to a var property at run time.
        // A declarative Connections object can miss the title/app-id requests
        // that immediately follow get_toplevel in the same Wayland dispatch
        // batch.  Connect explicitly, then reconcile once after this event so
        // classification and taskbar metadata cannot remain at their empty
        // creation-time values.
        if (toplevel) {
            toplevel.appIdChanged.connect(item.handleToplevelMetadataChanged)
            toplevel.titleChanged.connect(item.handleToplevelMetadataChanged)
            toplevel.maximizedChanged.connect(function() {
                if (item && item.isShell && toplevel.maximized
                        && !niraCompositor.applicationWorkAreaEnabled) {
                    // Qt's integration handles this signal first while the
                    // output still exposes its full geometry, placing the
                    // shell at (0,0). Reducing availableGeometry afterwards
                    // sends a same-state size configure but does not trigger a
                    // second maximizedChanged reposition.
                    niraCompositor.applicationWorkAreaEnabled = true
                    console.log("NiraCompositor: application work area enabled:",
                        output.availableGeometry)
                }
            })
            Qt.callLater(function() {
                if (item)
                    item.handleToplevelMetadataChanged()
            })
        }

        if (isShell) {
            niraCompositor.shellChrome = item
            niraCompositor.shellToplevel = toplevel
            item.sendShellConfigure()
            console.log("NiraCompositor: shell adopted immediately")
        } else {
            // Normal windows: centre with reasonable default size.
            const w = Math.min(900, compositorWindow.width - 80)
            const h = Math.min(600, compositorWindow.height - 80)
            toplevel.sendConfigure(Qt.size(w, h), [])
            item.x = (compositorWindow.width - w) / 2
            item.y = (compositorWindow.height - h) / 2
            item.z = ++niraCompositor.__topZ
        }

        console.log("NiraCompositor: xdg toplevel mapped:",
                    "appId=", (toplevel.appId || "(none)"),
                    "title=", (toplevel.title || "(untitled)"),
                    "isShell=", isShell)
    }

    XdgShell {
        id: xdgShell
        onToplevelCreated: (toplevel, xdgSurface) => {
            // Create the view immediately so QtWayland establishes its primary
            // ShellSurfaceItem before the client waits for an initial
            // configure. The explicit metadata signal connections in
            // adoptToplevel promote the Nira shell as soon as set_title or
            // set_app_id arrives in the following protocol requests.
            niraCompositor.adoptToplevel(toplevel, xdgSurface)
        }
    }

    // wl_shell surfaces are always normal windows.
    WlShell {
        id: wlShell
        onWlShellSurfaceCreated: (shellSurface) => {
            const item = chromeComponent.createObject(windowLayer, {
                shellSurface: shellSurface,
                isShell: false
            })
            const w = Math.min(900, compositorWindow.width - 80)
            const h = Math.min(600, compositorWindow.height - 80)
            item.x = (compositorWindow.width - w) / 2
            item.y = (compositorWindow.height - h) / 2
            console.log("NiraCompositor: wl_shell surface mapped")
        }
    }

    // ── Chrome item (per-surface) ───────────────────────────────────────
    //
    // For non-shell windows this renders a full SSD frame:
    //   • Title bar with window title + minimise / maximise / close
    //   • Active-window highlight (lighter title bar when focused)
    //   • 8 px resize handles on every edge and corner
    //   • Drag-to-move via the title bar
    //
    // The title bar is rendered as an overlay on top of the client surface
    // (z = 100) so the compositor's chrome is always visible.  This is the
    // standard SSD approach used by Mutter / GNOME.

    Component {
        id: chromeComponent
        ShellSurfaceItem {
            id: chrome

            property var toplevel: null
            property bool isShell: false

            // ── D-Bus window identity ───────────────────────────────────
            property string windowId: ""

            // ── Window geometry state ───────────────────────────────────
            property bool windowMaximized: false
            property bool windowMinimized: false
            property int saveX: 0
            property int saveY: 0
            property int saveW: 800
            property int saveH: 600

            // ── Metrics ─────────────────────────────────────────────────
            readonly property int titleBarHeight: isShell ? 0 : 32
            readonly property int resizeHandleWidth: 8

            // Local focus state updated via Connections to avoid evaluating
            // niraCompositor.activeFocusSurface === chrome.surface in every
            // chrome item on every focus change.
            property bool isLocalFocus: false
            readonly property color titleBg: isLocalFocus
                ? Qt.rgba(0.12, 0.12, 0.15, 0.94)
                : Qt.rgba(0.06, 0.06, 0.08, 0.90)

            Connections {
                target: niraCompositor
                function onActiveFocusSurfaceChanged() {
                    chrome.isLocalFocus = niraCompositor.activeFocusSurface === chrome.surface
                }
            }

            property bool __yFixPending: false
            onYChanged: {
                if (chrome.isShell
                        && niraCompositor.applicationWorkAreaEnabled
                        && chrome.surface && chrome.surface.hasContent
                        && chrome.y !== 0 && !chrome.__yFixPending) {
                    chrome.__yFixPending = true
                    Qt.callLater(function() {
                        chrome.__yFixPending = false
                        if (chrome && chrome.isShell
                                && niraCompositor.applicationWorkAreaEnabled)
                            chrome.y = 0
                    })
                }
            }

            // Assign a unique ID and register with the D-Bus window manager.
            Component.onCompleted: {
                if (!chrome.isShell) {
                    chrome.windowId = "win-" + (++niraCompositor.__windowIdCounter)
                    niraCompositor.__windowMap[chrome.windowId] = chrome
                    if (chrome.surface)
                        niraCompositor.__surfaceMap[chrome.surface] = chrome.windowId
                    var appId = chrome.toplevel ? chrome.toplevel.appId || "" : ""
                    var title = chrome.toplevel ? chrome.toplevel.title || "" : ""
                    wmDBus.registerWindow(chrome.windowId, title, appId)
                }
            }

            onSurfaceDestroyed: {
                if (!chrome.isShell && chrome.windowId) {
                    if (chrome.surface)
                        delete niraCompositor.__surfaceMap[chrome.surface]
                    wmDBus.unregisterWindow(chrome.windowId)
                }
                destroy()
            }

            onWindowMinimizedChanged: {
                if (!chrome.isShell) {
                    // A minimized surface must leave both the rendered scene
                    // and keyboard focus. Merely recording the boolean leaves
                    // the window fully visible and interactive.
                    chrome.visible = !chrome.windowMinimized
                    if (chrome.windowMinimized && niraCompositor.shellChrome)
                        niraCompositor.shellChrome.takeFocus()
                }
                if (!chrome.isShell && chrome.windowId)
                    wmDBus.updateWindowState(chrome.windowId, chrome.windowMinimized,
                        chrome.isLocalFocus)
            }

            // ── Focus + raise on click ──────────────────────────────────
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true
                onPressed: (mouse) => {
                    chrome.takeFocus()
                    if (!chrome.isShell) {
                        chrome.z = ++niraCompositor.__topZ
                    }
                    mouse.accepted = false
                }
            }

            // ── Reclassification (shell detection) ──────────────────────
            function handleToplevelMetadataChanged() {
                if (!chrome.toplevel || chrome.isShell)
                    return
                if (!niraCompositor.shellChrome && isShellSurface(chrome.toplevel)) {
                    // Do not reparent a ShellSurfaceItem before its first
                    // committed buffer. QtWayland has not established the
                    // primary view yet and the surface can remain invisible.
                    // onHasContentChanged performs the promotion once the view
                    // is live.
                    if (chrome.surface && chrome.surface.hasContent)
                        promoteToShell()
                } else if (chrome.windowId) {
                    wmDBus.updateWindowMetadata(chrome.windowId,
                        chrome.toplevel.title || "", chrome.toplevel.appId || "")
                }
            }

            function promoteToShell() {
                if (chrome.windowId) {
                    wmDBus.unregisterWindow(chrome.windowId)
                    delete niraCompositor.__windowMap[chrome.windowId]
                    if (chrome.surface)
                        delete niraCompositor.__surfaceMap[chrome.surface]
                    chrome.windowId = ""
                }
                chrome.isShell = true
                chrome.parent = backgroundLayer
                niraCompositor.shellChrome = chrome
                niraCompositor.shellToplevel = chrome.toplevel
                chrome.windowMaximized = true
                chrome.windowMinimized = false
                chrome.visible = true
                chrome.sendShellConfigure()
            }

            Connections {
                target: compositorWindow
                function onWidthChanged() {
                    if (chrome.isShell) chrome.sendShellConfigure()
                    else if (chrome.windowMaximized) chrome.applyMaximizedGeometry()
                }
                function onHeightChanged() {
                    if (chrome.isShell) chrome.sendShellConfigure()
                    else if (chrome.windowMaximized) chrome.applyMaximizedGeometry()
                }
            }

            function sendShellConfigure() {
                chrome.takeFocus()
                if (toplevel && isShell) {
                    // Qt's Wayland client commits the shell buffer reliably in
                    // maximized state. ShellSurfaceItem owns the resulting
                    // geometry; assigning to it during the state transition
                    // can detach the view from the committed buffer.
                    toplevel.sendMaximized(
                        Qt.size(compositorWindow.width, compositorWindow.height))
                }
            }

            function applyMaximizedGeometry() {
                if (!toplevel || isShell)
                    return
                const workArea = output.availableGeometry
                chrome.x = workArea.x
                chrome.y = workArea.y
                chrome.width = workArea.width
                chrome.height = workArea.height
                toplevel.sendMaximized(Qt.size(chrome.width, chrome.height))
            }

            Connections {
                target: chrome.surface
                function onHasContentChanged() {
                    if (chrome.surface && chrome.surface.hasContent) {
                        chrome.takeFocus()
                        if (!chrome.isShell && !niraCompositor.shellChrome && isShellSurface(chrome.toplevel)) {
                            console.log("NiraCompositor: promoting committed desktop surface:",
                                chrome.toplevel.appId || "(none)",
                                chrome.toplevel.title || "(untitled)")
                            promoteToShell()
                        }
                    }
                }
            }

            // ── Title bar (decorated overlay, z=100) ────────────────────
            Rectangle {
                id: titleBar
                visible: !chrome.isShell
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: chrome.titleBarHeight
                z: 100
                color: chrome.titleBg

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: chrome.toplevel ? (chrome.toplevel.title || "Untitled") : ""
                    color: "#E0E0E0"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width - 130
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Minimise
                    TitleBarBtn {
                        label: "\u2014"
                        onClicked: chrome.windowMinimized = true
                    }

                    // Maximise / Restore
                    TitleBarBtn {
                        label: chrome.windowMaximized ? "\u29C9" : "\u25A1"
                        onClicked: {
                            if (chrome.windowMaximized) {
                                chrome.x = chrome.saveX
                                chrome.y = chrome.saveY
                                chrome.width = chrome.saveW
                                chrome.height = chrome.saveH
                                chrome.windowMaximized = false
                                if (chrome.toplevel)
                                    chrome.toplevel.sendUnmaximized()
                            } else {
                                chrome.saveX = chrome.x
                                chrome.saveY = chrome.y
                                chrome.saveW = chrome.width
                                chrome.saveH = chrome.height
                                chrome.windowMaximized = true
                                chrome.applyMaximizedGeometry()
                            }
                        }
                    }

                    // Close
                    TitleBarBtn {
                        label: "\u2715"
                        hoverBg: "#CC3333"
                        onClicked: { if (chrome.toplevel) chrome.toplevel.sendClose() }
                    }
                }

                DragHandler {
                    target: chrome
                    enabled: !chrome.isShell && !chrome.windowMaximized
                    onActiveChanged: { if (active) chrome.takeFocus() }
                }

                // Bottom separator line
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: "#33FFFFFF"
                }
            }

            // ── Resize handles ──────────────────────────────────────────
            // Each handle is a transparent MouseArea that tracks drag delta
            // and calls sendContentConfigure() when the user releases.

            // Left
            ResizeHandle { edge: "left" }
            // Right
            ResizeHandle { edge: "right" }
            // Top
            ResizeHandle { edge: "top" }
            // Bottom
            ResizeHandle { edge: "bottom" }
            // Top-left
            ResizeHandle { edge: "topleft" }
            // Top-right
            ResizeHandle { edge: "topright" }
            // Bottom-left
            ResizeHandle { edge: "bottomleft" }
            // Bottom-right
            ResizeHandle { edge: "bottomright" }

            function sendContentConfigure() {
                if (chrome.toplevel && !chrome.isShell && !chrome.windowMaximized) {
                    chrome.toplevel.sendConfigure(Qt.size(chrome.width, chrome.height), [])
                }
            }
        }
    }

    // ── Inline title-bar button ─────────────────────────────────────────
    component TitleBarBtn : Rectangle {
        width: 32; height: 24; radius: 4
        color: ma.containsMouse ? (hoverBg) : "transparent"
        property string label: ""
        property color hoverBg: "#44FFFFFF"
        signal clicked()

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: "#DDDDDD"
            font.pixelSize: 12
            font.family: "monospace"
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    // ── Inline resize handle ────────────────────────────────────────────
    //
    // All coordinate math uses GLOBAL positions (via mapToItem) so that
    // moving the window edge does not shift the MouseArea's local origin
    // under the cursor — this eliminates the feedback loop that would
    // otherwise cause violent jitter.
    //
    // Left / top resize clamps the delta *before* applying it to the
    // window position, preventing the slide-bug when the minimum size
    // is reached.

    component ResizeHandle : MouseArea {
        visible: !chrome.isShell
        property string edge: "left"

        readonly property bool isLeft:   edge === "left" || edge === "topleft"  || edge === "bottomleft"
        readonly property bool isRight:  edge === "right"|| edge === "topright" || edge === "bottomright"
        readonly property bool isTop:    edge === "top"  || edge === "topleft"  || edge === "topright"
        readonly property bool isBottom: edge === "bottom"|| edge === "bottomleft"||edge === "bottomright"

        readonly property bool isCorner: (isLeft && isTop) || (isRight && isTop) || (isLeft && isBottom) || (isRight && isBottom)
        readonly property int sz: isCorner ? 16 : 8

        width:  isLeft || isRight  ? sz : parent.width
        height: isTop  || isBottom ? sz : parent.height

        anchors.left:   isLeft   ? parent.left   : undefined
        anchors.right:  isRight  ? parent.right  : undefined
        anchors.top:    isTop    ? parent.top    : undefined
        anchors.bottom: isBottom ? parent.bottom : undefined

        cursorShape: {
            if      (edge === "topleft")     return Qt.SizeFDiagCursor
            else if (edge === "bottomright") return Qt.SizeFDiagCursor
            else if (edge === "topright")    return Qt.SizeBDiagCursor
            else if (edge === "bottomleft")  return Qt.SizeBDiagCursor
            else if (isLeft || isRight)      return Qt.SizeHorCursor
            else                             return Qt.SizeVerCursor
        }

        // Drag origin in the COMPOSITOR WINDOW's coordinate space.
        property real dragGlobalX: 0
        property real dragGlobalY: 0

        onPressed: (mouse) => {
            var g = mapToItem(compositorWindow.contentItem, mouse.x, mouse.y)
            dragGlobalX = g.x
            dragGlobalY = g.y
        }

        onPositionChanged: (mouse) => {
            if (!pressed) return
            var g = mapToItem(compositorWindow.contentItem, mouse.x, mouse.y)
            var dx = g.x - dragGlobalX
            var dy = g.y - dragGlobalY

            // Clamp left/top resize so the window can't slide past its
            // minimum size.  Compute the bounded delta BEFORE applying it.
            var boundedDx = dx
            var boundedDy = dy
            if (isLeft) {
                var newW = chrome.width - boundedDx
                if (newW < 200) {
                    boundedDx = chrome.width - 200
                    newW = 200
                }
                chrome.x += boundedDx
                chrome.width = newW
            }
            if (isRight) {
                chrome.width = Math.max(200, chrome.width + dx)
            }
            if (isTop) {
                var newH = chrome.height - boundedDy
                if (newH < 200) {
                    boundedDy = chrome.height - 200
                    newH = 200
                }
                chrome.y += boundedDy
                chrome.height = newH
            }
            if (isBottom) {
                chrome.height = Math.max(200, chrome.height + dy)
            }

            dragGlobalX = g.x
            dragGlobalY = g.y

            chrome.sendContentConfigure()
        }
    }


    // ── Active-window tracking for the context-broker ───────────────
    // Whenever the compositor focus moves to a different surface we
    // update the ContextExporter C++ helper, which writes a JSON file
    // to $XDG_RUNTIME_DIR/nira-active-window.json.
    property string __lastFocusAppId: ""
    property string __lastFocusTitle: ""

    // O(1) focus tracking — only the two windows that actually changed
    // (lost → gained) emit D-Bus signals, instead of iterating over
    // every registered window.
    property string __lastFocusedWinId: ""

    onActiveFocusSurfaceChanged: {
        var focused = niraCompositor.activeFocusSurface
        if (!focused) return
        var appId = ""
        var title = ""

        var views = focused.views
        if (views && views.length > 0) {
            var view = views[0]
            if (view.shellSurface && view.shellSurface.toplevel) {
                appId = view.shellSurface.toplevel.appId || ""
                title = view.shellSurface.toplevel.title || ""
            }
        }

        // Context-broker (unchanged).
        if (appId !== __lastFocusAppId || title !== __lastFocusTitle) {
            __lastFocusAppId = appId
            __lastFocusTitle = title
            contextExporter.activeAppId = appId
            contextExporter.activeTitle = title
        }

        // O(1) surface-to-windowId lookup via reverse map.
        var newFocusedWinId = niraCompositor.__surfaceMap[focused] || ""

        if (__lastFocusedWinId !== newFocusedWinId) {
            // Unfocus the previously focused window.
            if (__lastFocusedWinId && niraCompositor.__windowMap[__lastFocusedWinId]) {
                var oldCh = niraCompositor.__windowMap[__lastFocusedWinId]
                wmDBus.updateWindowState(__lastFocusedWinId, oldCh.windowMinimized, false)
            }
            // Focus the newly focused window.
            if (newFocusedWinId && niraCompositor.__windowMap[newFocusedWinId]) {
                var newCh = niraCompositor.__windowMap[newFocusedWinId]
                wmDBus.updateWindowState(newFocusedWinId, newCh.windowMinimized, true)
            }
            __lastFocusedWinId = newFocusedWinId

            if (newFocusedWinId)
                console.log("NiraCompositor: focus changed to",
                            "id=", newFocusedWinId, "appId=", appId, "title=", title)
        }
    }

    // Write one final record on shutdown so the broker sees stale but
    // valid data instead of nothing.
    Component.onDestruction: {
        contextExporter.flush()
    }

    Component.onCompleted: {
        console.log("NiraCompositor: ready, output",
                    niraCompositor.outputWidth, "x", niraCompositor.outputHeight)
    }

    onSurfaceCreated: (surface) => {
        console.log("NiraCompositor: new wayland surface from client")
    }
}
