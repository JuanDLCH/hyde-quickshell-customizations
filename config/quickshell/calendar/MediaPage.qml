import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

TabPage {
    id: page
    required property var theme
    property bool open: false
    signal focusPlayer()

    // Weather location comes from ~/.config/hyde-qs/location.json, e.g.
    //   {"city": "Madrid", "lat": 40.4168, "lon": -3.7038}
    // Without that file the weather card stays hidden.
    property string city: ""
    property real lat: NaN
    property real lon: NaN

    // ---------------- music ----------------
    readonly property var player: {
        const list = Mpris.players.values
        for (const p of list) if (p.isPlaying) return p
        return list.length > 0 ? list[0] : null
    }
    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
    }
    Timer {
        interval: 1000; repeat: true
        running: page.open && page.active && page.player !== null && page.player.isPlaying
        onTriggered: page.player.positionChanged()
    }

    // ---------------- weather (Open-Meteo, no key) ----------------
    property var wx: null
    readonly property var codes: ({
        0: ["clear_day", "Clear"], 1: ["partly_cloudy_day", "Mostly clear"], 2: ["partly_cloudy_day", "Partly cloudy"], 3: ["cloud", "Overcast"],
        45: ["foggy", "Fog"], 48: ["foggy", "Fog"], 51: ["rainy_light", "Light drizzle"], 53: ["rainy_light", "Drizzle"], 55: ["rainy", "Heavy drizzle"],
        61: ["rainy_light", "Light rain"], 63: ["rainy", "Rain"], 65: ["rainy_heavy", "Heavy rain"], 66: ["rainy", "Freezing rain"], 67: ["rainy", "Freezing rain"],
        71: ["weather_snowy", "Light snow"], 73: ["weather_snowy", "Snow"], 75: ["snowing_heavy", "Heavy snow"], 77: ["weather_snowy", "Snow grains"],
        80: ["rainy", "Showers"], 81: ["rainy", "Showers"], 82: ["thunderstorm", "Violent showers"], 85: ["weather_snowy", "Snow showers"], 86: ["weather_snowy", "Snow showers"],
        95: ["thunderstorm", "Thunderstorm"], 96: ["thunderstorm", "Thunderstorm"], 99: ["thunderstorm", "Thunderstorm"]
    })
    function code(c) { return codes[c] || ["device_thermostat", "—"] }
    Process {
        id: location
        command: ["sh", "-c", "cat \"${XDG_CONFIG_HOME:-$HOME/.config}/hyde-qs/location.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const l = JSON.parse(text)
                    page.city = l.city || ""; page.lat = Number(l.lat); page.lon = Number(l.lon)
                    if (!isNaN(page.lat) && !isNaN(page.lon)) weather.running = true
                } catch (e) {}
            }
        }
    }
    Process {
        id: weather
        command: ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + page.lat + "&longitude=" + page.lon +
            "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
            "&timezone=auto&forecast_days=5"]
        stdout: StdioCollector {
            onStreamFinished: { try { const d = JSON.parse(text); if (d.current) page.wx = d } catch (e) {} }
        }
    }
    Timer { interval: 1800000; repeat: true; running: true; triggeredOnStart: true; onTriggered: location.running = true }

    component Transport: Rectangle {
        id: tb
        required property string glyph
        property bool primary: false
        property int dim: primary ? 50 : 36
        signal clicked()
        width: dim; height: dim; radius: dim / 2
        color: primary ? (ma.containsMouse ? Qt.lighter(page.theme.accent, 1.12) : page.theme.accent)
                       : ma.containsMouse ? page.theme.alpha(page.theme.accent, 0.28) : page.theme.alpha(page.theme.fg, 0.10)
        opacity: enabled ? 1 : 0.35
        scale: ma.pressed ? 0.9 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Icon {
            anchors.centerIn: parent
            name: tb.glyph
            size: tb.primary ? 28 : 22
            fill: 1
            color: tb.primary ? page.theme.bg : page.theme.fg
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tb.clicked() }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // ---------------- now playing ----------------
        Panel {
            id: music
            theme: page.theme
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 58

            // blurred cover as ambient background (blur first, rounded mask on the wrapper)
            Rectangle { id: bgMask; anchors.fill: parent; radius: 18; visible: false; layer.enabled: true }
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: bgMask }
                Image {
                    anchors.fill: parent
                    source: page.player ? page.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.38
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.3 }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                visible: page.player !== null
                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Item {
                        Layout.preferredWidth: 128; Layout.preferredHeight: 128
                        Rectangle {
                            id: artMask
                            anchors.fill: parent; radius: 16
                            visible: false; layer.enabled: true
                        }
                        Rectangle { anchors.fill: parent; radius: 16; color: page.theme.alpha(page.theme.accent, 0.18) }
                        Icon { anchors.centerIn: parent; name: "music_note"; size: 40; fill: 1; color: page.theme.alpha(page.theme.fg, 0.4) }
                        Image {
                            anchors.fill: parent
                            source: page.player ? page.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true; maskSource: artMask
                                shadowEnabled: false
                            }
                        }
                        Rectangle { anchors.fill: parent; radius: 16; color: "transparent"; border.width: 1; border.color: page.theme.alpha(page.theme.fg, 0.14) }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: page.focusPlayer()
                            Rectangle {
                                anchors.fill: parent; radius: 16; color: Qt.rgba(0, 0, 0, 0.45)
                                opacity: parent.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                Icon { anchors.centerIn: parent; name: "open_in_new"; size: 30; fill: 1; color: "white" }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3
                        Rectangle {
                            implicitWidth: src.implicitWidth + 14; implicitHeight: 18; radius: 9
                            color: chipMa.containsMouse ? page.theme.alpha(page.theme.accent, 0.34) : page.theme.alpha(page.theme.accent, 0.20)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.focusPlayer() }
                            Text {
                                id: src; anchors.centerIn: parent
                                text: (page.player && page.player.isPlaying ? "▶  " : "❚❚  ") + (page.player ? page.player.identity : "")
                                color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 9
                            }
                        }
                        Text {
                            Layout.fillWidth: true; Layout.topMargin: 4
                            text: page.player ? page.player.trackTitle : ""
                            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                            color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 18; font.weight: Font.Bold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.player ? page.player.trackArtist : ""
                            elide: Text.ElideRight
                            color: page.theme.accent; font.family: page.theme.font; font.pixelSize: 13; font.weight: Font.Medium
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.player ? page.player.trackAlbum : ""
                            elide: Text.ElideRight
                            color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 11
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 4
                    visible: page.player && page.player.lengthSupported && page.player.length > 0
                    WavyBar {
                        Layout.fillWidth: true
                        theme: page.theme
                        progress: page.player && page.player.length > 0 ? Math.min(1, page.player.position / page.player.length) : 0
                        playing: page.player !== null && page.player.isPlaying
                        seekable: page.player !== null && page.player.canSeek
                        onSeekTo: f => page.player.position = f * page.player.length
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: page.player ? page.fmt(page.player.position) : ""; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                        Text { text: page.player ? page.fmt(page.player.length) : ""; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10 }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    spacing: 18
                    Transport { glyph: "skip_previous"; enabled: page.player && page.player.canGoPrevious; onClicked: page.player.previous() }
                    Transport { primary: true; glyph: page.player && page.player.isPlaying ? "pause" : "play_arrow"; onClicked: page.player.togglePlaying() }
                    Transport { glyph: "skip_next"; enabled: page.player && page.player.canGoNext; onClicked: page.player.next() }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: page.player === null
                Icon { Layout.alignment: Qt.AlignHCenter; name: "music_off"; size: 40; fill: 1; color: page.theme.alpha(page.theme.accent, 0.65) }
                Text { Layout.alignment: Qt.AlignHCenter; text: "Nothing playing"; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Text { Layout.alignment: Qt.AlignHCenter; text: "Start music in any player."; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10 }
            }
        }

        // ---------------- weather ----------------
        Panel {
            theme: page.theme
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 42

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                visible: page.wx !== null

                RowLayout {
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true; spacing: 3
                        Icon { name: "location_on"; size: 15; fill: 1; color: page.theme.accent }
                        Text { text: page.city; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 11; Layout.fillWidth: true }
                    }
                    Text { text: page.wx ? page.code(page.wx.current.weather_code)[1] : ""; color: page.theme.accent; font.family: page.theme.font; font.pixelSize: 11; font.weight: Font.Medium }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    Item { Layout.fillWidth: true }
                    Icon { name: page.wx ? page.code(page.wx.current.weather_code)[0] : ""; size: 48; fill: 1; color: page.theme.accent }
                    Text {
                        text: page.wx ? Math.round(page.wx.current.temperature_2m) + "°" : ""
                        color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 44; font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: page.wx ? [
                            { k: "Feels", v: Math.round(page.wx.current.apparent_temperature) + "°" },
                            { k: "Humidity", v: page.wx.current.relative_humidity_2m + "%" },
                            { k: "Wind", v: Math.round(page.wx.current.wind_speed_10m) + " km/h" }
                        ] : []
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 11
                            color: page.theme.alpha(page.theme.fg, 0.06)
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.v; color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.k; color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 9 }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: page.wx ? page.wx.daily.time : []
                        Rectangle {
                            id: dayCell
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 86; radius: 12
                            color: index === 0 ? page.theme.alpha(page.theme.accent, 0.16) : page.theme.alpha(page.theme.fg, 0.05)
                            Column {
                                anchors.centerIn: parent; spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dayCell.index === 0 ? "Today" : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][new Date(dayCell.modelData + "T12:00:00").getDay()]
                                    color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 9
                                }
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: page.code(page.wx.daily.weather_code[dayCell.index])[0]; size: 22; fill: 1; color: dayCell.index === 0 ? page.theme.accent : page.theme.fg }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(page.wx.daily.temperature_2m_max[dayCell.index]) + "°"
                                    color: page.theme.fg; font.family: page.theme.font; font.pixelSize: 11; font.weight: Font.Medium
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(page.wx.daily.temperature_2m_min[dayCell.index]) + "°"
                                    color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: page.wx === null
                text: "Loading weather…"
                color: page.theme.muted; font.family: page.theme.font; font.pixelSize: 11
            }
        }
    }
}
