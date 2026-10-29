import QtQuick

// Tiny area chart for values in 0..1.
Canvas {
    id: c
    property var values: []
    property color stroke: "#ffffff"
    onValuesChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const n = values.length
        if (n < 2) return
        const w = width, h = height
        const rgba = a => "rgba(" + Math.round(stroke.r * 255) + "," + Math.round(stroke.g * 255) + "," + Math.round(stroke.b * 255) + "," + a + ")"
        ctx.beginPath()
        for (let i = 0; i < n; i++) {
            const x = i / (n - 1) * w
            const y = h - 2 - Math.max(0, Math.min(1, values[i])) * (h - 4)
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.strokeStyle = rgba(0.95)
        ctx.lineWidth = 1.6
        ctx.lineJoin = "round"
        ctx.stroke()
        ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath()
        ctx.fillStyle = rgba(0.16)
        ctx.fill()
    }
}
