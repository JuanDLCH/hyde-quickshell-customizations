-- hyde-quickshell-customizations: Hyprland (Lua) additions.
-- Loaded from ~/.config/hypr/hyprland.lua via require("hyde-qs") (the installer adds that line).
-- Keyboard layout is personal: set yours in hyprland.lua, e.g. hl.config({ input = { kb_layout = "us" } }).
local bin = os.getenv("HOME") .. "/.local/bin"

-- Quickshell notification center as HyDE's notification daemon.
hyde.config({
    start = { notifications = "quickshell -c notifications" },
})

-- Dashboard, screenshot picker and power menu run as always-on Quickshell instances.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -c calendar")
    hl.exec_cmd("quickshell -c screenshot")
    hl.exec_cmd("quickshell -c powermenu")
end)

-- Plain F-keys stay free for apps (F2 rename, F5 refresh...).
for _, key in ipairs({ "F10", "F12" }) do hl.unbind(key) end

-- OSD: volume, brightness and Caps Lock through SwayOSD.
for _, b in ipairs({
    { "XF86AudioMute", "mute-toggle", false },
    { "XF86AudioLowerVolume", "-5", true },
    { "XF86AudioRaiseVolume", "+5", true },
}) do
    hl.unbind(b[1])
    hl.bind(b[1], hl.dsp.exec_cmd("swayosd-client --output-volume " .. b[2]),
        { locked = true, repeating = b[3], description = "[Audio] Volume OSD" })
end
for _, b in ipairs({ { "XF86MonBrightnessUp", "+5" }, { "XF86MonBrightnessDown", "-5" } }) do
    hl.unbind(b[1])
    hl.bind(b[1], hl.dsp.exec_cmd("swayosd-client --brightness " .. b[2] .. " --min-brightness 5"),
        { locked = true, repeating = true, description = "[Brightness] OSD" })
end
hl.bind("Caps_Lock", hl.dsp.exec_cmd("swayosd-client --caps-lock"), {
    release = true, non_consuming = true, ignore_mods = true,
    description = "[Keyboard] Caps Lock OSD",
})

-- Notification center (Quickshell): toggle / do not disturb.
hl.bind("SUPER + N", hl.dsp.exec_cmd(bin .. "/notif toggle"), { description = "[Notifications] control center" })
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(bin .. "/notif toggleDnd"), { description = "[Notifications] toggle do not disturb" })

-- Screenshots: Print = full screen, Super+Shift+S = window / zone picker.
hl.unbind("Print")
hl.bind("Print", hl.dsp.exec_cmd(bin .. "/shot full"), { locked = true, description = "[Screenshot] full screen" })
hl.unbind("SUPER + SHIFT + S")
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(bin .. "/shot region"), { locked = true, description = "[Screenshot] pick window or zone" })

-- Lock and suspend (the power menu lives on the waybar power button).
hl.unbind("SUPER + L")
hl.bind("SUPER + L", hl.dsp.exec_cmd("sh -c 'loginctl lock-session; sleep 1.5; systemctl suspend -i'"),
    { description = "[Session] lock and suspend" })

-- Alt+Enter toggles maximized <-> normal; F11 toggles real fullscreen.
local function toggle_state(target)
    local w = assert(hl.get_active_window(), "No active window")
    local state = (tonumber(w.fullscreen) or 0) == target and 0 or target
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = state, client = state, window = w }))
end
hl.unbind("SHIFT + F11")
hl.unbind("F11")
hl.unbind("ALT + RETURN")
hl.bind("ALT + RETURN", function() toggle_state(1) end, { description = "[Window Management] toggle maximize" })
hl.bind("F11", function() toggle_state(2) end, { description = "[Window Management] toggle fullscreen" })
