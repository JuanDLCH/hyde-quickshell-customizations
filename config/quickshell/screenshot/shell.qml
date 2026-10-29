import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Screenshot region picker: frozen screen, hover highlights a window, click picks it, drag selects a zone.
ShellRoot {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/shot"

    property bool active: false
    property var info: null
    property rect sel: Qt.rect(0, 0, 0, 0)
    property bool dragging: false
    property bool hasSel: false

    Theme { id: pal }

    IpcHandler {
        target: "shot"
        function region(): void { reader.running = true }
    }
    Process {
        id: reader
        command: ["cat", root.dir + "/info.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.info = JSON.parse(text) } catch (e) { return }
                root.hasSel = false; root.dragging = false; root.sel = Qt.rect(0, 0, 0, 0)
                root.active = true
            }
        }
    }
    function pick(x, y) {
        for (const w of info.wins) if (x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h) return w
        return null
    }
    function confirm() {
        const s = sel
        active = false
        if (s.width < 2 || s.height < 2) return
        Quickshell.execDetached(["shot", "crop", Math.round(s.x), Math.round(s.y), Math.round(s.width), Math.round(s.height)])
    }

    PanelWindow {
        screen: root.info ? (Quickshell.screens.find(s => s.name === root.info.mon.name) || Quickshell.screens[0]) : Quickshell.screens[0]
        visible: root.active
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-screenshot"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.active = false

            Image {
                anchors.fill: parent
                source: root.info ? "file://" + root.info.frozen : ""
                cache: false
            }
            // dim everything except the selection
            Rectangle { color: "#000"; opacity: 0.5; x: 0; y: 0; width: parent.width; height: sel.y }
            Rectangle { color: "#000"; opacity: 0.5; x: 0; y: sel.y + sel.height; width: parent.width; height: parent.height - sel.y - sel.height }
            Rectangle { color: "#000"; opacity: 0.5; x: 0; y: sel.y; width: sel.x; height: sel.height }
            Rectangle { color: "#000"; opacity: 0.5; x: sel.x + sel.width; y: sel.y; width: parent.width - sel.x - sel.width; height: sel.height }
            readonly property rect sel: root.hasSel ? root.sel : Qt.rect(0, 0, parent.width, parent.height)

            Rectangle {
                id: frame
                visible: root.hasSel
                x: root.sel.x; y: root.sel.y; width: root.sel.width; height: root.sel.height
                color: "transparent"; radius: root.dragging ? 0 : 10
                border.width: 2; border.color: pal.accent
                Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !root.dragging; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: !root.dragging; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: !root.dragging; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                visible: root.hasSel && root.dragging
                x: Math.min(root.sel.x, stage.width - width); y: Math.max(0, root.sel.y - height - 6)
                width: sizeText.implicitWidth + 16; height: 24; radius: 12; color: pal.alpha(pal.bg, 0.92)
                Text { id: sizeText; anchors.centerIn: parent; color: pal.fg; font.family: pal.font; font.pixelSize: 11
                       text: Math.round(root.sel.width) + " × " + Math.round(root.sel.height) }
            }
            Rectangle {
                visible: !root.dragging
                anchors.horizontalCenter: parent.horizontalCenter; y: 28
                width: hint.implicitWidth + 28; height: 32; radius: 16; color: pal.alpha(pal.bg, 0.92)
                Text { id: hint; anchors.centerIn: parent; color: pal.fg; font.family: pal.font; font.pixelSize: 12
                       text: "Click a window · drag a zone · Esc to cancel" }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor
                property point start
                onPressed: m => { if (m.button === Qt.RightButton) { root.active = false; return } start = Qt.point(m.x, m.y) }
                onPositionChanged: m => {
                    if (pressed) {
                        if (!root.dragging && Math.hypot(m.x - start.x, m.y - start.y) < 6) return
                        root.dragging = true; root.hasSel = true
                        root.sel = Qt.rect(Math.min(start.x, m.x), Math.min(start.y, m.y), Math.abs(m.x - start.x), Math.abs(m.y - start.y))
                    } else {
                        const w = root.pick(m.x, m.y)
                        root.hasSel = w !== null
                        if (w) root.sel = Qt.rect(w.x, w.y, w.w, w.h)
                    }
                }
                onReleased: m => {
                    if (m.button !== Qt.LeftButton) return
                    if (root.dragging) { root.dragging = false; root.confirm(); return }
                    const w = root.pick(m.x, m.y)
                    if (w) { root.sel = Qt.rect(w.x, w.y, w.w, w.h); root.confirm() }
                }
            }
        }
    }
}
