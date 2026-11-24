hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
-- Fix Super release opening search after key combinations
for code = 9, 255 do
    if code ~= 133 and code ~= 134 then
        hl.bind(
            "SUPER + code:" .. code,
            hl.dsp.global("quickshell:searchToggleReleaseInterrupt"),
            {
                ignore_mods = true,
                non_consuming = true
            }
        )
    end
end

-- Mouse input interrupts
for _, key in ipairs({
    "mouse:272",
    "mouse:273",
    "mouse:274",
    "mouse:275",
    "mouse:276",
    "mouse:277",
    "mouse_up",
    "mouse_down"
}) do
    hl.bind(
        "SUPER + " .. key,
        hl.dsp.global("quickshell:searchToggleReleaseInterrupt"),
        { non_consuming = true }
    )
end

-- Dynamic island visibility: auto-hide -> dodge windows -> always visible (quickshell island)
hl.bind("SUPER + ALT + J", hl.dsp.global("quickshell:islandModeCycle"), { description = "Shell: Cycle island mode" })
hl.bind("SUPER + ALT + N", hl.dsp.global("quickshell:islandNotifStyleCycle"), { description = "Shell: Cycle notification style" })
