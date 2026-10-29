import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

TabPage {
    id: page
    required property var theme

    // ---- pomodoro (state lives here, so it keeps running while the popup is closed) ----
    property int focusMin: 25
    property int breakMin: 5
    property bool onBreak: false
    property bool running: false
    property int remaining: focusMin * 60
    property real endAt: 0
    property int done: 0
    readonly property int total: (onBreak ? breakMin : focusMin) * 60
    readonly property string clock: pad(Math.floor(remaining / 60)) + ":" + pad(remaining % 60)
    readonly property string badge: running ? clock : ""
    function pad(n) { return n < 10 ? "0" + n : "" + n }

    function start() { endAt = Date.now() + remaining * 1000; running = true }
    function pause() { running = false }
    function reset() { running = false; remaining = total }
    function setPreset(f, b) { focusMin = f; breakMin = b; onBreak = false; running = false; remaining = f * 60 }
    function finish() {
        running = false
        if (!onBreak) {
            done++
            Quickshell.execDetached(["notify-send", "-a", "Focus", "-i", "alarm-symbolic", "Focus session complete", "Time for a " + breakMin + " minute break."])
        } else {
            Quickshell.execDetached(["notify-send", "-a", "Focus", "-i", "alarm-symbolic", "Break over", "Ready for another focus session?"])
        }
        onBreak = !onBreak
        remaining = total
    }
    Timer {
        interval: 250; repeat: true; running: page.running
        onTriggered: {
            const left = Math.ceil((page.endAt - Date.now()) / 1000)
            if (left <= 0) page.finish(); else page.remaining = left
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Tile {
            theme: page.theme; order: 0; shown: page.active; interactive: false
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            tone: page.theme.alpha(page.theme.mix(page.theme.card, page.onBreak ? "#a6e3a1" : page.theme.accent, 0.10), 0.65)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                Item { Layout.fillHeight: true }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: page.onBreak ? "Break" : "Focus"
                    color: page.onBreak ? "#a6e3a1" : page.theme.accent
                    font.family: page.theme.font; font.pixelSize: 13; font.weight: Font.Medium
                }
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 150; Layout.preferredHeight: 150
                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real frac: page.total > 0 ? page.remaining / page.total : 0
                        property color tint: page.onBreak ? "#a6e3a1" : page.theme.accent
                        Behavior on frac { NumberAnimation { duration: 300 } }
                        onFracChanged: requestPaint()
                        onTintChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d"); ctx.reset()
                            const c = width / 2, r = c - 8
                            ctx.lineWidth = 8; ctx.lineCap = "round"
                            ctx.strokeStyle = Qt.rgba(page.theme.fg.r, page.theme.fg.g, page.theme.fg.b, 0.10)
                            ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke()
                            if (frac > 0.002) {
                                ctx.strokeStyle = tint
                                ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac); ctx.stroke()
                            }
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: page.clock
                            color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 32; font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (page.running ? (page.onBreak ? "resting" : "focusing") : "ready") + " · " + page.done + (page.done === 1 ? " session" : " sessions")
                            color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10
                        }
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Pill { theme: page.theme; strong: true; size: 11; text: page.running ? "Pause" : "Start"; onClicked: page.running ? page.pause() : page.start() }
                    Pill { theme: page.theme; strong: true; size: 11; text: "Reset"; onClicked: page.reset() }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Pill { theme: page.theme; text: "25 / 5"; onClicked: page.setPreset(25, 5) }
                    Pill { theme: page.theme; text: "50 / 10"; onClicked: page.setPreset(50, 10) }
                    Pill { theme: page.theme; text: "15 / 3"; onClicked: page.setPreset(15, 3) }
                }
                Item { Layout.fillHeight: true }
            }
        }

        Tile {
            theme: page.theme; order: 1; shown: page.active; interactive: false
            Layout.fillHeight: true
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Quick notes"; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                    Text { id: savedLabel; text: ""; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 9 }
                    Pill {
                        theme: page.theme; text: "Clear"
                        opacity: notes.text.length > 0 ? 1 : 0.35
                        enabled: notes.text.length > 0
                        onClicked: { notes.text = ""; notes.forceActiveFocus() }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: page.theme.alpha(page.theme.accent, 0.25) }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    TextArea {
                        id: notes
                        wrapMode: TextEdit.Wrap
                        color: page.theme.fg
                        selectionColor: page.theme.alpha(page.theme.accent, 0.5)
                        selectedTextColor: page.theme.fg
                        font.family: page.theme.font; font.pixelSize: 12
                        placeholderText: "Type anything — it is saved automatically."
                        placeholderTextColor: page.theme.alpha(page.theme.muted, 0.7)
                        background: null
                        padding: 4
                        property bool ready: false
                        onTextChanged: if (ready) saveTimer.restart()
                    }
                }
            }
        }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/share/hyde-calendar/notes.txt"
        onLoaded: { notes.text = text(); notes.ready = true }
        onLoadFailed: notes.ready = true   // first run: file does not exist yet
    }
    Timer {
        id: saveTimer
        interval: 700
        onTriggered: { file.setText(notes.text); savedLabel.text = "Saved"; savedFade.restart() }
    }
    Timer { id: savedFade; interval: 1500; onTriggered: savedLabel.text = "" }
}
