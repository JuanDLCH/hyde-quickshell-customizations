import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

// Side control center: header + mascot, quick toggles, sliders, player, next event, grouped notifications.
Scope {
    id: scope
    required property var hub
    required property var pal
    readonly property bool open: hub.centerOpen
    readonly property string home: hub.home
    readonly property string ccScript: home + "/.config/hyde/scripts/control-center.sh"

    // ---------------- toggles ----------------
    property bool wifi: false
    property bool bluetooth: false
    property bool awake: false
    Process {
        id: probe
        command: ["sh", "-c", "for x in wifi bluetooth awake; do echo \"$x $(" + scope.ccScript + " $x-state 2>/dev/null)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const f = l.trim().split(" ")
                    if (f[0] === "wifi") scope.wifi = f[1] === "true"
                    else if (f[0] === "bluetooth") scope.bluetooth = f[1] === "true"
                    else if (f[0] === "awake") scope.awake = f[1] === "true"
                }
            }
        }
    }
    // ---------------- submenus (wifi / bluetooth lists) ----------------
    property string submenu: ""
    property var subItems: []
    property bool subBusy: false
    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                scope.subItems = text.trim().split("\n").filter(l => l !== "").map(l => {
                    const f = l.split("|")
                    return { kind: f[0], id: f[1], name: f[2], signal: parseInt(f[3]) || 0, active: f[4] === "1", secure: f[5] === "1" }
                })
                scope.subBusy = false
            }
        }
    }
    function openSub(kind) {
        if (submenu === kind) { submenu = ""; return }
        submenu = kind; subItems = []; subBusy = true
        lister.command = ["sh", Quickshell.shellDir + "/netlist.sh", kind]
        lister.running = true
    }
    function connectItem(it) {
        if (it.kind === "wifi") {
            const cmd = it.active ? ["nmcli", "connection", "down", "id", it.id]
                                  : ["sh", "-c", "nmcli dev wifi connect \"$1\" >/dev/null 2>&1 || notify-send -a Network 'Wi‑Fi' \"Could not join $1 (needs a saved password?)\"", "sh", it.id]
            Quickshell.execDetached(cmd)
        } else {
            Quickshell.execDetached(["bluetoothctl", it.active ? "disconnect" : "connect", it.id])
        }
        refresher.restart()
    }
    function reloadSub() { if (submenu === "") return; subBusy = true; lister.command = ["sh", Quickshell.shellDir + "/netlist.sh", submenu]; lister.running = true }
    Timer { id: refresher; interval: 2500; onTriggered: scope.reloadSub() }

    function setToggle(name, v) {
        if (name === "dnd") { hub.setDnd(v); return }
        scope[name] = v
        Quickshell.execDetached(["sh", "-c", "SWAYNC_TOGGLE_STATE=" + (v ? "true" : "false") + " " + ccScript + " " + name + "-set"])
    }

    // ---------------- volume / brightness ----------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    property real brightness: 0.5
    Process {
        id: bright
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector { onStreamFinished: { const f = text.trim().split(","); if (f.length > 3) scope.brightness = parseInt(f[3]) / 100 } }
    }
    function setBrightness(f) { brightness = f; Quickshell.execDetached(["brightnessctl", "set", Math.max(5, Math.round(f * 100)) + "%"]) }

    // ---------------- player ----------------
    readonly property var player: {
        const list = Mpris.players.values
        for (const p of list) if (p.isPlaying) return p
        return list.length > 0 ? list[0] : null
    }
    Timer { interval: 1000; repeat: true; running: scope.open && scope.player !== null && scope.player.isPlaying; onTriggered: scope.player.positionChanged() }

    // ---------------- next event ----------------
    property var nextEv: null
    property var calData: null
    readonly property string py: home + "/.local/share/hyde-calendar/venv/bin/python"
    Process {
        id: cal
        command: [scope.py, scope.home + "/.local/share/hyde-calendar/app/calendar_json.py", "snapshot"]
        stdout: StdioCollector { onStreamFinished: { try { scope.calData = JSON.parse(text); scope.findNext() } catch (e) {} } }
    }
    function pad(n) { return n < 10 ? "0" + n : "" + n }
    function findNext() {
        if (!calData) return
        const now = new Date()
        for (let k = 0; k < 3; k++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + k)
            const key = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
            for (const e of (calData.days[key] || [])) {
                if (e.allDay) continue
                const end = new Date(key + "T" + e.end + ":00")
                if (end > now) { nextEv = { ev: e, start: new Date(key + "T" + e.start + ":00"), key: key }; return }
            }
        }
        nextEv = null
    }
    function whenText(n) {
        const mins = Math.round((n.start - new Date()) / 60000)
        if (mins <= 0) return "now"
        if (mins < 60) return "in " + mins + " min"
        if (n.key !== new Date().toISOString().slice(0, 10) && mins > 600) return "tomorrow " + n.ev.start
        return "in " + Math.floor(mins / 60) + " h " + (mins % 60) + " min"
    }
    function meetingUrl(ev) {
        if (!ev) return ""
        if (ev.videoUrl) return ev.videoUrl
        const m = /https?:\/\/[^\s<>"]*(zoom\.us|meet\.google\.com|teams\.microsoft\.com|webex\.com)[^\s<>"]*/i.exec((ev.description || "") + " " + (ev.location || ""))
        return m ? m[0] : ""
    }

    Connections { target: scope.hub; function onSubRequestChanged() { if (scope.hub.subRequest !== "") { scope.submenu = ""; scope.openSub(scope.hub.subRequest); scope.hub.subRequest = "" } } }
    Timer { id: nudgeTimer; interval: 160; onTriggered: Quickshell.execDetached([Quickshell.shellDir + "/nudge.sh"]) }
    onOpenChanged: { nudgeTimer.restart(); if (open) { probe.running = true; bright.running = true; cal.running = true } else submenu = "" }

    // ---------------- click-outside catcher (below the bar) ----------------
    PanelWindow {
        screen: scope.hub.targetScreen
        visible: scope.open
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: scope.hub.barBottom
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-notif-backdrop"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: scope.hub.centerOpen = false }
    }

    // ---------------- the panel ----------------
    PanelWindow {
        id: win
        screen: scope.hub.targetScreen
        visible: scope.open || slide.running
        color: "transparent"
        anchors { top: true; right: true; bottom: true }
        margins { top: scope.hub.barBottom; right: 0; bottom: 0 }
        implicitWidth: 372
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-notif-center"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: scope.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Item {
            id: holder
            width: 360; height: parent.height
            x: scope.open ? 12 : 392
            opacity: scope.open ? 1 : 0
            Behavior on x { NumberAnimation { id: slide; duration: 340; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 240 } }

            Rectangle {
                id: bg
                anchors.fill: parent
                radius: 0
                color: "transparent"
                focus: scope.open
                clip: true
                Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { scope.hub.centerOpen = false; e.accepted = true } }

                // body overshoots 24px to the right and is clipped, so the screen-edge corners stay square with no seam
                Rectangle { width: parent.width + 24; height: parent.height; radius: 24; color: scope.pal.alpha(scope.pal.bg, 0.97) }

                // theme wallpaper as soft background art
                Rectangle { id: wallMask; width: parent.width + 24; height: parent.height; radius: 24; visible: false; layer.enabled: true }
                Image {
                    width: parent.width + 24; height: parent.height   // same size as wallMask, which MultiEffect stretches to the source
                    source: "file://" + scope.home + "/.cache/hyde/wall.blur"
                    fillMode: Image.PreserveAspectCrop; cache: false; asynchronous: true
                    opacity: 0.26
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: wallMask }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // ---------- toggles ----------
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: ["wifi", "bluetooth", "dnd", "awake"]     // static: never rebuilt, so no flicker
                            Tile {
                                id: tg
                                required property string modelData
                                required property int index
                                readonly property var meta: ({
                                    wifi: { icon: "wifi", off: "wifi_off", label: "Wi‑Fi", on: scope.wifi, sub: true },
                                    bluetooth: { icon: "bluetooth", off: "bluetooth_disabled", label: "Bluetooth", on: scope.bluetooth, sub: true },
                                    dnd: { icon: "do_not_disturb_on", off: "notifications_active", label: "Silent", on: scope.hub.dnd, sub: false },
                                    awake: { icon: "coffee", off: "coffee", label: "Awake", on: scope.awake, sub: false }
                                })[modelData]
                                theme: scope.pal; order: 1 + index; shown: scope.open
                                Layout.fillWidth: true; Layout.preferredHeight: 64
                                tone: meta.on ? scope.pal.alpha(scope.pal.accent, 0.85) : scope.pal.alpha(scope.pal.card, 0.62)
                                onClicked: scope.setToggle(modelData, !meta.on)
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: tg.meta.on ? tg.meta.icon : tg.meta.off; size: 22; fill: tg.meta.on ? 1 : 0; color: tg.meta.on ? scope.pal.bg : scope.pal.fg }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: tg.meta.label; color: tg.meta.on ? scope.pal.bg : scope.pal.muted; font.family: scope.pal.font; font.pixelSize: 9; font.weight: Font.Medium }
                                }
                                // chevron: opens the submenu
                                Rectangle {
                                    visible: tg.meta.sub
                                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 3
                                    width: 22; height: 22; radius: 11
                                    color: chev.containsMouse ? scope.pal.alpha(tg.meta.on ? scope.pal.bg : scope.pal.fg, 0.2) : "transparent"
                                    Icon {
                                        anchors.centerIn: parent; name: "expand_more"; size: 18
                                        color: tg.meta.on ? scope.pal.bg : scope.pal.muted
                                        rotation: scope.submenu === tg.modelData ? 180 : 0
                                        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    }
                                    MouseArea { id: chev; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: scope.openSub(tg.modelData) }
                                }
                            }
                        }
                    }

                    // ---------- submenu (wifi networks / bluetooth devices) ----------
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: scope.submenu !== "" ? 188 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        clip: true
                        opacity: scope.submenu !== "" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Rectangle {
                            anchors.fill: parent
                            radius: 20
                            color: scope.pal.alpha(scope.pal.mix(scope.pal.card, scope.pal.accent, 0.1), 0.8)
                            border.width: 1; border.color: scope.pal.alpha(scope.pal.accent, 0.2)
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: scope.submenu === "wifi" ? "Wi‑Fi networks" : "Bluetooth devices"; color: scope.pal.fg; font.family: scope.pal.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Icon { name: "refresh"; size: 18; color: scope.pal.muted; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.reloadSub() } }
                                    Icon { name: "settings"; size: 18; color: scope.pal.muted; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached([scope.submenu === "wifi" ? "nm-connection-editor" : "blueman-manager"]); scope.hub.centerOpen = false } } }
                                }
                                ListView {
                                    id: subList
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    clip: true; spacing: 2
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: ScriptModel { values: scope.subItems; objectProp: "id" }
                                    delegate: Rectangle {
                                        id: it
                                        required property var modelData
                                        width: subList.width; height: 34; radius: 12
                                        color: ima.containsMouse ? scope.pal.alpha(scope.pal.accent, 0.18) : modelData.active ? scope.pal.alpha(scope.pal.accent, 0.12) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                            Icon {
                                                name: modelData.kind === "wifi" ? (modelData.signal > 66 ? "network_wifi_3_bar" : modelData.signal > 33 ? "network_wifi_2_bar" : "network_wifi_1_bar") : "bluetooth"
                                                size: 18; fill: 1; color: modelData.active ? scope.pal.accent : scope.pal.muted
                                            }
                                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.name; color: scope.pal.fg; font.family: scope.pal.font; font.pixelSize: 11; font.weight: modelData.active ? Font.DemiBold : Font.Normal }
                                            Icon { visible: modelData.secure; name: "lock"; size: 14; color: scope.pal.muted }
                                            Text { visible: modelData.active; text: "connected"; color: scope.pal.accent; font.family: scope.pal.font; font.pixelSize: 9 }
                                        }
                                        MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: scope.connectItem(it.modelData) }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: scope.subItems.length === 0
                                        text: scope.subBusy ? "Scanning…" : scope.submenu === "wifi" ? "No networks found" : "No paired devices"
                                        color: scope.pal.muted; font.family: scope.pal.font; font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    // ---------- sliders ----------
                    Tile {
                        theme: scope.pal; order: 5; shown: scope.open; interactive: false
                        Layout.fillWidth: true; Layout.preferredHeight: 82
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 4
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Icon {
                                    name: scope.muted || scope.volume === 0 ? "volume_off" : scope.volume < 0.5 ? "volume_down" : "volume_up"
                                    size: 20; fill: 1; color: scope.muted ? scope.pal.muted : scope.pal.accent
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (scope.sink && scope.sink.audio) scope.sink.audio.muted = !scope.sink.audio.muted }
                                }
                                WavyBar {
                                    Layout.fillWidth: true; Layout.preferredHeight: 18
                                    theme: scope.pal; seekable: true; amplitude: 0
                                    progress: scope.volume
                                    onDragging: f => { if (scope.sink && scope.sink.audio) scope.sink.audio.volume = f }
                                    onSeekTo: f => { if (scope.sink && scope.sink.audio) scope.sink.audio.volume = f }
                                }
                                Text { text: Math.round(scope.volume * 100) + "%"; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; color: scope.pal.muted; font.family: scope.pal.font; font.pixelSize: 10 }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Icon { name: "brightness_6"; size: 20; fill: 1; color: scope.pal.pink }
                                WavyBar {
                                    Layout.fillWidth: true; Layout.preferredHeight: 18
                                    theme: scope.pal; seekable: true; amplitude: 0
                                    progress: scope.brightness
                                    onDragging: f => scope.setBrightness(f)
                                    onSeekTo: f => scope.setBrightness(f)
                                }
                                Text { text: Math.round(scope.brightness * 100) + "%"; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; color: scope.pal.muted; font.family: scope.pal.font; font.pixelSize: 10 }
                            }
                        }
                    }

                    // ---------- player ----------
                    Tile {
                        theme: scope.pal; order: 6; shown: scope.open
                        visible: scope.player !== null
                        Layout.fillWidth: true; Layout.preferredHeight: scope.player !== null ? 92 : 0
                        onClicked: { Quickshell.execDetached(["quickshell", "ipc", "-c", "calendar", "call", "calendar", "tab", "2"]); scope.hub.centerOpen = false }
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 2
                            RowLayout {
                                Layout.fillWidth: true; spacing: 9
                                Item {
                                    Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                    Rectangle { id: artMask; anchors.fill: parent; radius: 13; visible: false; layer.enabled: true }
                                    Rectangle { anchors.fill: parent; radius: 13; color: scope.pal.alpha(scope.pal.accent, 0.2) }
                                    Image {
                                        anchors.fill: parent
                                        source: scope.player ? scope.player.trackArtUrl : ""
                                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                                        layer.enabled: true
                                        layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: scope.player ? scope.player.trackTitle : ""; color: scope.pal.fg; font.family: scope.pal.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: scope.player ? scope.player.trackArtist : ""; color: scope.pal.accent; font.family: scope.pal.font; font.pixelSize: 10 }
                                }
                                Icon { name: "skip_previous"; size: 22; fill: 1; color: scope.pal.fg; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (scope.player) scope.player.previous() } }
                                Icon { name: scope.player && scope.player.isPlaying ? "pause_circle" : "play_circle"; size: 32; fill: 1; color: scope.pal.accent; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (scope.player) scope.player.togglePlaying() } }
                                Icon { name: "skip_next"; size: 22; fill: 1; color: scope.pal.fg; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (scope.player) scope.player.next() } }
                            }
                            WavyBar {
                                Layout.fillWidth: true; Layout.preferredHeight: 14
                                theme: scope.pal; amplitude: playing ? 2 : 0; wavelength: 16
                                progress: scope.player && scope.player.length > 0 ? Math.min(1, scope.player.position / scope.player.length) : 0
                                playing: scope.player !== null && scope.player.isPlaying
                                seekable: scope.player !== null && scope.player.canSeek
                                onSeekTo: f => scope.player.position = f * scope.player.length
                            }
                        }
                    }

                    // ---------- next event ----------
                    Tile {
                        theme: scope.pal; order: 7; shown: scope.open
                        visible: scope.nextEv !== null
                        Layout.fillWidth: true; Layout.preferredHeight: scope.nextEv !== null ? 44 : 0
                        onClicked: { Quickshell.execDetached(["quickshell", "ipc", "-c", "calendar", "call", "calendar", "tab", "1"]); scope.hub.centerOpen = false }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                            Rectangle { Layout.preferredWidth: 4; Layout.preferredHeight: 26; radius: 2; color: scope.nextEv ? scope.nextEv.ev.color : "transparent" }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: scope.nextEv ? scope.nextEv.ev.title : ""; color: scope.pal.fg; font.family: scope.pal.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                                Text { text: scope.nextEv ? scope.whenText(scope.nextEv) + " · " + scope.nextEv.ev.start : ""; color: scope.pal.muted; font.family: scope.pal.font; font.pixelSize: 10 }
                            }
                            Pill {
                                visible: scope.nextEv !== null && scope.meetingUrl(scope.nextEv.ev) !== ""
                                theme: scope.pal; strong: true; text: "Join"; size: 10
                                onClicked: { Quickshell.execDetached(["xdg-open", scope.meetingUrl(scope.nextEv.ev)]); scope.hub.centerOpen = false }
                            }
                        }
                    }

                    // ---------- notifications ----------
                    RowLayout {
                        Layout.fillWidth: true; Layout.topMargin: 2
                        Text { Layout.fillWidth: true; text: "Notifications"; color: scope.pal.fg; font.family: scope.pal.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Pill { theme: scope.pal; text: "Clear all"; visible: scope.hub.count > 0; onClicked: scope.hub.clearAll() }
                    }

                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 80
                        ListView {
                            id: groupsView
                            anchors.fill: parent
                            clip: true; spacing: 10
                            boundsBehavior: Flickable.StopAtBounds
                            model: ScriptModel { values: scope.hub.groups; objectProp: "app" }
                            delegate: Item {
                                id: g
                                required property var modelData
                                width: groupsView.width
                                height: gcol.implicitHeight
                                readonly property bool folded: !!scope.hub.collapsed[modelData.app]
                                Column {
                                    id: gcol
                                    width: parent.width
                                    spacing: 6
                                    RowLayout {
                                        width: parent.width; height: 22; spacing: 6
                                        Icon { name: g.folded ? "chevron_right" : "expand_more"; size: 18; color: scope.pal.accent }
                                        Text { text: g.modelData.app; color: scope.pal.muted; font.family: scope.pal.font; font.pixelSize: 11; font.weight: Font.Medium }
                                        Rectangle {
                                            implicitWidth: cnt.implicitWidth + 12; implicitHeight: 16; radius: 8
                                            color: scope.pal.alpha(scope.pal.accent, 0.2)
                                            Text { id: cnt; anchors.centerIn: parent; text: g.modelData.items.length; color: scope.pal.fg; font.family: scope.pal.font; font.pixelSize: 9 }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Icon {
                                            name: "close"; size: 16; color: scope.pal.muted
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.hub.clearGroup(g.modelData.app) }
                                        }
                                        MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: scope.hub.toggleCollapsed(g.modelData.app) }
                                    }
                                    Repeater {
                                        model: g.folded ? [] : g.modelData.items
                                        NotifCard {
                                            required property var modelData
                                            width: gcol.width
                                            theme: scope.pal; notif: modelData
                                            onDismissed: scope.hub.dismiss(modelData)
                                            opacity: 0
                                            Component.onCompleted: opacity = 1
                                            Behavior on opacity { NumberAnimation { duration: 220 } }
                                        }
                                    }
                                }
                            }
                        }

                        // empty state
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 6
                            visible: scope.hub.count === 0
                            Icon { Layout.alignment: Qt.AlignHCenter; name: "notifications_paused"; size: 34; fill: 1; color: scope.pal.alpha(scope.pal.accent, 0.6) }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "No new notifications"; color: scope.pal.muted; font.family: scope.pal.font; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }
    }
}
