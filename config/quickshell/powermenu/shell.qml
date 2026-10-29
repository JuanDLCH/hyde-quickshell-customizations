import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Power menu: glass tiles with the action name underneath each one.
ShellRoot {
    id: root
    readonly property string icons: Quickshell.env("HOME") + "/.config/wlogout/icons/"
    property bool active: false
    property int cur: -1

    Theme { id: pal }

    readonly property var actions: [
        { id: "lock",      label: "Lock",      key: Qt.Key_L, color: "#b4befe", cmd: ["lockscreen.sh"] },
        { id: "logout",    label: "Logout",    key: Qt.Key_E, color: "#fab387", cmd: ["hyde-shell", "logout"] },
        { id: "suspend",   label: "Suspend",   key: Qt.Key_U, color: "#94e2d5", cmd: ["systemctl", "suspend"] },
        { id: "shutdown",  label: "Shutdown",  key: Qt.Key_S, color: "#f38ba8", cmd: ["systemctl", "poweroff"] },
        { id: "hibernate", label: "Hibernate", key: Qt.Key_H, color: "#cba6f7", cmd: ["systemctl", "hibernate"] },
        { id: "reboot",    label: "Reboot",    key: Qt.Key_R, color: "#f9e2af", cmd: ["systemctl", "reboot"] }
    ]

    function run(i) {
        active = false
        Quickshell.execDetached(actions[i].cmd)
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.cur = -1; root.active = !root.active }
    }

    PanelWindow {
        visible: root.active
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "logout_dialog"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) root.active = false
                else if (e.key === Qt.Key_Left) root.cur = root.cur < 0 ? 5 : (root.cur + 5) % 6
                else if (e.key === Qt.Key_Right) root.cur = (root.cur + 1) % 6
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (root.cur >= 0) root.run(root.cur) }
                else for (let i = 0; i < 6; i++) if (root.actions[i].key === e.key) root.run(i)
            }

            Rectangle { anchors.fill: parent; color: pal.bg; opacity: 0.30 }
            MouseArea { anchors.fill: parent; onClicked: root.active = false }

            Row {
                anchors.centerIn: parent
                spacing: 16
                Repeater {
                    model: root.actions
                    delegate: Column {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool hot: root.cur === index
                        spacing: 14

                        Rectangle {
                            width: 104; height: 104; radius: 26
                            color: item.hot ? item.modelData.color : Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.42)
                            border.width: 1
                            border.color: item.hot ? "transparent" : Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.13)
                            Behavior on color { ColorAnimation { duration: 110 } }
                            Image {
                                anchors.centerIn: parent
                                width: 40; height: 40
                                sourceSize: Qt.size(80, 80)
                                smooth: true
                                source: "file://" + root.icons + item.modelData.id + (item.hot ? "_black" : "_white") + ".png"
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.cur = item.index
                                onClicked: root.run(item.index)
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: item.modelData.label
                            font.family: "Inter"; font.pixelSize: 15; font.weight: Font.Medium
                            color: item.hot ? "#ffffff" : Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.6)
                        }
                    }
                }
            }
        }
    }
}
