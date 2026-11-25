-- Machine-local settings: things tied to THIS computer (monitors, keyboard, touchpad, GPU, services).
-- install.sh copies this folder to ~/.rices/local/hypr/ once; edit the copy there, not this template.
-- hyprland.lua loads it LAST, so anything set here overrides the rice.

local dir = os.getenv("HOME") .. "/.rices/local/hypr/"

dofile(dir .. "env.lua")
dofile(dir .. "monitors.lua")
dofile(dir .. "input.lua")
dofile(dir .. "execs.lua")
