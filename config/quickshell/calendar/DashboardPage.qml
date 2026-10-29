import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

// Bento dashboard: greeting + clock, weather, mascot, mini calendar, gauges, mini player.
TabPage {
    id: page
    required property var theme
    required property var hub        // shell root: data, calendar helpers, navigation
    required property var sys        // SystemPage (cpu/mem/disk/bat)
    required property var media      // MediaPage (player, weather)
    required property var pomo       // FocusPage (pomodoro)
    property string forceMood: ""

    SystemClock { id: clock; precision: SystemClock.Minutes }
    Timer {
        interval: 1000; repeat: true
        running: page.active && page.playing
        onTriggered: page.media.player.positionChanged()
    }

    // ---------------- derived state ----------------
    readonly property int hour: clock.date.getHours()
    readonly property bool night: hour >= 22 || hour < 6
    readonly property bool playing: media.player !== null && media.player.isPlaying
    readonly property string mood: forceMood !== "" ? forceMood
        : sys.cpu > 0.85 ? "tired"
        : (pomo.running && !pomo.onBreak) ? "focus"
        : playing ? "dance"
        : (pomo.running && pomo.onBreak) ? "rest"
        : night ? "sleep" : "idle"
    readonly property var faces: ({ idle: "", dance: "vibing", sleep: "zzZ", focus: "focus mode", tired: "so tired", rest: "snack time" })
    readonly property string userName: {
        const u = Quickshell.env("USER") || "friend"
        return u.charAt(0).toUpperCase() + u.slice(1)
    }
    readonly property string greeting: hour < 6 ? "Up late, " : hour < 12 ? "Good morning, " : hour < 19 ? "Good afternoon, " : "Good evening, "

    function nextEvent() {
        const now = clock.date
        for (let k = 0; k < 3; k++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + k)
            const key = hub.iso(d)
            for (const e of (hub.data.days[key] || [])) {
                if (e.allDay) continue
                const start = new Date(key + "T" + e.start + ":00")
                const end = new Date(key + "T" + e.end + ":00")
                if (end > now) return { ev: e, start: start, end: end, key: key }
            }
        }
        return null
    }
    readonly property var next: { clock.date; hub.data; return nextEvent() }
    function whenText(n) {
        const mins = Math.round((n.start - clock.date) / 60000)
        if (mins <= 0) return "now"
        if (mins < 60) return "in " + mins + " min"
        if (n.key !== hub.iso(clock.date)) return "tomorrow " + n.ev.start
        return "in " + Math.floor(mins / 60) + " h " + (mins % 60) + " min"
    }
    function warn(v) { return v > 0.85 ? "#f38ba8" : null }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // ---------- gauges (slim column) ----------
        Tile {
            theme: page.theme; order: 4; shown: page.active
            Layout.preferredWidth: 78; Layout.fillHeight: true
            onClicked: page.hub.setTab(3)
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 6; anchors.bottomMargin: 6
                spacing: 0
                Repeater {
                    model: [
                        { icon: "memory", label: "CPU", v: page.sys.cpu, t: page.theme.accent },
                        { icon: "developer_board", label: "RAM", v: page.sys.memUsed / Math.max(1, page.sys.memTotal), t: page.theme.pink },
                        { icon: "storage", label: "Disk", v: page.sys.diskUsed / Math.max(1, page.sys.diskTotal), t: "#89dceb" },
                        { icon: page.sys.batStatus === "Charging" ? "battery_charging_full" : "battery_full", label: "Bat", v: Math.max(0, page.sys.bat) / 100, t: "#a6e3a1" }
                    ]
                    Item {
                        required property var modelData
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Ring {
                                anchors.horizontalCenter: parent.horizontalCenter
                                theme: page.theme; implicitWidth: 42; implicitHeight: 42; width: 42; height: 42; thickness: 4
                                value: modelData.v; icon: modelData.icon
                                tint: modelData.label !== "Bat" && modelData.v > 0.85 ? "#f38ba8" : modelData.t
                                onClicked: page.hub.setTab(3)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(modelData.v * 100) + "%"
                                color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 11; font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 1; Layout.horizontalStretchFactor: 3
            spacing: 8
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 6
                spacing: 8
        // ---------- greeting + clock + next event ----------
        Tile {
            theme: page.theme; order: 0; shown: page.active
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1; Layout.horizontalStretchFactor: 5; Layout.verticalStretchFactor: 6
            onClicked: { page.hub.selected = new Date(); page.hub.setTab(1) }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 0
                Text {
                    text: page.greeting + page.userName + " ~"
                    color: page.theme.accent; font.family: page.theme.font; font.pixelSize: 12; font.weight: Font.Medium
                }
                RowLayout {
                    spacing: 12
                    Text {
                        id: timeText
                        text: Qt.formatTime(clock.date, "hh") + ":" + Qt.formatTime(clock.date, "mm")
                        color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 38; font.weight: Font.Bold
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: Qt.formatDate(clock.date, "dddd"); color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                        Text { text: Qt.formatDate(clock.date, "d MMMM"); color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 11 }
                    }
                }
                Item { Layout.fillHeight: true }
                // next event chip
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 13
                    color: page.theme.alpha(page.theme.accent, chipHit.containsMouse ? 0.26 : 0.16)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9; anchors.rightMargin: 4
                        spacing: 6
                        Icon { name: page.next ? "event" : "event_available"; size: 15; fill: 1; color: page.theme.accent }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: page.next ? page.next.ev.title + " · " + page.whenText(page.next) : "Nothing planned"
                            color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 10
                        }
                        Rectangle {
                            visible: page.next && page.hub.meetingUrl(page.next.ev) !== ""
                            Layout.preferredHeight: 18; Layout.preferredWidth: joinText.implicitWidth + 14; radius: 9
                            color: page.theme.accent
                            Text { id: joinText; anchors.centerIn: parent; text: "Join"; color: page.theme.bg; font.family: page.theme.font; font.pixelSize: 9; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.hub.openUrl(page.hub.meetingUrl(page.next.ev)) }
                        }
                    }
                    MouseArea {
                        id: chipHit
                        anchors.fill: parent; z: -1; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: page.next !== null
                        onClicked: { page.hub.selected = new Date(page.next.key + "T12:00:00"); page.hub.setTab(1); page.hub.detail = page.next.ev }
                    }
                }
            }
        }

        // ---------- weather ----------
        Tile {
            theme: page.theme; order: 1; shown: page.active
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1; Layout.horizontalStretchFactor: 3; Layout.verticalStretchFactor: 6
            onClicked: page.hub.setTab(2)
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 1
                visible: page.media.wx !== null
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Icon { name: page.media.wx ? page.media.code(page.media.wx.current.weather_code)[0] : ""; size: 30; fill: 1; color: page.theme.accent }
                    Text { text: page.media.wx ? Math.round(page.media.wx.current.temperature_2m) + "°" : ""; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 24; font.weight: Font.Bold }
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: page.media.wx ? page.media.code(page.media.wx.current.weather_code)[1] : ""; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10 }
            }
            Icon { anchors.centerIn: parent; visible: page.media.wx === null; name: "cloud_sync"; size: 24; color: page.theme.muted }
        }

            }
        // ---------- mini calendar ----------
        Tile {
            theme: page.theme; order: 3; shown: page.active
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 7
            onClicked: page.hub.setTab(1)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Icon {
                        name: "chevron_left"; size: 20; color: page.theme.accent
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.hub.shiftMonth(-1) }
                    }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        text: page.hub.months[page.hub.pendingMonth.getMonth()] + " " + page.hub.pendingMonth.getFullYear()
                        color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
                    }
                    Icon {
                        name: "chevron_right"; size: 20; color: page.theme.accent
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.hub.shiftMonth(1) }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 0
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        Text { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10 }
                    }
                }
                Grid {
                    id: miniGrid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    columns: 7
                    Repeater {
                        model: page.hub.cells
                        Item {
                            id: mc
                            required property var modelData
                            width: miniGrid.width / 7; height: miniGrid.height / 6
                            readonly property bool out: modelData.getMonth() !== page.hub.month.getMonth()
                            readonly property bool today: page.hub.isToday(modelData)
                            readonly property bool sel: page.hub.iso(modelData) === page.hub.iso(page.hub.selected)
                            readonly property var cols: page.hub.colorsFor(modelData)
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 2; height: width; radius: width * 0.38
                                color: mc.today ? page.theme.accent : mcHit.containsMouse ? page.theme.alpha(page.theme.accent, 0.22) : "transparent"
                                border.width: mc.sel && !mc.today ? 1 : 0; border.color: page.theme.accent
                                scale: mcHit.pressed ? 0.88 : 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: mc.modelData.getDate()
                                        color: mc.today ? page.theme.bg : mc.out ? page.theme.alpha(page.theme.fg, 0.35) : page.theme.fg
                                        font.family: page.theme.font; font.pixelSize: 12; font.weight: mc.today ? Font.Bold : Font.Normal
                                    }
                                    // fixed-height row: numbers stay aligned whether or not a day has events
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: 5; spacing: 2
                                        Repeater {
                                            model: mc.cols.slice(0, 3)
                                            Rectangle {
                                                required property string modelData
                                                width: 4; height: 4; radius: 2
                                                color: mc.today ? page.theme.bg : modelData
                                            }
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: mcHit
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { page.hub.choose(mc.modelData); page.hub.setTab(1) }
                            }
                        }
                    }
                }
            }
        }

        }
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 180; Layout.maximumWidth: 180
            spacing: 8
            // ---------- mini player ----------
            Tile {
                theme: page.theme; order: 5; shown: page.active
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 6
                onClicked: page.hub.setTab(2)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 0
                    visible: page.media.player !== null
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Item {
                            Layout.preferredWidth: 46; Layout.preferredHeight: 46
                            Rectangle { id: miniMask; anchors.fill: parent; radius: 13; visible: false; layer.enabled: true }
                            Rectangle { anchors.fill: parent; radius: 13; color: page.theme.alpha(page.theme.accent, 0.2) }
                            Image {
                                anchors.fill: parent
                                source: page.media.player ? page.media.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop; asynchronous: true
                                layer.enabled: true
                                layer.effect: MultiEffect { maskEnabled: true; maskSource: miniMask }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: page.media.player ? page.media.player.trackTitle : ""; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: page.media.player ? page.media.player.trackArtist : ""; color: page.theme.accent; font.family: page.theme.font; font.pixelSize: 10 }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        visible: page.media.player && page.media.player.lengthSupported && page.media.player.length > 0
                        WavyBar {
                            Layout.fillWidth: true; Layout.preferredHeight: 14
                            theme: page.theme
                            amplitude: playing ? 2.2 : 0
                            wavelength: 16
                            progress: page.media.player && page.media.player.length > 0 ? Math.min(1, page.media.player.position / page.media.player.length) : 0
                            playing: page.playing
                            seekable: page.media.player !== null && page.media.player.canSeek
                            onSeekTo: f => page.media.player.position = f * page.media.player.length
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: page.media.player ? page.media.fmt(page.media.player.position) : ""; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 9 }
                            Text { text: page.media.player ? page.media.fmt(page.media.player.length) : ""; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 9 }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 14
                        Icon { name: "skip_previous"; size: 22; fill: 1; color: page.theme.fg; opacity: page.media.player && page.media.player.canGoPrevious ? 1 : 0.35
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.media.player.previous() } }
                        Icon { name: page.playing ? "pause_circle" : "play_circle"; size: 32; fill: 1; color: page.theme.accent
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.media.player.togglePlaying() } }
                        Icon { name: "skip_next"; size: 22; fill: 1; color: page.theme.fg; opacity: page.media.player && page.media.player.canGoNext ? 1 : 0.35
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.media.player.next() } }
                    }
                }
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 2; visible: page.media.player === null
                    Icon { Layout.alignment: Qt.AlignHCenter; name: "music_off"; size: 28; fill: 1; color: page.theme.muted }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Nothing playing"; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10 }
                }
            }
        // ---------- mascot ----------
        Tile {
            id: mascotTile
            theme: page.theme; order: 2; shown: page.active
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 7
            tone: page.theme.alpha(page.theme.mix(page.theme.card, page.theme.pink, 0.22), 0.7)
            onClicked: { hop.restart(); heart.restart() }

            Text {
                anchors.top: parent.top; anchors.topMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
                text: page.faces[page.mood]
                color: page.theme.fg; font.pixelSize: 12; font.family: page.theme.font
            }
            Mascot {
                id: mascot
                theme: page.theme
                mood: page.mood
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: baseOffset
                property real baseOffset: 6
                Behavior on baseOffset { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                width: parent.width - 24; height: Math.min(parent.width - 24, parent.height - 80)
                SequentialAnimation { id: hop
                    NumberAnimation { target: mascot; property: "anchors.verticalCenterOffset"; to: mascot.baseOffset - 18; duration: 140; easing.type: Easing.OutQuad }
                    NumberAnimation { target: mascot; property: "anchors.verticalCenterOffset"; to: mascot.baseOffset; duration: 260; easing.type: Easing.OutBounce }
                }
            }
            Text {
                id: heartText
                text: "♥"; color: page.theme.pink; font.pixelSize: 18
                x: parent.width / 2 - width / 2; y: parent.height * 0.4
                opacity: 0
                SequentialAnimation { id: heart
                    ParallelAnimation {
                        NumberAnimation { target: heartText; property: "y"; from: mascotTile.height * 0.5; to: mascotTile.height * 0.2; duration: 700; easing.type: Easing.OutCubic }
                        SequentialAnimation {
                            NumberAnimation { target: heartText; property: "opacity"; to: 1; duration: 120 }
                            NumberAnimation { target: heartText; property: "opacity"; to: 0; duration: 580 }
                        }
                    }
                }
            }
            // pomodoro bubble
            Rectangle {
                visible: page.pomo.running
                anchors.bottom: parent.bottom; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter
                height: 18; width: pomoText.implicitWidth + 16; radius: 9
                color: page.theme.alpha(page.theme.accent, 0.25)
                Text { id: pomoText; anchors.centerIn: parent; text: (page.pomo.onBreak ? "☕ " : "🍅 ") + page.pomo.clock; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 9 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.hub.setTab(4) }
            }
        }

        }
    }
}
