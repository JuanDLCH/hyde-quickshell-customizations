import QtQuick

// Base for a tab's content: fades and slides in when active.
Item {
    id: page
    property bool active: false
    opacity: active ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    transform: Translate { x: page.active ? 0 : 14; Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }
}
