import QtQuick
import Quickshell
import Quickshell.Io

// Reads the HyDE wallbash palette and re-reads it live when the theme changes.
Scope {
    id: t
    property string raw: ""
    function pick(name, fallback) {
        const m = new RegExp("@define-color " + name + " (#[0-9a-fA-F]{6});").exec(raw)
        return m ? m[1] : fallback
    }
    function mix(a, b, k) { return Qt.rgba(a.r * (1 - k) + b.r * k, a.g * (1 - k) + b.g * k, a.b * (1 - k) + b.b * k, 1) }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property color base: pick("wallbash_1xa1", "#2C2952")
    readonly property color fg: pick("wallbash_1xa9", "#CFCCFF")
    readonly property color accent: pick("wallbash_1xa8", "#AFAAF0")
    readonly property color pink: pick("wallbash_3xa8", "#AAAAF0")
    // GTK shade(base, 0.40): scale lightness only
    readonly property color bg: Qt.hsla(base.hslHue, base.hslSaturation, base.hslLightness * 0.4, 1)
    readonly property color muted: mix(bg, fg, 0.68)
    readonly property color card: mix(bg, fg, 0.065)
    readonly property string font: "Noto Sans"
    readonly property string iconFont: "JetBrainsMono Nerd Font Mono"

    FileView {
        path: Quickshell.env("HOME") + "/.cache/hyde/wallbash/gtk.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: t.raw = text()
    }
}
