import QtQuick

// Kawaii cat-blob drawn in plain QML. `mood` drives the animation:
// idle | dance | sleep | focus | tired | rest
Item {
    id: m
    required property var theme
    property string mood: "idle"
    property string imageSource: ""      // optional sticker/PNG to use instead of the drawing

    readonly property real s: Math.min(width, height)
    readonly property color fur: theme.mix(theme.fg, theme.pink, 0.45)
    readonly property color ink: theme.bg
    readonly property bool asleep: mood === "sleep"

    // ---- optional custom image: same moods become sway/bob ----
    Image {
        visible: m.imageSource !== ""
        anchors.centerIn: parent
        width: m.s; height: m.s
        source: m.imageSource
        fillMode: Image.PreserveAspectFit
        transformOrigin: Item.Bottom
        rotation: m.mood === "dance" ? cat.sway : 0
    }

    Item {
        id: cat
        visible: m.imageSource === ""
        anchors.centerIn: parent
        width: m.s; height: m.s
        transformOrigin: Item.Bottom

        // breathing + dance
        property real breathe: 0
        property real sway: 0
        scale: 1
        transform: [
            Scale { origin.x: cat.width / 2; origin.y: cat.height; yScale: 1 + cat.breathe * 0.035; xScale: 1 - cat.breathe * 0.015 },
            Rotation { origin.x: cat.width / 2; origin.y: cat.height; angle: cat.sway }
        ]
        SequentialAnimation on breathe {
            loops: Animation.Infinite; running: true
            NumberAnimation { to: 1; duration: m.mood === "tired" ? 1100 : 1700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0; duration: m.mood === "tired" ? 1100 : 1700; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on sway {
            id: sway
            loops: Animation.Infinite
            running: m.mood === "dance"
            NumberAnimation { to: -7; duration: 380; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 7; duration: 380; easing.type: Easing.InOutQuad }
            onRunningChanged: if (!running) cat.sway = 0
        }

        // tail
        Rectangle {
            id: tail
            width: m.s * 0.1; height: m.s * 0.36; radius: width / 2
            color: Qt.darker(m.fur, 1.08)
            x: cat.width * 0.72; y: cat.height * 0.5
            transformOrigin: Item.Bottom
            rotation: 22
            SequentialAnimation on rotation {
                loops: Animation.Infinite; running: !m.asleep
                NumberAnimation { to: 40; duration: m.mood === "dance" ? 260 : 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 8; duration: m.mood === "dance" ? 260 : 900; easing.type: Easing.InOutSine }
            }
        }

        // ears
        Repeater {
            model: [-1, 1]
            Item {
                required property int modelData
                x: cat.width / 2 + modelData * m.s * 0.23 - m.s * 0.09
                y: cat.height * 0.2
                width: m.s * 0.18; height: m.s * 0.18
                rotation: modelData * 18
                Rectangle { anchors.fill: parent; radius: m.s * 0.04; color: m.fur; rotation: 45 }
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.5; height: width; radius: m.s * 0.02; color: m.theme.alpha(m.theme.pink, 0.55); rotation: 45 }
            }
        }

        // body
        Rectangle {
            id: body
            width: m.s * 0.74; height: m.s * 0.62
            radius: m.s * 0.3
            x: (cat.width - width) / 2; y: cat.height * 0.3
            color: m.fur
            border.width: 1; border.color: m.theme.alpha(m.ink, 0.12)

            // eyes
            Repeater {
                model: [-1, 1]
                Rectangle {
                    id: eye
                    required property int modelData
                    width: m.s * 0.075; height: m.asleep ? m.s * 0.02 : m.s * 0.12
                    radius: width / 2
                    color: m.ink
                    x: body.width / 2 + modelData * m.s * 0.16 - width / 2
                    y: body.height * 0.34
                    transformOrigin: Item.Center
                    property real blink: 1
                    scale: 1
                    transform: Scale { origin.y: eye.height / 2; yScale: eye.blink }
                    SequentialAnimation on blink {
                        loops: Animation.Infinite; running: !m.asleep
                        PauseAnimation { duration: 2600 + (modelData > 0 ? 40 : 0) }
                        NumberAnimation { to: 0.08; duration: 70 }
                        NumberAnimation { to: 1; duration: 110 }
                    }
                    // sparkle
                    Rectangle { visible: !m.asleep; width: parent.width * 0.38; height: width; radius: width / 2; color: "white"; x: parent.width * 0.5; y: parent.height * 0.12 }
                }
            }
            // glasses while focusing
            Item {
                visible: m.mood === "focus"
                anchors.fill: parent
                Repeater {
                    model: [-1, 1]
                    Rectangle {
                        required property int modelData
                        width: m.s * 0.2; height: width; radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 2; border.color: m.theme.accent
                        x: body.width / 2 + modelData * m.s * 0.16 - width / 2
                        y: body.height * 0.34 + m.s * 0.06 - height / 2
                    }
                }
                Rectangle { width: m.s * 0.06; height: 2; color: m.theme.accent; x: body.width / 2 - width / 2; y: body.height * 0.34 + m.s * 0.06 }
            }
            // cheeks
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    width: m.s * 0.11; height: m.s * 0.065; radius: height / 2
                    color: m.theme.alpha(m.theme.pink, m.mood === "tired" ? 0.25 : 0.65)
                    x: body.width / 2 + modelData * m.s * 0.27 - width / 2
                    y: body.height * 0.56
                }
            }
            // mouth
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: body.height * 0.5
                color: m.ink
                font.pixelSize: m.s * 0.16
                font.family: "Noto Sans CJK JP"
                text: m.mood === "tired" ? "﹏" : m.mood === "dance" ? "ᴗ" : m.mood === "rest" ? "ᴥ" : m.asleep ? "ᴗ" : "ω"
            }
        }

        // paws
        Repeater {
            model: [-1, 1]
            Rectangle {
                required property int modelData
                width: m.s * 0.17; height: m.s * 0.1; radius: height / 2
                color: Qt.lighter(m.fur, 1.06)
                x: cat.width / 2 + modelData * m.s * 0.2 - width / 2
                y: cat.height - height - 1
            }
        }

        // sweat drop (tired)
        Rectangle {
            visible: m.mood === "tired"
            width: m.s * 0.07; height: m.s * 0.1; radius: width / 2
            color: "#8ecbff"
            x: cat.width * 0.74; y: cat.height * 0.3
            SequentialAnimation on y {
                loops: Animation.Infinite; running: m.mood === "tired"
                NumberAnimation { from: cat.height * 0.26; to: cat.height * 0.42; duration: 900; easing.type: Easing.InQuad }
                PauseAnimation { duration: 400 }
            }
        }
        // dango snack (rest)
        Text {
            visible: m.mood === "rest"
            text: "🍡"; font.family: "Noto Color Emoji"; font.pixelSize: m.s * 0.24
            x: cat.width * 0.62; y: cat.height * 0.66
            SequentialAnimation on rotation {
                loops: Animation.Infinite; running: m.mood === "rest"
                NumberAnimation { to: -12; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 6; duration: 500; easing.type: Easing.InOutSine }
            }
        }
    }

    // floating z's (sleep) and notes (dance)
    Repeater {
        model: m.asleep ? 3 : 0
        Text {
            id: zz
            required property int index
            text: "z"; color: m.theme.accent; font.bold: true
            font.pixelSize: m.s * (0.12 + index * 0.04)
            x: m.width / 2 + m.s * 0.2 + index * m.s * 0.07
            opacity: 0
            SequentialAnimation {
                loops: Animation.Infinite; running: true
                PauseAnimation { duration: index * 600 }
                ParallelAnimation {
                    NumberAnimation { target: zz; property: "y"; from: m.height * 0.3; to: -m.s * 0.05; duration: 1800; easing.type: Easing.OutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: zz; property: "opacity"; to: 1; duration: 400 }
                        NumberAnimation { target: zz; property: "opacity"; to: 0; duration: 1400 }
                    }
                }
            }
        }
    }
    Repeater {
        model: m.mood === "dance" ? 3 : 0
        Text {
            id: nt
            required property int index
            text: index % 2 ? "♪" : "♫"; color: index % 2 ? m.theme.pink : m.theme.accent
            font.pixelSize: m.s * 0.17
            x: index % 2 ? m.width * 0.06 : m.width * 0.78 - index * 4
            opacity: 0
            SequentialAnimation {
                loops: Animation.Infinite; running: true
                PauseAnimation { duration: index * 450 }
                ParallelAnimation {
                    NumberAnimation { target: nt; property: "y"; from: m.height * 0.4; to: -m.s * 0.04; duration: 1500; easing.type: Easing.OutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: nt; property: "opacity"; to: 1; duration: 300 }
                        NumberAnimation { target: nt; property: "opacity"; to: 0; duration: 1200 }
                    }
                }
            }
        }
    }
}
