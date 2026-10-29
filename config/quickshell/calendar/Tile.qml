import QtQuick

// Rounded, soft bento tile: springy hover, staggered entrance, optional click.
Rectangle {
    id: tile
    required property var theme
    property int order: 0               // entrance stagger
    property bool shown: false          // set by the page when it becomes active
    property bool interactive: true
    property color tone: theme.alpha(theme.card, 0.62)
    signal clicked()

    radius: 22
    color: hov.hovered && interactive ? Qt.lighter(tone, 1.18) : tone
    border.width: 1
    border.color: theme.alpha(theme.accent, hov.hovered && interactive ? 0.32 : 0.14)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    property real appear: 0
    opacity: appear
    scale: (0.86 + 0.14 * appear) * (hov.hovered && interactive ? 1.025 : 1)
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    onShownChanged: {
        enter.stop()
        if (shown) { appear = 0; enter.start() } else appear = 0
    }
    SequentialAnimation {
        id: enter
        PauseAnimation { duration: 40 + tile.order * 45 }
        NumberAnimation { target: tile; property: "appear"; to: 1; duration: 320; easing.type: Easing.OutCubic }
    }

    HoverHandler { id: hov }
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: tile.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (tile.interactive) tile.clicked()
    }
}
