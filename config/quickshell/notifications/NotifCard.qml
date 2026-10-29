import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications

// One notification: icon, text, actions, optional timeout bar. Used by popups and the center list.
Rectangle {
    id: card
    required property var theme
    required property var notif          // Quickshell Notification
    property bool popup: false           // popup mode shows the timeout bar and auto-expires
    property int timeoutMs: 6000
    signal expired()
    signal dismissed()

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property var appIcons: ({
        "firefox": "language", "spotify": "music_note", "discord": "forum", "telegram": "send",
        "whatsapp": "chat", "slack": "tag", "thunderbird": "mail", "evolution": "mail",
        "hyde": "tune", "volume": "volume_up", "brightness": "brightness_6", "calendar": "event",
        "focus": "timer", "satty": "photo_camera", "screenshot": "photo_camera", "grim": "photo_camera", "claude": "smart_toy", "notify-send": "notifications", "battery": "battery_alert", "network": "wifi"
    })
    function iconFor(app) {
        const k = (app || "").toLowerCase()
        for (const name in appIcons) if (k.indexOf(name) >= 0) return appIcons[name]
        return "notifications"
    }
    readonly property bool isClaude: ((notif.appName || "") + " " + (notif.summary || "")).toLowerCase().indexOf("claude") >= 0
    function plain(t) { return (t || "").replace(/<[^>]+>/g, "") }

    implicitHeight: col.implicitHeight + 22 + (popup && !critical && timeoutMs > 0 ? 8 : 0)
    radius: 20
    color: critical ? theme.alpha(theme.mix(theme.card, Qt.color("#f38ba8"), 0.16), 0.95) : theme.alpha(theme.mix(theme.bg, theme.card, 0.9), 0.97)
    border.width: critical ? 1.5 : 1
    border.color: critical ? Qt.color("#f38ba8") : theme.alpha(theme.accent, hov.hovered ? 0.35 : 0.16)
    Behavior on border.color { ColorAnimation { duration: 140 } }
    clip: true

    HoverHandler { id: hov }

    // ---- swipe to dismiss ----
    property real dragX: 0
    property bool leaving: false
    transform: Translate { x: card.dragX }
    opacity: leaving ? 0 : 1 - Math.min(0.6, Math.abs(dragX) / 300)
    Behavior on opacity { enabled: card.leaving; NumberAnimation { duration: 160 } }
    NumberAnimation { id: springBack; target: card; property: "dragX"; to: 0; duration: 240; easing.type: Easing.OutBack }
    NumberAnimation { id: flyOut; target: card; property: "dragX"; duration: 180; easing.type: Easing.InCubic; onFinished: card.dismissed() }
    DragHandler {
        id: swipe
        xAxis.enabled: true; yAxis.enabled: false
        dragThreshold: 28           // a slightly shaky click must not turn into a drag
        grabPermissions: PointerHandler.TakeOverForbidden
        target: null
        onTranslationChanged: if (active) card.dragX = translation.x
        onActiveChanged: {
            if (active) { springBack.stop(); return }
            if (Math.abs(card.dragX) > 110) { card.leaving = true; flyOut.to = card.dragX > 0 ? card.width : -card.width; flyOut.start() }
            else springBack.start()
        }
    }

    // ---- auto-expire (popup mode only) ----
    property real remaining: 1
    NumberAnimation on remaining {
        id: countdown
        running: card.popup && !card.critical && card.timeoutMs > 0 && !hov.hovered && !swipe.active
        from: card.remaining; to: 0
        duration: Math.max(50, card.remaining * card.timeoutMs)
        onFinished: card.expired()
    }

    // safety net: a popup never outlives its timeout by much, even if hover/drag state gets stuck
    Timer {
        running: card.popup && !card.critical && card.timeoutMs > 0
        interval: card.timeoutMs + 12000
        onTriggered: card.expired()
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const d = card.notif.actions.find(a => a.identifier === "default")
            if (d) d.invoke()
            card.dismissed()
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 11
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 13
                Layout.alignment: Qt.AlignTop
                color: card.theme.alpha(card.critical ? card.theme.pink : card.theme.accent, 0.18)
                clip: true
                // real pictures only (cover art, avatars, screenshots); theme-icon URIs fall back to Material
                // Theme-icon URIs: the quickshell icon provider can't resolve some apps (it paints a
                // checkerboard), so look the file up ourselves, trying common locations in turn.
                readonly property bool isThemeIcon: card.notif.image.indexOf("image://icon/") === 0
                readonly property string iconName: isThemeIcon ? card.notif.image.slice(13) : ""
                readonly property bool isFilePath: iconName.charAt(0) === "/"      // e.g. screenshots: app_icon = /tmp/shot.png
                readonly property var candidates: iconName === "" ? [] : isFilePath ? [iconName] : [
                    "/usr/share/icons/hicolor/scalable/apps/" + iconName + ".svg",
                    "/usr/share/icons/hicolor/256x256/apps/" + iconName + ".png",
                    "/usr/share/icons/hicolor/128x128/apps/" + iconName + ".png",
                    "/usr/share/icons/hicolor/64x64/apps/" + iconName + ".png",
                    "/usr/share/icons/hicolor/48x48/apps/" + iconName + ".png",
                    "/usr/share/pixmaps/" + iconName + ".svg",
                    "/usr/share/pixmaps/" + iconName + ".png"
                ]
                property int tryIdx: 0
                readonly property string pictureSource: isThemeIcon ? (tryIdx < candidates.length ? "file://" + candidates[tryIdx] : "") : card.notif.image
                readonly property bool hasPicture: pictureSource !== ""
                Rectangle { id: picMask; anchors.fill: parent; radius: 13; visible: false; antialiasing: true; layer.enabled: true; layer.smooth: true; layer.samples: 4 }
                Image {
                    id: picImg
                    anchors.fill: parent
                    visible: parent.hasPicture && status === Image.Ready
                    source: parent.pictureSource
                    sourceSize: Qt.size(96, 96)
                    smooth: true; mipmap: true; layer.smooth: true
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                    onStatusChanged: if (status === Image.Error) { if (parent.isThemeIcon) parent.tryIdx++; else if (retries < 6) retryTimer.start() }
                    property int retries: 0
                    Timer { id: retryTimer; interval: 120; onTriggered: { picImg.retries++; const s = picImg.source; picImg.source = ""; picImg.source = s } }
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: picMask }
                }
                ClaudeMark {
                    anchors.centerIn: parent; s: 30
                    visible: card.isClaude && !picImg.visible
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !picImg.visible && !card.isClaude
                    name: card.iconFor(card.notif.appName); size: 22; fill: 1
                    color: card.critical ? card.theme.pink : card.theme.accent
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: card.notif.summary
                        color: card.theme.fg; font.family: card.theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                    Text { text: card.notif.appName; color: card.theme.muted; font.family: card.theme.font; font.pixelSize: 9 }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.plain(card.notif.body)
                    wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                    color: card.theme.muted; font.family: card.theme.font; font.pixelSize: 11
                }
            }
            Rectangle {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11
                Layout.alignment: Qt.AlignTop
                color: xma.containsMouse ? card.theme.alpha(card.theme.accent, 0.3) : card.theme.alpha(card.theme.fg, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }
                Icon { anchors.centerIn: parent; name: "close"; size: 14; color: card.theme.fg }
                MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.dismissed() }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: card.notif.actions.length > 0 && repeater.count > 0
            Repeater {
                id: repeater
                model: card.notif.actions.filter(a => a.identifier !== "default")
                Pill {
                    required property var modelData
                    theme: card.theme; text: modelData.text; size: 10
                    onClicked: { modelData.invoke(); card.dismissed() }
                }
            }
        }
    }

    // timeout bar: inset pill inside the card so it never touches the rounded corners
    Rectangle {
        visible: card.popup && !card.critical && card.timeoutMs > 0
        anchors.bottom: parent.bottom; anchors.bottomMargin: 6
        anchors.left: parent.left; anchors.leftMargin: 18
        height: 3; radius: 1.5
        width: (parent.width - 36) * card.remaining
        color: card.theme.alpha(card.theme.accent, 0.7)
    }
}
