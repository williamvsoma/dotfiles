#!/usr/bin/env python3
import fcntl
import json
import os
import signal
import socket
import subprocess
import sys
import threading
import time

HOTSPOT_Y = 6
KEEP_Y = 72
HOTSPOT_WIDTH = 620
KEEP_WIDTH = 720
PEEK_SECONDS = 0.75
POLL_SECONDS = 0.16
MONITOR_REFRESH_SECONDS = 2.0
DEBUG = os.environ.get("WAYBAR_NOTCH_DEBUG") == "1"

WORKSPACE_EVENTS = {
    "workspace",
    "workspacev2",
    "createworkspace",
    "createworkspacev2",
    "focusedmon",
    "moveworkspace",
    "moveworkspacev2",
}

runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
lock_path = os.path.join(runtime_dir, "waybar-notch-autohide.lock")
lock_file = open(lock_path, "w")

try:
    fcntl.lockf(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError:
    sys.exit(0)

peek_until = 0.0
state_lock = threading.Lock()
running = True


def debug(message):
    if DEBUG:
        print(message, file=sys.stderr, flush=True)


def run_json(command):
    try:
        result = subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=0.35,
        )
        return json.loads(result.stdout)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return None


def waybar_is_running():
    return subprocess.run(
        ["pgrep", "-x", "waybar"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def signal_waybar(signame):
    debug(f"signal {signame}")
    subprocess.run(
        ["pkill", f"-{signame}", "-x", "waybar"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def set_waybar_visible(visible, current_visible):
    if visible == current_visible:
        return current_visible

    if waybar_is_running():
        signal_waybar("SIGUSR2" if visible else "SIGUSR1")
        return visible

    return False


def cursor_position():
    position = run_json(["hyprctl", "-j", "cursorpos"])
    if not isinstance(position, dict):
        return None

    try:
        return int(position["x"]), int(position["y"])
    except (KeyError, TypeError, ValueError):
        return None


def monitors():
    data = run_json(["hyprctl", "-j", "monitors"])
    if not isinstance(data, list):
        return []

    parsed = []
    for monitor in data:
        try:
            parsed.append(
                {
                    "x": int(monitor["x"]),
                    "y": int(monitor["y"]),
                    "width": int(monitor["width"]),
                    "height": int(monitor["height"]),
                }
            )
        except (KeyError, TypeError, ValueError):
            continue

    return parsed


def monitor_for_cursor(position, known_monitors):
    if not position:
        return None

    x, y = position
    for monitor in known_monitors:
        within_x = monitor["x"] <= x < monitor["x"] + monitor["width"]
        within_y = monitor["y"] <= y < monitor["y"] + monitor["height"]
        if within_x and within_y:
            return monitor

    if known_monitors:
        return known_monitors[0]

    return None


def near_notch(position, known_monitors, y_limit, width):
    monitor = monitor_for_cursor(position, known_monitors)
    if not position or not monitor:
        return False

    x, y = position
    center = monitor["x"] + monitor["width"] / 2
    return monitor["y"] <= y <= monitor["y"] + y_limit and abs(x - center) <= width / 2


def request_peek():
    global peek_until

    with state_lock:
        peek_until = max(peek_until, time.monotonic() + PEEK_SECONDS)
    debug("peek")


def peek_active():
    with state_lock:
        return time.monotonic() < peek_until


def hyprland_event_socket():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        return None

    return os.path.join(runtime_dir, "hypr", signature, ".socket2.sock")


def listen_for_workspace_events():
    path = hyprland_event_socket()
    if not path:
        debug("missing Hyprland socket path")
        return

    while running:
        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(path)
            debug(f"connected {path}")
            with client, client.makefile("r") as stream:
                for line in stream:
                    event = line.split(">>", 1)[0]
                    debug(f"event {event}")
                    if event in WORKSPACE_EVENTS:
                        request_peek()
        except OSError:
            debug("event socket reconnect")
            time.sleep(1.0)


def handle_signal(signum, frame):
    global running
    running = False


signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)

threading.Thread(target=listen_for_workspace_events, daemon=True).start()

known_monitors = monitors()
next_monitor_refresh = time.monotonic() + MONITOR_REFRESH_SECONDS
visible = None

while running:
    now = time.monotonic()

    if now >= next_monitor_refresh:
        refreshed = monitors()
        if refreshed:
            known_monitors = refreshed
        next_monitor_refresh = now + MONITOR_REFRESH_SECONDS

    cursor = cursor_position()
    wants_hotspot = near_notch(cursor, known_monitors, HOTSPOT_Y, HOTSPOT_WIDTH)
    keeps_notch = visible and near_notch(cursor, known_monitors, KEEP_Y, KEEP_WIDTH)
    desired_visible = wants_hotspot or keeps_notch or peek_active()

    visible = set_waybar_visible(desired_visible, visible)
    time.sleep(POLL_SECONDS)
