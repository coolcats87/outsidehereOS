-- Frosted-glass windows, matching the dynamic island: windows blur what is actually behind them
-- (other windows, floating ones, the island) instead of only the wallpaper (xray), and are a bit more
-- see-through than end4's defaults (0.9 / 0.8). Layers keep xray via the layer rule in hyprland/rules.lua.
-- Undo: delete this block (or this file's contents) and run `hyprctl reload`.
hl.config({
    decoration = {
        active_opacity = 0.78,
        inactive_opacity = 0.78,
        blur = {
            xray = false,
            noise = 0, -- end4 adds 0.05 film grain; Liquid Glass is smooth and glossy
        },
    },
})
