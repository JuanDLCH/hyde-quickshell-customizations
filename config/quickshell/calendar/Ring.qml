import QtQuick

// Animated circular gauge with a Material icon in the middle.
Item {
    id: r
    required property var theme
    property real value: 0          // 0..1
    property string icon: ""
    property string label: ""
    property color tint: theme.accent
    property real thickness: 6
    signal clicked()

    implicitWidth: 56; implicitHeight: 56
    property real shown: value
    Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const c = width / 2, rad = c - r.thickness / 2 - 1
            ctx.lineWidth = r.thickness; ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(r.theme.fg.r, r.theme.fg.g, r.theme.fg.b, 0.12)
            ctx.beginPath(); ctx.arc(c, c, rad, 0, Math.PI * 2); ctx.stroke()
            if (r.shown > 0.004) {
                ctx.strokeStyle = r.tint
                ctx.beginPath(); ctx.arc(c, c, rad, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, r.shown)); ctx.stroke()
            }
        }
        Connections { target: r; function onShownChanged() { cv.requestPaint() } function onTintChanged() { cv.requestPaint() } }
        Component.onCompleted: requestPaint()
    }
    Icon { anchors.centerIn: parent; name: r.icon; size: r.width * 0.36; fill: 1; color: r.tint }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.clicked() }
}
