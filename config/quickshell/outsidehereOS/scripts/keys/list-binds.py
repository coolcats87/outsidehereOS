#!/usr/bin/env python3
"""
List the live Hyprland keybinds for the island cheatsheet (Super+/), as JSON.

Source of truth is `hyprctl binds -j` (what is actually bound right now). Hyprland's Lua
config only reports the action as an opaque handle, so binds without a description get a
label from the config source instead (hypr/**/*.lua, the hl.bind(...) call with the same
key combo). Left out: binds marked "# [hidden]", internal binds (non-consuming / catch-all,
like the Super-release interrupts), and keycode duplicates of binds already listed.
Workspace-number binds ("Focus 1" ... "Focus 10") are folded into one row.

Output: [{"cat": "Window", "label": "Close", "combos": [{"mods": ["SUPER"], "key": "Q"}]}, ...]
"""
import json
import os
import re
import subprocess
import sys

HYPR = os.path.expanduser("~/.config/hypr")
MOD_BITS = [(64, "SUPER"), (4, "CTRL"), (8, "ALT"), (1, "SHIFT")]
MOD_ALIASES = {"SUPER": "SUPER", "MOD4": "SUPER", "WIN": "SUPER", "CTRL": "CTRL", "CONTROL": "CTRL",
               "ALT": "ALT", "MOD1": "ALT", "SHIFT": "SHIFT"}
# Media/hardware keys, labelled by the key itself when the bind has no description
XF86 = {"xf86audioraisevolume": "Volume up", "xf86audiolowervolume": "Volume down", "xf86audiomute": "Toggle mute",
        "xf86audiomicmute": "Toggle mic", "xf86monbrightnessup": "Brightness up",
        "xf86monbrightnessdown": "Brightness down", "xf86audioplay": "Play/pause media", "xf86audiopause": "Play/pause media",
        "xf86audionext": "Next track", "xf86audioprev": "Previous track"}
CAT_ORDER = ["Shell", "App", "Window", "Workspace", "Utilities", "Screen", "Media", "Session"]


def norm_key(k):
    return k.strip().lower()


def parse_combo(combo):
    mods, key = set(), ""
    for part in [p.strip() for p in combo.split("+") if p.strip()]:
        up = part.upper()
        if up in MOD_ALIASES:
            mods.add(MOD_ALIASES[up])
        else:
            key = part
    return frozenset(mods), norm_key(key)


def split_args(s):
    """Split a Lua argument list at top-level commas."""
    out, depth, cur, q = [], 0, "", None
    for ch in s:
        if q:
            cur += ch
            if ch == q:
                q = None
            continue
        if ch in "\"'":
            q = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
            continue
        cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def humanize(name):
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name).replace("_", " ").strip()
    return name[:1].upper() + name[1:]


# Friendlier names for quickshell shortcuts that have no description
SHELL_NAMES = {"overviewClipboardToggle": "Clipboard history", "overviewEmojiToggle": "Emoji picker",
               "overviewWorkspacesToggle": "Toggle overview", "sidebarLeftToggleDetach": "Detach left sidebar",
               "sidebarLeftToggle": "Toggle left sidebar", "sidebarRightToggle": "Toggle right sidebar",
               "regionRecord": "Record region", "regionScreenshot": "Screen snip", "regionSearch": "Google Lens",
               "regionOcr": "Copy text from region", "islandLauncherToggleRelease": "Toggle launcher",
               "islandModeCycle": "Cycle island mode", "islandKeystrokesToggle": "Toggle keystroke overlay"}
MEDIA_CMDS = ("playerctl", "wpctl", "pactl", "pamixer", "media")


def shell_name(name):
    if name in SHELL_NAMES:
        return SHELL_NAMES[name]
    m = re.fullmatch(r"(.*?)(Toggle|Open|Close)(.*)", name)  # "fooBarToggle" -> "Toggle foo bar"
    if m and m.group(1):
        return f"{m.group(2)} {humanize(m.group(1)).lower()}{(' ' + humanize(m.group(3)).lower()) if m.group(3) else ''}"
    return humanize(name)


def action_label(action):
    m = re.search(r'global\(\s*"quickshell:([^"]+)"', action)
    if m:
        return shell_name(m.group(1)), "Shell"
    m = re.search(r'exec_cmd\(\s*"([^"]*)"', action)
    if m:
        cmd = m.group(1)
        cmd = re.sub(r"^.*\|\|\s*", "", cmd) if "qsIsAlive" in action else cmd
        if cmd.startswith("playerctl "):
            verb = cmd.split()[-1]
            return {"previous": "Previous track", "next": "Next track", "play-pause": "Play / pause"}.get(verb, "Run " + cmd), "Media"
        cat = "Media" if any(w in cmd for w in MEDIA_CMDS) else "App"
        return "Run " + (cmd if len(cmd) <= 40 else cmd[:38] + "…"), cat
    m = re.search(r"exec_cmd\(\s*([A-Za-z_]\w*)\s*\)", action)
    if m:
        var = m.group(1)
        if var.lower().startswith("media"):  # mediaNextCommand -> "Next track"
            return {"next": "Next track", "prev": "Previous track", "previous": "Previous track"}.get(
                re.sub(r"(?i)^media|command$", "", var).lower(), humanize(var)), "Media"
        return humanize(var), "App"
    m = re.search(r"hl\.dsp\.([\w.]+)\((.*)\)", action, re.S)
    if m:
        what = m.group(1).split(".")
        args = re.sub(r"\s+", " ", m.group(2)).strip()
        cat = "Window" if what[0] == "window" else "Workspace" if what[0] in ("workspace", "focus") else "Window"
        label = humanize(" ".join(what))
        short = re.sub(r'[{}"]', "", args)
        if short and len(short) <= 30:
            label += f" ({short})"
        return label, cat
    return None, None


