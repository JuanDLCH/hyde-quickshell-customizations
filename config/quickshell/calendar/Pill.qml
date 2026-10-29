import QtQuick

// Small text/icon button with hover + press feedback.
Rectangle {
    id: p
    required property var theme
    property string text: ""
    property string icon: ""
    property int size: 10
    property bool strong: false
    property bool round: false
    signal clicked()

    implicitWidth: round ? implicitHeight : label.implicitWidth + (strong ? 36 : 12)
    implicitHeight: round ? 30 : (strong ? 34 : 20)
    radius: round ? height / 2 : (strong ? 12 : 9)
    color: ma.containsMouse ? theme.alpha(theme.accent, strong ? 0.29 : 0.20) : theme.alpha(theme.accent, strong ? 0.17 : (round ? 0.12 : 0.09))
    border.width: round ? 0 : 1
    border.color: theme.alpha(theme.accent, strong ? 0.35 : 0.18)
    scale: ma.pressed ? 0.94 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    Icon {
        visible: p.icon !== ""
        anchors.centerIn: parent
        name: p.icon
        size: p.size + 8
        fill: 1
        color: p.theme.fg
    }
    Text {
        id: label
        visible: p.icon === ""
        anchors.centerIn: parent
        text: p.text
        color: p.strong || ma.containsMouse ? p.theme.fg : p.theme.muted
        font.family: p.theme.font
        font.pixelSize: p.size
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: p.clicked()
    }
}
