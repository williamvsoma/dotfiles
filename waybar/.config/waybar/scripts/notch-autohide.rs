use std::env;
use std::fs;
use std::io::{ErrorKind, Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant, SystemTime};

const HOTSPOT_Y: i32 = 6;
const KEEP_Y: i32 = 72;
const HOTSPOT_WIDTH: i32 = 620;
const KEEP_WIDTH: i32 = 720;
const PEEK_SECONDS: Duration = Duration::from_millis(750);
const ACTIVE_POLL_SECONDS: Duration = Duration::from_millis(80);
const IDLE_POLL_SECONDS: Duration = Duration::from_millis(350);
const MONITOR_REFRESH_SECONDS: Duration = Duration::from_secs(60);
const IPC_TIMEOUT: Duration = Duration::from_millis(350);

const SIGUSR1: i32 = 10;
const SIGUSR2: i32 = 12;

unsafe extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
}

#[derive(Clone, Copy)]
struct Point {
    x: i32,
    y: i32,
}

#[derive(Clone, Copy)]
struct Monitor {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
}

#[derive(Clone, PartialEq, Eq)]
struct Paths {
    command_socket: PathBuf,
    event_socket: PathBuf,
}

#[derive(Default)]
struct EventActions {
    peek: bool,
    refresh_monitors: bool,
}

struct EventSocket {
    path: PathBuf,
    stream: UnixStream,
    buffer: Vec<u8>,
}

fn debug(message: &str) {
    if env::var_os("WAYBAR_NOTCH_DEBUG").is_some() {
        eprintln!("{message}");
    }
}

