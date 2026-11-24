-- Dynamic island (quickshell): frosted glass. Blur whatever is behind the island, its quick settings,
-- the launcher and the keystroke dropdown (xray off = real windows, not just the wallpaper).
-- ignore_alpha 0.3: only the translucent panels get blurred, never the empty parts of the surface.
hl.layer_rule({ match = { namespace = "quickshell:island.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:island.*" }, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "quickshell:island.*" }, xray = false })

-- Frosted-glass windows: end4's hyprland/rules.lua disables blur for every window (no_blur on class .*).
-- Re-enable it here (custom rules load later), keeping end4's exception for xwayland context menus.
hl.window_rule({ match = { class = ".*" }, no_blur = false })
hl.window_rule({ match = { class = "^()$", title = "^()$" }, no_blur = true })
