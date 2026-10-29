import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Toast stack, top-right under the bar. Never steals focus; only the cards take input.
Scope {
    id: scope
    required property var hub
    required property var pal

    PanelWindow {
        id: win
        screen: scope.hub.targetScreen
        visible: scope.hub.popups.length > 0 || hold.running
        color: "transparent"
        anchors { bottom: true; right: true }
        margins { bottom: 10; right: 8 }
        implicitWidth: 372
        implicitHeight: Math.max(1, list.contentHeight + 12)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-notif-popups"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: list }

        Timer { id: hold; interval: 450 }
        Connections { target: scope.hub; function onPopupsChanged() { hold.restart() } }

        ListView {
            id: list
            width: 360; x: 6
            height: contentHeight
            anchors.bottom: parent.bottom; anchors.bottomMargin: 6
            verticalLayoutDirection: ListView.BottomToTop
            interactive: false
            spacing: 8
            model: ScriptModel { values: scope.hub.popups }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: 380; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                }
            }
            remove: Transition {
                ScriptAction { script: hold.restart() }
                ParallelAnimation {
                    NumberAnimation { property: "x"; to: 380; duration: 260; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: 240 }
                }
            }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic } }

            delegate: Item {
                id: row
                required property var modelData
                width: list.width
                height: card.implicitHeight
                NotifCard {
                    id: card
                    width: parent.width
                    theme: scope.pal
                    notif: row.modelData
                    popup: true
                    timeoutMs: row.modelData.expireTimeout > 0 ? Math.max(2500, row.modelData.expireTimeout)   // quickshell reports milliseconds
                             : row.modelData.urgency === NotificationUrgency.Low ? 4000 : 6000
                    onExpired: scope.hub.hidePopup(row.modelData)
                    onDismissed: scope.hub.dismiss(row.modelData)
                }
            }
        }
    }
}