fn runtime_dir() -> PathBuf {
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn socket_paths_for_dir(dir: PathBuf) -> Option<Paths> {
    let command_socket = dir.join(".socket.sock");
    let event_socket = dir.join(".socket2.sock");

    if command_socket.exists() && event_socket.exists() {
        Some(Paths {
            command_socket,
            event_socket,
        })
    } else {
        None
    }
}

fn hyprland_paths() -> Option<Paths> {
    let runtime = runtime_dir();
    let hypr_runtime_dir = runtime.join("hypr");

    if let Some(signature) = env::var_os("HYPRLAND_INSTANCE_SIGNATURE") {
        if let Some(paths) = socket_paths_for_dir(hypr_runtime_dir.join(signature)) {
            return Some(paths);
        }
    }

    fs::read_dir(hypr_runtime_dir)
        .ok()?
        .filter_map(Result::ok)
        .filter_map(|entry| {
            let paths = socket_paths_for_dir(entry.path())?;
            let modified = paths
                .command_socket
                .metadata()
                .and_then(|metadata| metadata.modified())
                .unwrap_or(SystemTime::UNIX_EPOCH);
            Some((modified, paths))
        })
        .max_by_key(|(modified, _)| *modified)
        .map(|(_, paths)| paths)
}

fn lock_socket_path() -> PathBuf {
    runtime_dir().join("waybar-notch-autohide.sock")
}

fn acquire_lock(path: &Path) -> Option<UnixListener> {
    match UnixListener::bind(path) {
        Ok(listener) => Some(listener),
        Err(_) => {
            if UnixStream::connect(path).is_ok() {
                None
            } else {
                let _ = fs::remove_file(path);
                UnixListener::bind(path).ok()
            }
        }
    }
}

fn wait_for_hyprland_paths() -> Paths {
    loop {
        if let Some(paths) = hyprland_paths() {
            return paths;
        }

        debug("waiting for Hyprland IPC sockets");
        thread::sleep(Duration::from_secs(1));
    }
}

fn hyprland_request(socket_path: &Path, command: &str) -> Option<String> {
    let mut stream = UnixStream::connect(socket_path).ok()?;
    let _ = stream.set_read_timeout(Some(IPC_TIMEOUT));
    let _ = stream.set_write_timeout(Some(IPC_TIMEOUT));

    stream.write_all(command.as_bytes()).ok()?;
    let _ = stream.shutdown(std::net::Shutdown::Write);

    let mut response = String::new();
    stream.read_to_string(&mut response).ok()?;
    Some(response)
}

fn int_field(input: &str, field: &str) -> Option<i32> {
    let needle = format!("\"{field}\"");
    let start = input.find(&needle)?;
    let after_key = &input[start + needle.len()..];
    let colon = after_key.find(':')?;
    let after_colon = after_key[colon + 1..].trim_start();

    let mut end = 0;
    for (index, ch) in after_colon.char_indices() {
        if index == 0 && ch == '-' {
            end = ch.len_utf8();
            continue;
        }

        if ch.is_ascii_digit() {
            end = index + ch.len_utf8();
            continue;
        }

        break;
    }

    if end == 0 {
        return None;
    }

    after_colon[..end].parse().ok()
}

fn cursor_position(command_socket: &Path) -> Option<Point> {
    let response = hyprland_request(command_socket, "j/cursorpos")?;
    Some(Point {
        x: int_field(&response, "x")?,
        y: int_field(&response, "y")?,
    })
}

fn top_level_objects(input: &str) -> Vec<&str> {
    let mut objects = Vec::new();
    let mut depth = 0_i32;
    let mut start = None;
    let mut in_string = false;
    let mut escaped = false;

    for (index, ch) in input.char_indices() {
        if in_string {
            if escaped {
                escaped = false;
            } else if ch == '\\' {
                escaped = true;
            } else if ch == '"' {
                in_string = false;
            }
            continue;
        }

        match ch {
            '"' => in_string = true,
            '{' => {
                if depth == 0 {
                    start = Some(index);
                }
                depth += 1;
            }
            '}' => {
                depth -= 1;
                if depth == 0 {
                    if let Some(start_index) = start.take() {
                        objects.push(&input[start_index..=index]);
                    }
                }
            }
            _ => {}
        }
    }

    objects
}

fn monitors(command_socket: &Path) -> Vec<Monitor> {
    let Some(response) = hyprland_request(command_socket, "j/monitors") else {
        return Vec::new();
    };

    top_level_objects(&response)
        .into_iter()
        .filter_map(|object| {
            Some(Monitor {
                x: int_field(object, "x")?,
                y: int_field(object, "y")?,
                width: int_field(object, "width")?,
                height: int_field(object, "height")?,
            })
        })
        .collect()
}

fn monitor_for_cursor(position: Point, monitors: &[Monitor]) -> Option<Monitor> {
    for monitor in monitors {
        let within_x = monitor.x <= position.x && position.x < monitor.x + monitor.width;
        let within_y = monitor.y <= position.y && position.y < monitor.y + monitor.height;
        if within_x && within_y {
            return Some(*monitor);
        }
    }

    monitors.first().copied()
}

fn near_notch(position: Option<Point>, monitors: &[Monitor], y_limit: i32, width: i32) -> bool {
    let Some(position) = position else {
        return false;
    };
    let Some(monitor) = monitor_for_cursor(position, monitors) else {
        return false;
    };

    let center = monitor.x + monitor.width / 2;
    monitor.y <= position.y
        && position.y <= monitor.y + y_limit
        && (position.x - center).abs() <= width / 2
}

fn waybar_pids() -> Vec<i32> {
    let Ok(entries) = fs::read_dir("/proc") else {
        return Vec::new();
    };

    entries
        .filter_map(Result::ok)
        .filter_map(|entry| entry.file_name().to_string_lossy().parse::<i32>().ok())
        .filter(|pid| {
            fs::read_to_string(format!("/proc/{pid}/comm"))
                .map(|comm| comm.trim() == "waybar")
                .unwrap_or(false)
        })
        .collect()
}

fn signal_waybar(signal: i32) -> bool {
    let pids = waybar_pids();
    if pids.is_empty() {
        return false;
    }

    for pid in pids {
        unsafe {
            let _ = kill(pid, signal);
        }
    }

    true
}

fn set_waybar_visible(desired: bool, current: Option<bool>) -> Option<bool> {
    if current == Some(desired) {
        return current;
    }

    let signal = if desired { SIGUSR2 } else { SIGUSR1 };
    if signal_waybar(signal) {
        debug(if desired { "show" } else { "hide" });
        Some(desired)
    } else {
        Some(false)
    }
}

fn connect_event_socket(path: &Path) -> Option<EventSocket> {
    let stream = UnixStream::connect(path).ok()?;
    stream.set_nonblocking(true).ok()?;
    debug("connected to Hyprland event socket");

    Some(EventSocket {
        path: path.to_path_buf(),
        stream,
        buffer: Vec::with_capacity(4096),
    })
}

fn classify_event(event: &str) -> EventActions {
    let mut actions = EventActions::default();

    if matches!(
        event,
        "workspace"
            | "workspacev2"
            | "createworkspace"
            | "createworkspacev2"
            | "focusedmon"
            | "moveworkspace"
            | "moveworkspacev2"
    ) {
        actions.peek = true;
    }

    if matches!(
        event,
        "focusedmon" | "monitoradded" | "monitoraddedv2" | "monitorremoved" | "monitorremovedv2"
    ) {
        actions.refresh_monitors = true;
    }

    actions
}

fn merge_actions(target: &mut EventActions, source: EventActions) {
    target.peek |= source.peek;
    target.refresh_monitors |= source.refresh_monitors;
}

fn process_event_line(line: &[u8]) -> EventActions {
    let Ok(line) = std::str::from_utf8(line) else {
        return EventActions::default();
    };
    let event = line
        .trim_end()
        .split_once(">>")
        .map(|(event, _)| event)
        .unwrap_or(line);

    classify_event(event)
}

fn drain_event_socket(socket: &mut EventSocket) -> Result<EventActions, ()> {
    let mut actions = EventActions::default();
    let mut chunk = [0_u8; 4096];

    loop {
        match socket.stream.read(&mut chunk) {
            Ok(0) => return Err(()),
            Ok(n) => {
                socket.buffer.extend_from_slice(&chunk[..n]);
                while let Some(index) = socket.buffer.iter().position(|byte| *byte == b'\n') {
                    let line: Vec<u8> = socket.buffer.drain(..=index).collect();
                    merge_actions(&mut actions, process_event_line(&line));
                }
            }
            Err(error) if error.kind() == ErrorKind::WouldBlock => return Ok(actions),
            Err(_) => return Err(()),
        }
    }
}

fn event_actions(event_socket: &mut Option<EventSocket>, event_path: &Path) -> EventActions {
    let should_connect = event_socket
        .as_ref()
        .map(|socket| socket.path.as_path() != event_path)
        .unwrap_or(true);

    if should_connect {
        *event_socket = connect_event_socket(event_path);
    }

    let Some(socket) = event_socket.as_mut() else {
        return EventActions::default();
    };

    match drain_event_socket(socket) {
        Ok(actions) => actions,
        Err(()) => {
            *event_socket = None;
            EventActions::default()
        }
    }
}

fn refresh_paths(paths: &mut Paths, event_socket: &mut Option<EventSocket>) -> bool {
    let Some(new_paths) = hyprland_paths() else {
        return false;
    };

    if *paths != new_paths {
        debug("Hyprland IPC socket path changed");
        *paths = new_paths;
        *event_socket = None;
    }

    true
}

fn refresh_monitors(paths: &mut Paths, event_socket: &mut Option<EventSocket>) -> Vec<Monitor> {
    let mut refreshed = monitors(&paths.command_socket);
    if refreshed.is_empty() && refresh_paths(paths, event_socket) {
        refreshed = monitors(&paths.command_socket);
    }
    refreshed
}

fn refresh_cursor(paths: &mut Paths, event_socket: &mut Option<EventSocket>) -> Option<Point> {
    let mut cursor = cursor_position(&paths.command_socket);
    if cursor.is_none() && refresh_paths(paths, event_socket) {
        cursor = cursor_position(&paths.command_socket);
    }
    cursor
}

fn main() {
    let Some(_lock) = acquire_lock(&lock_socket_path()) else {
        return;
    };

    let mut paths = wait_for_hyprland_paths();
    let mut event_socket = None;
    let mut known_monitors = refresh_monitors(&mut paths, &mut event_socket);
    let mut next_monitor_refresh = Instant::now() + MONITOR_REFRESH_SECONDS;
    let mut peek_until = Instant::now();
    let mut visible = None;

    loop {
        let now = Instant::now();
        let actions = event_actions(&mut event_socket, &paths.event_socket);

        if actions.peek {
            let next_peek = now + PEEK_SECONDS;
            if next_peek > peek_until {
                peek_until = next_peek;
            }
        }

        if actions.refresh_monitors || now >= next_monitor_refresh {
            let refreshed = refresh_monitors(&mut paths, &mut event_socket);
            if !refreshed.is_empty() {
                known_monitors = refreshed;
            }
            next_monitor_refresh = now + MONITOR_REFRESH_SECONDS;
        }

        let cursor = refresh_cursor(&mut paths, &mut event_socket);
        let wants_hotspot = near_notch(cursor, &known_monitors, HOTSPOT_Y, HOTSPOT_WIDTH);
        let keeps_notch =
            visible == Some(true) && near_notch(cursor, &known_monitors, KEEP_Y, KEEP_WIDTH);
        let close_to_notch = near_notch(cursor, &known_monitors, KEEP_Y + 64, KEEP_WIDTH + 160);
        let peeking = now < peek_until;
        let desired_visible = wants_hotspot || keeps_notch || peeking;

        visible = set_waybar_visible(desired_visible, visible);

        let poll_interval = if desired_visible || close_to_notch {
            ACTIVE_POLL_SECONDS
        } else {
            IDLE_POLL_SECONDS
        };
        thread::sleep(poll_interval);
    }
}