def source_binds():
    """(mods, key) -> {label, cat, hidden} for hl.bind calls with a literal combo."""
    found = {}
    for root, _, files in os.walk(HYPR):
        for f in files:
            if not f.endswith(".lua"):
                continue
            try:
                text = open(os.path.join(root, f), encoding="utf-8").read()
            except OSError:
                continue
            for m in re.finditer(r"(?m)^[ \t]*hl\.bind\(", text):
                i, depth, q = m.end(), 1, None
                while i < len(text) and depth > 0:
                    ch = text[i]
                    if q:
                        if ch == q:
                            q = None
                    elif ch in "\"'":
                        q = ch
                    elif ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                    i += 1
                args = split_args(text[m.end():i - 1])
                if len(args) < 2 or not re.fullmatch(r'"[^"]*"', args[0]):
                    continue  # combo built in a loop: these come with descriptions, or aren't shown
                line_end = text.find("\n", i)
                tail = text[i:line_end if line_end != -1 else len(text)]
                hidden = "[hidden]" in tail or "[hidden]" in text[m.start():i]
                opts = args[2] if len(args) > 2 else ""
                internal = "non_consuming" in opts or "transparent" in opts
                label, cat = action_label(args[1])
                key = parse_combo(args[0][1:-1])
                if key not in found:
                    found[key] = {"label": label, "cat": cat, "hidden": hidden or internal}
    return found


def mouse_name(key):
    names = {"mouse:272": "Left drag", "mouse:273": "Right drag", "mouse:274": "Middle click",
             "mouse:275": "Back button", "mouse:276": "Forward button", "mouse_up": "Scroll up",
             "mouse_down": "Scroll down"}
    return names.get(key.lower(), key)


def main():
    try:
        live = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, timeout=5).stdout)
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"error": str(e)}))
        return
    src = source_binds()
    rows, seen = [], set()
    for b in live:
        if b.get("non_consuming") or b.get("catch_all") or b.get("submap"):
            continue
        key = b.get("key") or ""
        if not key:
            continue  # keycode-only binds: duplicates of the named-key ones
        mods = frozenset(n for bit, n in MOD_BITS if b.get("modmask", 0) & bit)
        if key.upper() in ("SUPER_L", "SUPER_R"):  # a Super tap: one row for both Super keys
            mods, key = frozenset(), "SUPER"
        ident = (mods, norm_key(key))
        if ident in seen:
            continue
        desc = (b.get("description") or "").strip()
        s = src.get(ident)
        if desc:
            if "[hidden]" in desc or (s and s["hidden"] and not desc):
                continue
            cat, _, label = desc.partition(": ")
            if not label:
                cat, label = "General", desc
        elif norm_key(key) in XF86:
            cat, label = "Media", XF86[norm_key(key)]
            if "ALT" in mods and norm_key(key) == "xf86audiomute":
                label = "Toggle mic"
        else:
            if not s or s["hidden"] or not s["label"] or s["label"] in ("Exec cmd", "Exec"):
                continue  # can't tell what it does: better left out than shown as noise
            cat, label = s["cat"], s["label"]
        if b.get("mouse") or key.lower().startswith("mouse"):
            key = mouse_name(key)
        seen.add(ident)
        rows.append({"cat": cat.strip(), "label": label.strip(), "mods": [n for _, n in MOD_BITS if n in mods], "key": key})

    # Fold numbered rows: same category/mods, label "... N", key = a digit
    folded, groups = [], {}
    for r in rows:
        m = re.fullmatch(r"(.*?)\s*(\d+)", r["label"])
        if m and re.fullmatch(r"\d", r["key"]):
            gk = (r["cat"], tuple(r["mods"]), m.group(1))
            if gk in groups:
                groups[gk]["nums"].append(int(m.group(2)))
                continue
            entry = dict(r, nums=[int(m.group(2))], base=m.group(1))
            groups[gk] = entry
            folded.append(entry)
        else:
            folded.append(r)
    for r in folded:
        if "nums" in r:
            nums = sorted(r.pop("nums"))
            base = r.pop("base")
            if len(nums) > 1:
                r["label"] = f"{base} {nums[0]}–{nums[-1]}"
                r["key"] = "1 … 0" if nums[-1] == 10 else f"{nums[0] % 10} … {nums[-1] % 10}"

    # One row per action: several shortcuts for the same thing are listed together
    merged, byLabel = [], {}
    for r in folded:
        k = (r["cat"], r["label"].lower())
        combo = {"mods": r["mods"], "key": r["key"]}
        if k in byLabel:
            byLabel[k]["combos"].append(combo)
        else:
            byLabel[k] = {"cat": r["cat"], "label": r["label"], "combos": [combo]}
            merged.append(byLabel[k])

    order = {c: i for i, c in enumerate(CAT_ORDER)}
    merged.sort(key=lambda r: order.get(r["cat"], len(order)))  # stable: keeps config order inside a category
    json.dump(merged, sys.stdout)


if __name__ == "__main__":
    main()
