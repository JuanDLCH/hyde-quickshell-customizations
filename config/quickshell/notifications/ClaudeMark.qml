import QtQuick

// Small orange blob critter for Claude Code notifications (original drawing).
Item {
    id: m
    property real s: 30
    implicitWidth: s; implicitHeight: s
    readonly property color orange: "#E8895C"
    readonly property color dark: "#2a1d19"

    // antennae
    Rectangle { x: s * 0.30; y: s * 0.06; width: s * 0.07; height: s * 0.26; radius: width / 2; color: m.orange; rotation: -18 }
    Rectangle { x: s * 0.63; y: s * 0.06; width: s * 0.07; height: s * 0.26; radius: width / 2; color: m.orange; rotation: 18 }
    Rectangle { x: s * 0.24; y: s * 0.02; width: s * 0.14; height: s * 0.14; radius: width / 2; color: m.orange }
    Rectangle { x: s * 0.62; y: s * 0.02; width: s * 0.14; height: s * 0.14; radius: width / 2; color: m.orange }
    // body
    Rectangle { x: s * 0.10; y: s * 0.26; width: s * 0.80; height: s * 0.66; radius: s * 0.30; color: m.orange }
    // eyes
    Rectangle { x: s * 0.31; y: s * 0.48; width: s * 0.10; height: s * 0.16; radius: width / 2; color: m.dark }
    Rectangle { x: s * 0.59; y: s * 0.48; width: s * 0.10; height: s * 0.16; radius: width / 2; color: m.dark }
    // cheeks
    Rectangle { x: s * 0.20; y: s * 0.64; width: s * 0.12; height: s * 0.07; radius: height / 2; color: "#f4b08f" }
    Rectangle { x: s * 0.68; y: s * 0.64; width: s * 0.12; height: s * 0.07; radius: height / 2; color: "#f4b08f" }
}
