import QtQuick

// Material Symbols Rounded glyph by ligature name (e.g. "calendar_month").
Text {
    property string name: ""
    property real size: 18
    property real fill: 0
    text: name
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill, "wght": 450, "GRAD": 0, "opsz": 24 })
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
    Behavior on color { ColorAnimation { duration: 150 } }
}
