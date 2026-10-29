import QtQuick

// Material 3 expressive progress: wavy "played" part, flat track, round handle.
Item {
    id: w
    required property var theme
    property real progress: 0        // 0..1
    property bool playing: false
    property bool seekable: false
    property real amplitude: playing ? 3 : 0
    property real wavelength: 22
    property real phase: 0
    signal seekTo(real fraction)
    signal dragging(real fraction)

    implicitHeight: 20
    Behavior on amplitude { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on progress { enabled: !drag.pressed; NumberAnimation { duration: 900 } }

    NumberAnimation on phase {
        from: 0; to: Math.PI * 2; duration: 1400
        loops: Animation.Infinite; running: w.playing && w.visible
    }

    readonly property real shown: drag.pressed ? drag.frac : progress
    readonly property real handleX: Math.max(4, Math.min(width - 4, width * shown))

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const cy = height / 2, hx = w.handleX, gap = 8
            ctx.lineCap = "round"; ctx.lineWidth = 4
            // flat remaining track
            ctx.strokeStyle = Qt.rgba(w.theme.fg.r, w.theme.fg.g, w.theme.fg.b, 0.16)
            if (hx + gap < width - 2) { ctx.beginPath(); ctx.moveTo(hx + gap, cy); ctx.lineTo(width - 2, cy); ctx.stroke() }
            // wavy played part
            ctx.strokeStyle = w.theme.accent
            ctx.beginPath()
            const end = hx - gap
            for (let x = 2; x <= end; x += 1.5) {
                const fade = Math.min(1, (x - 2) / 14) * Math.min(1, (end - x) / 10 + 0.0001)  // flatten at both ends
                const y = cy + Math.sin(x / w.wavelength * Math.PI * 2 - w.phase) * w.amplitude * Math.max(0, Math.min(1, fade))
                if (x === 2) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            if (end < 2) ctx.moveTo(2, cy)
            ctx.stroke()
        }
        Connections {
            target: w
            function onPhaseChanged() { cv.requestPaint() }
            function onShownChanged() { cv.requestPaint() }
            function onAmplitudeChanged() { cv.requestPaint() }
            function onWidthChanged() { cv.requestPaint() }
        }
        Component.onCompleted: requestPaint()
    }

    // handle: tall rounded pill, thins when pressed
    Rectangle {
        x: w.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: drag.pressed ? 3 : 5; height: drag.pressed ? 18 : 16; radius: width / 2
        color: w.theme.accent
        Behavior on width { NumberAnimation { duration: 100 } }
        Behavior on height { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: w.seekable
        cursorShape: Qt.PointingHandCursor
        property real frac: 0
        function pos(m) { frac = Math.max(0, Math.min(1, m.x / width)) }
        onPressed: m => pos(m)
        onPositionChanged: m => { if (pressed) { pos(m); w.dragging(frac) } }
        onReleased: w.seekTo(frac)
    }
}
