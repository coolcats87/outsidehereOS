#!/usr/bin/env python3
"""Keystroke reader for the dynamic island's key overlay.

Reads key press/release events from every keyboard in /dev/input (needs the
`input` group) and prints one line per event to stdout:  "D KEY_A" / "U KEY_A".
Nothing is stored or logged; Quickshell only shows the latest stroke on screen
and stops this process while the screen is locked. Standard library only.
"""
import os
import re
import select
import struct
import sys
import time

EV_KEY = 1
EVENT = struct.Struct("llHHi")  # struct input_event (64-bit timeval)
HEADER = "/usr/include/linux/input-event-codes.h"


def key_names():
    names = {}
    try:
        with open(HEADER) as f:
            for m in re.finditer(r"#define\s+(KEY_\w+)\s+(0x[0-9a-fA-F]+|\d+)", f.read()):
                code = int(m.group(2), 0)
                names.setdefault(code, m.group(1))  # first (canonical) name wins
    except OSError:
        pass
    return names


def keyboards():
    """Event nodes of devices that look like keyboards (kbd handler + EV_KEY|EV_REP)."""
    devs = []
    try:
        blocks = open("/proc/bus/input/devices").read().split("\n\n")
    except OSError:
        return devs
    for b in blocks:
        h = re.search(r"H: Handlers=(.*)", b)
        ev = re.search(r"B: EV=([0-9a-f]+)", b)
        if not h or not ev or "kbd" not in h.group(1):
            continue
        bits = int(ev.group(1), 16)
        if not (bits & (1 << EV_KEY)):
            continue
        # EV_REP: real keyboards repeat; virtual devices (e.g. ydotool) only if asked to
        if not (bits & (1 << 20)) and os.environ.get("KEYSTROKE_INCLUDE_VIRTUAL") != "1":
            continue
        m = re.search(r"event\d+", h.group(1))
        if m:
            devs.append("/dev/input/" + m.group(0))
    return devs


def main():
    names = key_names()
    fds = {}  # path -> fd
    last_scan = 0.0
    while True:
        now = time.monotonic()
        if now - last_scan > 2:  # hotplug (e.g. Bluetooth keyboards)
            last_scan = now
            for path in keyboards():
                if path not in fds:
                    try:
                        fds[path] = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                    except OSError:
                        pass
        if not fds:
            time.sleep(1)
            continue
        ready, _, _ = select.select(list(fds.values()), [], [], 1.0)
        for fd in ready:
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:  # device went away
                for p, f in list(fds.items()):
                    if f == fd:
                        os.close(f)
                        del fds[p]
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, etype, code, value = EVENT.unpack_from(data, i)
                if etype != EV_KEY or value == 2:  # ignore autorepeat
                    continue
                name = names.get(code)
                if not name:
                    continue
                sys.stdout.write(("D " if value == 1 else "U ") + name + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
