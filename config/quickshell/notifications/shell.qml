import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Notification daemon + popups + side control center. Replaces swaync.
ShellRoot {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/state/hyde-notifications"
    readonly property int barBottom: 42

    property bool centerOpen: false
    property bool dnd: false
    property string subRequest: ""
    property var popups: []         // Notification objects currently shown as popups
    property var groups: []         // [{app, items:[Notification…]}] for the center
    property int count: 0
    property var collapsed: ({})
    property var targetScreen: Quickshell.screens[0]

    // ---------------- server ----------------
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: false
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            // Claude's own terminal notification (any terminal) is generic; the Notification hook sends a richer one.
            if ((n.appName || "") !== "claude-code" && /^Claude( Code)?$/.test(n.summary || "")) { n.dismiss(); return }
            n.tracked = true
            root.pickScreen()
            let img = n.image || ""
            // Senders like Satty point at a temp file they delete right after notifying: grab a copy now
            const tmp = img.replace(/^file:\/\//, "").replace(/^image:\/\/icon\//, "")
            if (tmp.indexOf("/tmp/") === 0) {
                const dest = root.home + "/.cache/qs-notif-img/" + (root.seq + 1) + ".png"
                Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp -- "$1" "$2"', "sh", tmp, dest])
                img = "file://" + dest
            }
            const rec = {
                uid: ++root.seq, appName: n.appName || "Unknown", summary: n.summary || "", body: n.body || "",
                image: img.indexOf("image://qsimage") === 0 ? "" : img,
                urgency: n.urgency, expireTimeout: n.expireTimeout, time: Date.now(),
                actions: n.actions.map(a => ({ identifier: a.identifier, text: a.text, invoke: () => a.invoke() })),
                live: n
            }
            n.closed.connect(() => { rec.live = null; rec.actions = [] })
            root.history = [rec].concat(root.history).slice(0, 100)
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) root.popups = [rec].concat(root.popups)
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) {
                const text = ((n.appName || "") + " " + (n.summary || "") + " " + (n.body || "")).toLowerCase()
                if ((n.appName || "") === "claude-code") {
                    // sounds for Claude Code come from its hooks (~/.claude/hooks), which know why it notified
                    claudeLog.logText = claudeLog.logText + new Date().toISOString() + " | " + n.appName + " | " + n.summary + " | " + n.body + " | urgency=" + n.urgency + "\n"; claudeLog.setText(claudeLog.logText)
                } else root.playSound(n.urgency === NotificationUrgency.Critical ? "dialog-warning" : "message-new-instant")
            }
            root.rebuild()
        }
    }
    property int seq: 0
    FileView {
        id: claudeLog
        path: root.stateDir + "/claude-log.txt"
        property string logText: ""
        onLoaded: logText = text()
        onLoadFailed: logText = ""
    }
    property real lastSound: 0
    function playCustom(kind) {
        const now = Date.now()
        if (now - lastSound < 400) return
        lastSound = now
        const dir = home + "/Music/claude-sounds"
        Quickshell.execDetached(["sh", "-c", 'f=$(ls "$1"/"$2".* 2>/dev/null | head -1); [ -n "$f" ] && exec pw-play "$f"; exec pw-play /usr/share/sounds/freedesktop/stereo/message-new-instant.oga', "sh", dir, kind])
    }
    function playSound(name) {
        const now = Date.now()
        if (now - lastSound < 400) return          // a burst of notifications plays one sound
        lastSound = now
        Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/" + name + ".oga"])
    }
    property var history: []

    function rebuild() {
        const byApp = {}, order = []
        for (const r of history) {
            if (!byApp[r.appName]) { byApp[r.appName] = { app: r.appName, items: [] }; order.push(r.appName) }
            byApp[r.appName].items.push(r)
        }
        groups = order.map(k => byApp[k])
        count = history.length
        writeState()
        saveTimer.restart()
    }
    function pickScreen() {
        const mon = Hyprland.focusedMonitor
        targetScreen = Quickshell.screens.find(s => mon && s.name === mon.name) || Quickshell.screens[0]
    }
    // Records reach delegates as copies (JS objects lose identity through models), so match by uid.
    function hidePopup(r) { popups = popups.filter(x => x.uid !== r.uid) }
    function dismiss(r) {
        const orig = history.find(x => x.uid === r.uid)
        hidePopup(r)
        history = history.filter(x => x.uid !== r.uid)
        if (orig && orig.live) { try { orig.live.dismiss() } catch (e) {} }
        rebuild()
    }
    function clearAll() {
        for (const r of history) if (r.live) { try { r.live.dismiss() } catch (e) {} }
        history = []; popups = []; rebuild()
    }
    function clearGroup(app) {
        for (const r of history) if (r.appName === app && r.live) { try { r.live.dismiss() } catch (e) {} }
        history = history.filter(r => r.appName !== app)
        popups = popups.filter(r => r.appName !== app)
        rebuild()
    }

    // ---------------- persistence ----------------
    FileView {
        id: histFile
        path: root.stateDir + "/history.json"
        onLoaded: {
            try {
                const arr = JSON.parse(text())
                root.history = arr.map(r => Object.assign(r, { actions: [], live: null, uid: ++root.seq }))
                root.rebuild()
            } catch (e) {}
        }
    }
    Timer {
        id: saveTimer; interval: 800
        onTriggered: histFile.setText(JSON.stringify(root.history.map(r => ({
            appName: r.appName, summary: r.summary, body: r.body, image: r.image,
            urgency: r.urgency, expireTimeout: r.expireTimeout, time: r.time }))))
    }
    function toggleCollapsed(app) { const c = Object.assign({}, collapsed); c[app] = !c[app]; collapsed = c }

    // ---------------- DND + state for waybar ----------------
    FileView {
        id: dndFile
        path: root.stateDir + "/dnd"
        onLoaded: root.dnd = text().trim() === "1"
        onLoadFailed: root.dnd = false
    }
    FileView { id: stateFile; path: root.stateDir + "/state.json" }
    function setDnd(v) { dnd = v; dndFile.setText(v ? "1" : "0"); if (v) popups = []; writeState() }
    function writeState() {
        const alt = (dnd ? "dnd-" : "") + (count > 0 ? "notification" : "none")
        stateFile.setText(JSON.stringify({ text: " ", alt: alt, class: alt, tooltip: count + (count === 1 ? " notification" : " notifications") + (dnd ? " · do not disturb" : "") }) + "\n")
    }
    Component.onCompleted: writeState()

    // ---------------- ipc ----------------
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.centerOpen = !root.centerOpen; if (root.centerOpen) root.pickScreen() }
        function open(): void { root.pickScreen(); root.centerOpen = true }
        function close(): void { root.centerOpen = false }
        function toggleDnd(): void { root.setDnd(!root.dnd) }
        function clear(): void { root.clearAll() }
        function sub(kind: string): void { root.subRequest = kind }
    }

    Theme { id: pal }

    Popups { hub: root; pal: pal }
    Center { hub: root; pal: pal }
}
