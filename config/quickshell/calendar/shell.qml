import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Calendar popup that drops from the Waybar clock. Data comes from the existing
// hyde-calendar backend (Google -> SQLite); this file is presentation only.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string appDir: home + "/.local/share/hyde-calendar/app"
    readonly property string py: home + "/.local/share/hyde-calendar/venv/bin/python"
    readonly property int barBottom: 42   // Waybar bottom edge; the card hangs 2px below it
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    property bool open: false
    property var detail: null
    property int tab: 0
    property bool copied: false
    property bool busy: false
    property bool showSettings: false
    property var targetScreen: Quickshell.screens[0]
    property var data: ({ connected: false, hasClient: false, error: "", lastSync: 0, today: "", calendars: [], days: ({}) })
    property date selected: new Date()
    property date month: new Date(selected.getFullYear(), selected.getMonth(), 1)
    property int slideDir: 1
    property date pendingMonth: month

    readonly property var cells: buildCells(month)
    readonly property var dayEvents: data.days[iso(selected)] || []

    function pad(n) { return n < 10 ? "0" + n : "" + n }
    function iso(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    function ym(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) }
    function buildCells(m) {
        const first = new Date(m.getFullYear(), m.getMonth(), 1)
        const offset = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) out.push(new Date(m.getFullYear(), m.getMonth(), 1 - offset + i))
        return out
    }
    function colorsFor(d) {
        const evs = data.days[iso(d)] || []
        const seen = {}
        for (const e of evs) seen[e.calendar] = e.color
        return Object.values(seen)
    }
    function isToday(d) { return iso(d) === (data.today || iso(new Date())) }

    // ---- state changes -------------------------------------------------
    function goMonth(target, dir) {
        if (ym(target) === ym(month)) return
        slideDir = dir
        pendingMonth = new Date(target.getFullYear(), target.getMonth(), 1)
        monthAnim.restart()
        requestMonth(pendingMonth)
    }
    function shiftMonth(delta) {
        goMonth(new Date(month.getFullYear(), month.getMonth() + delta, 1), delta)
    }
    function choose(d) {
        selected = d
        if (ym(d) !== ym(month)) goMonth(d, d > month ? 1 : -1)
    }
    function goToday() {
        const t = data.today ? new Date(data.today + "T12:00:00") : new Date()
        const dir = t > month ? 1 : -1
        selected = t
        goMonth(t, dir)
    }
    function requestMonth(m) {
        load(m)
        if (data.connected) sync(ym(m))
    }
    function toggle() { open ? close() : openCalendar() }
    function openCalendar() {
        const mon = Hyprland.focusedMonitor
        targetScreen = Quickshell.screens.find(s => mon && s.name === mon.name) || Quickshell.screens[0]
        showSettings = false
        tab = 0
        wallImg.reload()
        const now = new Date()
        selected = now
        month = new Date(now.getFullYear(), now.getMonth(), 1)
        load(month)
        open = true
        nudgeTimer.restart()
        if (data.connected && Date.now() / 1000 - data.lastSync > 300) sync("")
    }
    function setTab(i) { tab = i; detail = null; showSettings = false; card.forceActiveFocus() }
    function close() { open = false; nudgeTimer.restart(); showSettings = false; detail = null }
    function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    function linkify(t) {
        return esc(t).replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>').replace(/\n/g, "<br>")
    }
    function meetingUrl(ev) {
        if (!ev) return ""
        if (ev.videoUrl) return ev.videoUrl
        const m = /https?:\/\/[^\s<>"]*(zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|whereby\.com)[^\s<>"]*/i.exec((ev.description || "") + " " + (ev.location || ""))
        return m ? m[0] : ""
    }
    function openUrl(u) { Quickshell.execDetached(["xdg-open", u]); close() }
    function copyUrl(u) { Quickshell.execDetached(["wl-copy", u]); copied = true; copyTimer.restart() }

    // ---- backend bridge -------------------------------------------------
    function load(m) {
        snap.command = [py, appDir + "/calendar_json.py", "snapshot", iso(new Date(m.getFullYear(), m.getMonth(), 15))]
        snap.running = true
    }
    function sync(monthArg) {
        if (busy) return
        busy = true
        syncProc.command = monthArg === "" ? [py, appDir + "/backend.py", "sync"] : [py, appDir + "/backend.py", "sync", monthArg]
        syncProc.running = true
    }
    function connectGoogle() {
        close()
        if (data.hasClient) {
            Quickshell.execDetached(["systemctl", "--user", "restart", "--no-block", "hyde-calendar-auth.service"])
        } else {
            Quickshell.execDetached(["sh", "-c",
                'f=$(zenity --file-selection --title="Select Google Desktop OAuth client JSON" --file-filter="*.json") && ' +
                py + " " + appDir + "/backend.py import-client \"$f\" && systemctl --user restart --no-block hyde-calendar-auth.service"])
        }
    }
    function setCalendar(id, on) {
        selectProc.command = [py, appDir + "/calendar_json.py", "select", id, on ? "1" : "0"]
        selectProc.running = true
    }

    Process {
        id: snap
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.data = JSON.parse(text) } catch (e) { console.warn("calendar snapshot parse failed") }
            }
        }
    }
    Process {
        id: syncProc
        onExited: { root.busy = false; root.load(root.month) }
    }
    Process {
        id: selectProc
        onExited: { root.load(root.month); root.sync("") }
    }
    // Keep the clock-driven "today" fresh and pick up reminder/timer syncs while open.
    Timer {
        interval: 60000; running: root.open; repeat: true
        onTriggered: root.load(root.month)
    }
    IpcHandler {
        target: "calendar"
        function toggle(): void { root.toggle() }
        function open(): void { if (!root.open) root.openCalendar() }
        function close(): void { root.close() }
        function tab(n: int): void { if (!root.open) root.openCalendar(); root.setTab(n) }
    }

    Timer { id: copyTimer; interval: 1500; onTriggered: root.copied = false }

    Timer { id: nudgeTimer; interval: 160; onTriggered: Quickshell.execDetached([Quickshell.shellDir + "/nudge.sh"]) }

    Theme { id: pal }

    SequentialAnimation {
        id: monthAnim
        ParallelAnimation {
            NumberAnimation { target: gridHolder; property: "opacity"; to: 0; duration: 90 }
            NumberAnimation { target: gridHolder; property: "x"; to: -root.slideDir * 26; duration: 90; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.month = root.pendingMonth; gridHolder.x = root.slideDir * 26 } }
        ParallelAnimation {
            NumberAnimation { target: gridHolder; property: "opacity"; to: 1; duration: 170 }
            NumberAnimation { target: gridHolder; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
    }

    // Click-outside catcher. It starts below the bar, so Waybar stays hoverable and clickable,
    // and it never reacts to the pointer merely leaving the popup.
    PanelWindow {
        screen: root.targetScreen
        visible: root.open
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: root.barBottom
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hyde-calendar-backdrop"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.close()
        }
    }

    PanelWindow {
        id: win
        screen: root.targetScreen
        visible: root.open || holder.slide < 0.999
        color: "transparent"
        anchors.top: true
        margins.top: root.barBottom - shadowPad
        mask: Region { x: win.shadowPad; y: win.shadowPad; width: win.cardW; height: win.cardH }   // fixed rect: only the card takes input (not tied to the animated scale)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hyde-calendar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        readonly property int shadowPad: 32
        readonly property int cardW: Math.min(Math.round((screen ? screen.width : 1280) * 0.52), 760)
        readonly property int cardH: Math.max(300, Math.round(((screen ? screen.height : 720) - root.barBottom) * 0.60))
        implicitWidth: cardW + shadowPad * 2
        implicitHeight: cardH + shadowPad * 2

        // No focus grab: Waybar stays hoverable. The popup only closes on the clock click or
        // Escape, so focus-follows-mouse activating another window never dismisses it.
        // Everything slides inside a viewport that starts at the bar's bottom edge, so the
        // card appears to come out from behind Waybar and retract back into it.
        Item {
            id: viewport
            x: 0; y: win.shadowPad
            width: parent.width; height: parent.height - y
            clip: true

        Item {
            id: holder
            x: 0; y: -viewport.y + (-(win.cardH + win.shadowPad + 12)) * slide
            width: win.width; height: win.height
            property real slide: root.open ? 0 : 1
            Behavior on slide { NumberAnimation { duration: root.open ? 340 : 260; easing.type: root.open ? Easing.OutCubic : Easing.InCubic } }

            Rectangle {
                id: shadowSrc
                x: win.shadowPad; y: win.shadowPad
                width: win.cardW; height: win.cardH
                radius: 21
                color: "black"
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                source: shadowSrc
                anchors.fill: shadowSrc
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.45
                shadowBlur: 1.0
                shadowVerticalOffset: 8
            }

            // Card body + wallpaper share one outline with concave fillets at the top, so the card melts into Waybar
            Item {
                id: body
                x: win.shadowPad - 24; y: win.shadowPad
                width: win.cardW + 48; height: win.cardH
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: bodyMask }
                Rectangle { anchors.fill: parent; color: pal.alpha(pal.bg, 0.98) }
                Image {
                    id: wallImg
                    anchors.fill: parent
                    source: "file://" + root.home + "/.cache/hyde/wall.blur"
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    opacity: 0.30
                    function reload() { const s = source; source = ""; source = s }
                }
            }
            Canvas {
                id: bodyMask
                x: body.x; y: body.y; width: body.width; height: body.height
                visible: false
                layer.enabled: true
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset()
                    const W = width, H = height, f = 24, r = 21
                    c.fillStyle = "white"
                    c.beginPath()
                    c.moveTo(0, 0)
                    c.arc(0, f, f, -Math.PI / 2, 0, false)
                    c.lineTo(f, H - r)
                    c.arc(f + r, H - r, r, Math.PI, Math.PI / 2, true)
                    c.lineTo(W - f - r, H)
                    c.arc(W - f - r, H - r, r, Math.PI / 2, 0, true)
                    c.lineTo(W - f, f)
                    c.arc(W, f, f, Math.PI, 1.5 * Math.PI, false)
                    c.closePath(); c.fill()
                }
            }

            Rectangle {
                id: card
                x: win.shadowPad; y: win.shadowPad
                width: win.cardW; height: win.cardH
                radius: 21
                color: "transparent"
                border.width: 0
                focus: root.open
                clip: true

                Keys.onPressed: event => {
                    const d = new Date(root.selected)
                    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) { root.setTab(event.key - Qt.Key_1); event.accepted = true; return }
                    if (root.tab !== 1 && event.key !== Qt.Key_Escape) return   // arrows etc. belong to the calendar tab
                    if (event.key === Qt.Key_Escape) { if (root.detail) root.detail = null; else if (root.showSettings) root.showSettings = false; else root.close() }
                    else if (event.key === Qt.Key_Left) { d.setDate(d.getDate() - 1); root.choose(d) }
                    else if (event.key === Qt.Key_Right) { d.setDate(d.getDate() + 1); root.choose(d) }
                    else if (event.key === Qt.Key_Up) { d.setDate(d.getDate() - 7); root.choose(d) }
                    else if (event.key === Qt.Key_Down) { d.setDate(d.getDate() + 7); root.choose(d) }
                    else if (event.key === Qt.Key_PageUp) root.shiftMonth(-1)
                    else if (event.key === Qt.Key_PageDown) root.shiftMonth(1)
                    else if (event.key === Qt.Key_Home || event.key === Qt.Key_T) root.goToday()
                    else return
                    event.accepted = true
                }

                TabPage {
                    id: calendarPage
                    active: root.tab === 1
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.bottom: tabBar.top

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // ---------------- agenda column ----------------
                    Tile {
                        theme: pal; order: 0; shown: calendarPage.active; interactive: false
                        Layout.fillHeight: true
                        Layout.preferredWidth: (card.width - 28) * 0.48

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: root.weekdays[(root.selected.getDay() + 6) % 7]
                                        color: pal.muted; font.family: pal.font; font.pixelSize: 14
                                    }
                                    Text {
                                        textFormat: Text.StyledText
                                        text: "<b>" + root.selected.getDate() + " " + root.months[root.selected.getMonth()] + "</b> " + root.selected.getFullYear()
                                        color: pal.fg; font.family: pal.font; font.pixelSize: 18
                                    }
                                }
                                Pill { theme: pal; round: true; icon: "calendar_month"; size: 11; onClicked: root.showSettings = !root.showSettings }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 4; height: 1; color: pal.alpha(pal.accent, 0.25) }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: "Events · " + root.months[root.selected.getMonth()].slice(0, 3) + " " + root.selected.getDate()
                                    color: pal.fg; font.family: pal.font; font.pixelSize: 12
                                }
                                Rectangle {
                                    implicitWidth: countText.implicitWidth + 16; implicitHeight: 16; radius: 8
                                    color: pal.alpha(pal.accent, 0.09)
                                    Text {
                                        id: countText; anchors.centerIn: parent
                                        text: root.dayEvents.length + (root.dayEvents.length === 1 ? " event" : " events")
                                        color: pal.muted; font.family: pal.font; font.pixelSize: 9
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ListView {
                                    id: list
                                    anchors.fill: parent
                                    clip: true
                                    spacing: 5
                                    model: root.dayEvents
                                    boundsBehavior: Flickable.StopAtBounds
                                    delegate: EventRow {
                                        required property var modelData
                                        theme: pal
                                        ev: modelData
                                        width: list.width
                                        onClicked: root.detail = modelData
                                    }
                                    // staggered entrance when the day changes
                                    populate: Transition {
                                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                                        NumberAnimation { property: "y"; from: 14; duration: 260; easing.type: Easing.OutCubic }
                                    }
                                    add: Transition {
                                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    visible: root.dayEvents.length === 0
                                    Icon {
                                        Layout.alignment: Qt.AlignHCenter
                                        name: !root.data.connected ? "link_off" : root.busy ? "sync" : "event_available"
                                        size: 34; fill: 1; color: pal.alpha(pal.accent, 0.7)
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: !root.data.connected ? "Your calendar, here" : root.busy || root.data.lastSync === 0 ? "Refreshing your agenda…" : "No events for this day"
                                        color: pal.fg; font.family: pal.font; font.pixelSize: 12; font.weight: Font.Medium
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.data.connected ? "Choose another date or return to today." : "Connect Google to see your private agenda."
                                        color: pal.muted; font.family: pal.font; font.pixelSize: 10
                                    }
                                    Pill {
                                        Layout.alignment: Qt.AlignHCenter
                                        visible: !root.data.connected
                                        theme: pal; strong: true; text: "Connect Google"; size: 11
                                        onClicked: root.connectGoogle()
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                elide: Text.ElideRight
                                color: pal.muted; font.family: pal.font; font.pixelSize: 9
                                text: root.busy ? "Refreshing Google Calendar…"
                                    : root.data.error !== "" ? root.data.error
                                    : !root.data.connected ? "Private Google connection · read-only access"
                                    : root.data.lastSync > 0 ? "Updated " + Qt.formatTime(new Date(root.data.lastSync * 1000), "hh:mm") + " · America/Bogota"
                                    : "Waiting for synchronization"
                            }
                        }
                    }

                    // ---------------- month column ----------------
                    Tile {
                        theme: pal; order: 1; shown: calendarPage.active; interactive: false
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 0

                            Item {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 6
                                Layout.preferredHeight: 26
                                // Title is centred on the whole panel, independent of the buttons' widths.
                                Text {
                                    anchors.centerIn: parent
                                    text: root.months[root.pendingMonth.getMonth()] + " " + root.pendingMonth.getFullYear()
                                    color: pal.fg; font.family: pal.font; font.pixelSize: 14; font.weight: Font.DemiBold
                                }
                                MouseArea { anchors.centerIn: parent; width: 150; height: parent.height; cursorShape: Qt.PointingHandCursor; onClicked: root.goToday() }
                                Pill { anchors.left: parent.left; theme: pal; round: true; icon: "chevron_left"; size: 8; width: 26; height: 26; onClicked: root.shiftMonth(-1) }
                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Pill { anchors.verticalCenter: parent.verticalCenter; theme: pal; text: "Today"; onClicked: root.goToday() }
                                    Pill { theme: pal; round: true; icon: "chevron_right"; size: 8; width: 26; height: 26; onClicked: root.shiftMonth(1) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 5
                                spacing: 0
                                Repeater {
                                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                                    Text {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData; color: pal.muted; font.family: pal.font; font.pixelSize: 10
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                Item {
                                    id: gridHolder
                                    width: parent.width
                                    height: parent.height
                                    Grid {
                                        anchors.fill: parent
                                        columns: 7
                                        Repeater {
                                            model: root.cells
                                            DayCell {
                                                required property var modelData
                                                theme: pal
                                                width: gridHolder.width / 7
                                                height: gridHolder.height / 6
                                                day: modelData.getDate()
                                                outside: modelData.getMonth() !== root.month.getMonth()
                                                today: root.isToday(modelData)
                                                selected: root.iso(modelData) === root.iso(root.selected)
                                                colors: root.colorsFor(modelData)
                                                onClicked: root.choose(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------------- event detail (replaces the calendar) ----------------
                Rectangle {
                    id: detailView
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: 18
                    color: pal.mix(pal.bg, pal.card, 0.6)   // opaque, so the calendar underneath never shows through
                    border.width: 1
                    border.color: pal.alpha(pal.accent, 0.12)
                    readonly property var ev: root.detail || lastEv
                    property var lastEv: null
                    readonly property string url: root.meetingUrl(ev)
                    opacity: root.detail ? 1 : 0
                    visible: opacity > 0.01
                    onEvChanged: if (root.detail) lastEv = root.detail
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate { y: root.detail ? 0 : 10; Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }
                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Pill { theme: pal; round: true; icon: "arrow_back"; size: 8; width: 26; height: 26; onClicked: root.detail = null }
                            Rectangle { Layout.preferredWidth: 4; Layout.preferredHeight: 34; radius: 2; color: detailView.ev ? detailView.ev.color : "transparent" }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: detailView.ev ? detailView.ev.title : ""
                                    elide: Text.ElideRight
                                    color: pal.fg; font.family: pal.font; font.pixelSize: 16; font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: pal.muted; font.family: pal.font; font.pixelSize: 11
                                    text: {
                                        const ev = detailView.ev
                                        if (!ev) return ""
                                        const d = new Date(ev.date + "T12:00:00")
                                        const day = root.weekdays[(d.getDay() + 6) % 7] + ", " + d.getDate() + " " + root.months[d.getMonth()]
                                        return day + " · " + (ev.allDay ? "All day" : ev.start + " – " + ev.end)
                                    }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: pal.alpha(pal.accent, 0.25) }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Pill {
                                visible: detailView.url !== ""
                                theme: pal; strong: true; size: 11
                                text: detailView.url.indexOf("meet.google") >= 0 ? "Join Google Meet" : detailView.url.indexOf("zoom") >= 0 ? "Join Zoom" : detailView.url.indexOf("teams") >= 0 ? "Join Teams" : "Join meeting"
                                onClicked: root.openUrl(detailView.url)
                            }
                            Pill {
                                visible: detailView.url !== ""
                                theme: pal; strong: true; size: 11
                                text: root.copied ? "Copied ✓" : "Copy link"
                                onClicked: root.copyUrl(detailView.url)
                            }
                            Pill {
                                visible: detailView.ev && detailView.ev.htmlLink !== ""
                                theme: pal; text: "Open in Google Calendar"
                                onClicked: root.openUrl(detailView.ev.htmlLink)
                            }
                            Item { Layout.fillWidth: true }
                        }

                        // meta lines
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: {
                                    const ev = detailView.ev
                                    if (!ev) return []
                                    const out = [{ i: "calendar_month", t: ev.calendar }]
                                    if (ev.location !== "") out.push({ i: "location_on", t: ev.location })
                                    if (ev.organizer !== "") out.push({ i: "person", t: ev.organizer })
                                    if (ev.attendees > 0) out.push({ i: "group", t: ev.attendees + (ev.attendees === 1 ? " guest" : " guests") })
                                    return out
                                }
                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 9
                                    Icon { Layout.preferredWidth: 18; name: modelData.i; size: 17; fill: 1; color: pal.accent }
                                    Text { Layout.fillWidth: true; text: modelData.t; elide: Text.ElideRight; color: pal.fg; font.family: pal.font; font.pixelSize: 11 }
                                }
                            }
                        }

                        Flickable {
                            id: descFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: detailView.ev && detailView.ev.description !== ""
                            clip: true
                            contentHeight: descText.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            Text {
                                id: descText
                                width: descFlick.width
                                wrapMode: Text.Wrap
                                textFormat: Text.StyledText
                                linkColor: pal.accent
                                color: pal.muted; font.family: pal.font; font.pixelSize: 11
                                text: detailView.ev ? root.linkify(detailView.ev.description) : ""
                                onLinkActivated: link => root.openUrl(link)
                            }
                        }
                        Item { visible: !descFlick.visible; Layout.fillHeight: true }
                    }
                }

                // ---------------- settings sheet ----------------
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: 18
                    color: pal.bg
                    border.width: 1
                    border.color: pal.alpha(pal.accent, 0.35)
                    opacity: root.showSettings ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    MouseArea { anchors.fill: parent }   // swallow clicks

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 9
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: "Google Calendar"; color: pal.fg; font.family: pal.font; font.pixelSize: 13; font.weight: Font.Medium }
                            Pill { theme: pal; round: true; icon: "close"; size: 9; onClicked: root.showSettings = false }
                        }
                        RowLayout {
                            spacing: 8
                            Pill { theme: pal; strong: true; text: root.data.connected ? "Refresh now" : "Connect Google"; size: 11; onClicked: { if (root.data.connected) { root.showSettings = false; root.sync("") } else root.connectGoogle() } }
                            Pill { theme: pal; visible: root.data.connected; text: "Reconnect Google"; onClicked: root.connectGoogle() }
                            Pill { theme: pal; text: "Setup guide"; onClicked: { Quickshell.execDetached(["xdg-open", root.home + "/.local/share/hyde-calendar/GOOGLE_SETUP.html"]); root.close() } }
                        }
                        Text {
                            visible: root.data.calendars.length === 0
                            text: "Calendar selection appears after connection."
                            color: pal.muted; font.family: pal.font; font.pixelSize: 10
                        }
                        ListView {
                            id: calList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: root.data.calendars
                            delegate: Item {
                                required property var modelData
                                width: calList.width
                                height: 26
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 9
                                    Rectangle {
                                        width: 16; height: 16; radius: 5
                                        color: modelData.selected ? modelData.color : "transparent"
                                        border.width: 2; border.color: modelData.color
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                    Text { text: modelData.name; color: pal.fg; font.family: pal.font; font.pixelSize: 11 }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setCalendar(modelData.id, !modelData.selected)
                                }
                            }
                        }
                    }
                }   // settings sheet
                }   // calendarPage

                MediaPage {
                    id: mediaPage
                    theme: pal
                    open: root.open
                    active: root.tab === 2
                    onFocusPlayer: { Quickshell.execDetached([root.home + "/.local/bin/hyde-qs-media", "focus-player"]); root.close() }
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.bottom: tabBar.top
                }
                SystemPage {
                    id: sysPage
                    theme: pal
                    polling: root.open
                    active: root.tab === 3
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.bottom: tabBar.top
                }
                FocusPage {
                    id: focusPage
                    theme: pal
                    active: root.tab === 4
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.bottom: tabBar.top
                }
                DashboardPage {
                    id: dashPage
                    theme: pal
                    hub: root
                    sys: sysPage
                    media: mediaPage
                    pomo: focusPage
                    active: root.tab === 0
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.bottom: tabBar.top
                }

                // ---------------- tab bar ----------------
                Item {
                    id: tabBar
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: 40
                    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; anchors.rightMargin: 14; height: 1; color: pal.alpha(pal.accent, 0.18) }

                    readonly property var tabs: [
                        { icon: "dashboard", label: "Home" },
                        { icon: "calendar_month", label: "Calendar" },
                        { icon: "music_note", label: "Media" },
                        { icon: "monitor_heart", label: "System" },
                        { icon: "timer", label: "Focus" }
                    ]
                    readonly property real cellW: (width - 28 - gap * (tabs.length - 1)) / tabs.length
                    readonly property int gap: 6

                    Item {
                        id: tabRow
                        anchors.centerIn: parent
                        width: tabBar.width - 28
                        height: 28
                        Rectangle {
                            height: parent.height; width: tabBar.cellW; radius: 14
                            x: root.tab * (tabBar.cellW + tabBar.gap)
                            color: pal.alpha(pal.accent, 0.20)
                            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                        }
                        Repeater {
                            model: tabBar.tabs
                            Item {
                                id: tabItem
                                required property int index
                                required property var modelData
                                x: index * (tabBar.cellW + tabBar.gap)
                                width: tabBar.cellW; height: parent.height
                                readonly property bool current: root.tab === index
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: tabItem.modelData.icon
                                        size: 17
                                        fill: tabItem.current ? 1 : 0
                                        color: tabItem.current ? pal.fg : pal.muted
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tabItem.index === 4 && focusPage.badge !== "" ? focusPage.badge : tabItem.modelData.label
                                        color: tabItem.current ? pal.fg : pal.muted
                                        font.family: pal.font; font.pixelSize: 11; font.weight: tabItem.current ? Font.Medium : Font.Normal
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setTab(tabItem.index)
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
}
