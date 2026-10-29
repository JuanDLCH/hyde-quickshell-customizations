import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

TabPage {
    id: page
    required property var theme
    property bool polling: false   // true while the popup is open on this tab

    readonly property int keep: 60
    property var cpuHist: []
    property var memHist: []
    property real cpu: 0
    property real memUsed: 0
    property real memTotal: 1
    property real swapUsed: 0
    property real swapTotal: 0
    property real diskUsed: 0
    property real diskTotal: 1
    property real temp: 0
    property int bat: -1
    property string batStatus: ""
    property real uptime: 0
    property real load: 0
    property var prev: null
    property var mem: ({})

    function push(arr, v) { const a = arr.concat([v]); return a.length > keep ? a.slice(a.length - keep) : a }
    function gib(b) { return (b / 1073741824).toFixed(1) }
    function parse(text) {
        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/)
            switch (f[0]) {
            case "cpu": {
                const n = f.slice(1).map(Number)
                const total = n.slice(0, 8).reduce((a, b) => a + b, 0)
                const idle = n[3] + n[4]
                if (prev) {
                    const dt = total - prev.total
                    if (dt > 0) { cpu = 1 - (idle - prev.idle) / dt; cpuHist = push(cpuHist, cpu) }
                }
                prev = { total: total, idle: idle }
                break
            }
            case "mem": mem[f[1]] = Number(f[2]) * 1024; break
            case "disk": diskUsed = Number(f[1]); diskTotal = Number(f[2]); break
            case "temp": temp = Number(f[1]) / 1000; break
            case "bat": bat = Number(f[1]); batStatus = f[2] || ""; break
            case "up": uptime = Number(f[1]); break
            case "load": load = Number(f[1]); break
            }
        }
        if (mem.MemTotal) {
            memTotal = mem.MemTotal
            memUsed = mem.MemTotal - mem.MemAvailable
            swapTotal = mem.SwapTotal || 0
            swapUsed = (mem.SwapTotal || 0) - (mem.SwapFree || 0)
            memHist = push(memHist, memUsed / memTotal)
        }
    }
    function uptimeText() {
        const m = Math.floor(uptime / 60), h = Math.floor(m / 60), d = Math.floor(h / 24)
        return d > 0 ? d + "d " + (h % 24) + "h" : h > 0 ? h + "h " + (m % 60) + "m" : m + "m"
    }

    Process {
        id: sample
        command: ["sh", Quickshell.shellDir + "/sysstat.sh"]
        stdout: StdioCollector { onStreamFinished: page.parse(text) }
    }
    Timer {
        interval: 1500; repeat: true; triggeredOnStart: true
        running: page.polling
        onTriggered: if (!sample.running) sample.running = true
    }

    function loadWord(v) { return v < 0.7 ? "idle" : v < 1.5 ? "calm" : v < 3 ? "busy" : "maxed" }

    // small header used by every tile: round icon + title (+ optional right-hand hint)
    component Head: RowLayout {
        id: hd
        property string icon: ""
        property string title: ""
        property string hint: ""
        property color tint: page.theme.accent
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
            color: page.theme.alpha(hd.tint, 0.18)
            Icon { anchors.centerIn: parent; name: hd.icon; size: 16; fill: 1; color: hd.tint }
        }
        Text { text: hd.title; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 12; font.weight: Font.Medium; Layout.fillWidth: true }
        Text { text: hd.hint; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10 }
    }

    component Bar: Rectangle {
        id: br
        property real fraction: 0
        property color tint: page.theme.accent
        Layout.fillWidth: true; Layout.preferredHeight: 10; radius: 5
        color: page.theme.alpha(page.theme.fg, 0.10)
        Rectangle {
            height: parent.height; radius: 5
            width: parent.width * Math.max(0.02, Math.min(1, br.fraction))
            color: br.tint
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: 10
        columns: 3
        rowSpacing: 8
        columnSpacing: 8
        uniformCellWidths: true

        // ---------- CPU ----------
        Tile {
            theme: page.theme; order: 0; shown: page.active; interactive: false
            Layout.columnSpan: 2; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 5
            tone: page.theme.alpha(page.theme.mix(page.theme.card, page.cpu > 0.85 ? "#f38ba8" : page.theme.accent, 0.10), 0.65)
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 4
                Head {
                    icon: "memory"; title: "CPU"; tint: page.cpu > 0.85 ? "#f38ba8" : page.theme.accent
                    hint: (page.temp > 0 ? Math.round(page.temp) + "°C · " : "") + page.loadWord(page.load)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: Math.round(page.cpu * 100) + "%"; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 34; font.weight: Font.Bold }
                    Item { Layout.fillWidth: true }
                    Text { text: "load " + page.load.toFixed(2); color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10; Layout.alignment: Qt.AlignBottom }
                }
                Sparkline {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 30
                    values: page.cpuHist
                    stroke: page.cpu > 0.85 ? "#f38ba8" : page.theme.accent
                }
            }
        }

        // ---------- Memory ----------
        Tile {
            theme: page.theme; order: 1; shown: page.active; interactive: false
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 5
            tone: page.theme.alpha(page.theme.mix(page.theme.card, page.theme.pink, 0.12), 0.65)
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 4
                Head { icon: "developer_board"; title: "Memory"; tint: page.theme.pink; hint: page.gib(page.memTotal) + " GiB" }
                Text { text: page.gib(page.memUsed) + " GiB"; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 24; font.weight: Font.Bold }
                Text {
                    visible: page.swapTotal > 0
                    text: "swap " + page.gib(page.swapUsed) + " / " + page.gib(page.swapTotal)
                    color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10
                }
                Sparkline {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 30
                    values: page.memHist
                    stroke: page.memUsed / page.memTotal > 0.85 ? "#f38ba8" : page.theme.pink
                }
            }
        }

        // ---------- Disk ----------
        Tile {
            theme: page.theme; order: 2; shown: page.active; interactive: false
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 5
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 4
                Head { icon: "storage"; title: "Disk"; tint: "#89dceb"; hint: page.gib(page.diskUsed) + " / " + page.gib(page.diskTotal) + " GiB" }
                Text { text: Math.round(page.diskUsed / page.diskTotal * 100) + "%"; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 22; font.weight: Font.Bold }
                Item { Layout.fillHeight: true }
                Bar { fraction: page.diskUsed / page.diskTotal; tint: "#89dceb" }
            }
        }

        // ---------- Battery ----------
        Tile {
            theme: page.theme; order: 3; shown: page.active; interactive: false
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 5
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 4
                Head {
                    icon: page.batStatus === "Charging" ? "battery_charging_full" : "battery_full"
                    title: "Battery"; tint: page.bat >= 0 && page.bat < 20 && page.batStatus !== "Charging" ? "#f38ba8" : "#a6e3a1"
                    hint: page.batStatus === "Charging" ? "charging" : page.bat > 90 ? "all good" : page.bat >= 0 && page.bat < 20 ? "plug in" : ""
                }
                Text { text: page.bat >= 0 ? page.bat + "%" : "—"; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 22; font.weight: Font.Bold }
                Item { Layout.fillHeight: true }
                Bar { fraction: page.bat >= 0 ? page.bat / 100 : 0; tint: page.bat >= 0 && page.bat < 20 && page.batStatus !== "Charging" ? "#f38ba8" : "#a6e3a1" }
            }
        }

        // ---------- Uptime ----------
        Tile {
            theme: page.theme; order: 4; shown: page.active; interactive: false
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1; Layout.verticalStretchFactor: 5
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 4
                Head {
                    icon: "schedule"; title: "Uptime"; tint: page.theme.accent
                    hint: page.uptime > 86400 ? "reboot?" : page.uptime < 3600 ? "just booted" : "running"
                }
                Text { text: page.uptimeText(); color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 22; font.weight: Font.Bold }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
