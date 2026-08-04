//! Subscribe to yashiki's state stream and fire sketchybar events.
//!
//!   yashiki_workspace_change  OUTPUT_{id}_ACTIVE_TAGS / _OCCUPIED_TAGS / _TAG_APPS_{1..10}
//!   yashiki_focus_change      FLOAT=true|false
//!   yashiki_mode_change       MODE=normal|resize
//!
//! Long-running process, started with & from sketchybar's items/init.lua.
//!
//! Translation only. Never write back to yashiki. The borders colour and focus
//! recovery belong to ~/.config/yashiki/focus_watcher.sh.

use std::collections::BTreeMap;
use std::io::{BufRead, BufReader};
use std::process::{Child, ChildStdout, Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

use serde_json::Value;

const SKETCHYBAR: &str = "/opt/homebrew/bin/sketchybar";
const TAG_COUNT: usize = 10;

/// Drain whatever else already arrived before firing, so a burst (an app
/// opening several windows) collapses into one trigger instead of one per line.
const COALESCE: Duration = Duration::from_millis(10);

/// Rapid tag switching (holding alt-tab) makes yashiki emit a long stream of
/// alternating states, often lagging behind the keys because every switch also
/// retiles. Forwarding each one makes the bar chase stale targets back and
/// forth long after the user stopped. If we fired recently, treat the stream
/// as a burst: keep folding until it goes quiet, but never sit on updates
/// longer than the cap, so mid-burst progress still shows.
const BURST_DETECT: Duration = Duration::from_millis(250);
const BURST_QUIET: Duration = Duration::from_millis(80);
const BURST_CAP: Duration = Duration::from_millis(350);

const RESUBSCRIBE_DELAY: Duration = Duration::from_secs(2);

struct Window {
    tags: i64,
    floating: bool,
    app_id: String,
    output: String,
}

#[derive(Default)]
struct State {
    displays: BTreeMap<String, i64>,
    windows: BTreeMap<String, Window>,
    focused_window: String,
}

/// What has to be fired after folding a batch of messages.
#[derive(Default)]
struct Pending {
    workspace: bool,
    focus: bool,
    mode: Option<String>,
}

/// yashiki sends ids as numbers; take strings too rather than guessing.
fn id(value: &Value) -> String {
    match value {
        Value::Number(n) => n.to_string(),
        Value::String(s) => s.clone(),
        _ => String::new(),
    }
}

fn window_from(value: &Value) -> Window {
    Window {
        tags: value["tags"].as_i64().unwrap_or(0),
        floating: value["is_floating"].as_bool().unwrap_or(false),
        app_id: value["app_id"].as_str().unwrap_or("").to_owned(),
        output: id(&value["output_id"]),
    }
}

impl State {
    fn apply(&mut self, msg: &Value) -> Pending {
        match msg["type"].as_str().unwrap_or("") {
            "snapshot" => {
                self.displays.clear();
                self.windows.clear();
                if let Some(displays) = msg["displays"].as_array() {
                    for d in displays {
                        self.displays
                            .insert(id(&d["id"]), d["visible_tags"].as_i64().unwrap_or(0));
                    }
                }
                if let Some(windows) = msg["windows"].as_array() {
                    for w in windows {
                        self.windows.insert(id(&w["id"]), window_from(w));
                    }
                }
                self.focused_window = id(&msg["focused_window_id"]);
                Pending {
                    workspace: true,
                    focus: true,
                    mode: None,
                }
            }
            "tags_changed" => {
                self.displays.insert(
                    id(&msg["display_id"]),
                    msg["visible_tags"].as_i64().unwrap_or(0),
                );
                Pending {
                    workspace: true,
                    ..Pending::default()
                }
            }
            "display_focused" => Pending {
                workspace: true,
                focus: true,
                mode: None,
            },
            "window_focused" => {
                let wid = id(&msg["window_id"]);
                // Focus ended up nowhere. Nothing to display, so leave it.
                // Recovery is focus_watcher.sh's job.
                if wid.is_empty() || wid == "0" {
                    return Pending::default();
                }
                self.focused_window = wid;
                Pending {
                    focus: true,
                    ..Pending::default()
                }
            }
            "window_created" | "window_updated" => {
                let win = &msg["window"];
                let wid = id(&win["id"]);
                if win["is_focused"].as_bool().unwrap_or(false) {
                    self.focused_window = wid.clone();
                }
                self.windows.insert(wid, window_from(win));
                Pending {
                    workspace: true,
                    focus: true,
                    mode: None,
                }
            }
            "window_destroyed" => {
                self.windows.remove(&id(&msg["window_id"]));
                Pending {
                    workspace: true,
                    focus: true,
                    mode: None,
                }
            }
            "mode_changed" => Pending {
                mode: Some(msg["mode"].as_str().unwrap_or("normal").to_owned()),
                ..Pending::default()
            },
            _ => Pending::default(),
        }
    }

    fn workspace_args(&self) -> Vec<String> {
        let mut args = Vec::new();
        for (display, visible_tags) in &self.displays {
            // active = visible_tags of the display
            args.push(format!("OUTPUT_{display}_ACTIVE_TAGS={visible_tags}"));

            // occupied = union of the tags of the windows on that display
            let mut occupied = 0i64;
            let mut tag_apps: Vec<Vec<&str>> = vec![Vec::new(); TAG_COUNT];
            for win in self.windows.values() {
                if &win.output != display {
                    continue;
                }
                occupied |= win.tags;
                if win.app_id.is_empty() {
                    continue;
                }
                for (i, apps) in tag_apps.iter_mut().enumerate() {
                    if win.tags & (1 << i) != 0 && !apps.contains(&win.app_id.as_str()) {
                        apps.push(&win.app_id);
                    }
                }
            }

            args.push(format!("OUTPUT_{display}_OCCUPIED_TAGS={occupied}"));
            for (i, apps) in tag_apps.iter().enumerate() {
                args.push(format!(
                    "OUTPUT_{display}_TAG_APPS_{}={}",
                    i + 1,
                    apps.join(",")
                ));
            }
        }
        args
    }

    fn focused_is_floating(&self) -> bool {
        self.windows
            .get(&self.focused_window)
            .is_some_and(|w| w.floating)
    }
}

fn trigger(event: &str, args: &[String]) {
    let _ = Command::new(SKETCHYBAR)
        .arg("--trigger")
        .arg(event)
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

const SUBSCRIBE_ARGS: [&str; 4] = [
    "subscribe",
    "--snapshot",
    "--filter",
    "tags,focus,window,mode",
];

fn kill_pids(out: std::process::Output, self_pid: &str) {
    for pid in String::from_utf8_lossy(&out.stdout).split_whitespace() {
        if pid != self_pid {
            let _ = Command::new("kill").arg(pid).status();
        }
    }
}

/// A sketchybar restart would otherwise leave the previous bridge behind, and
/// killing a bridge leaves its `yashiki subscribe` child running, so clear both.
fn kill_previous_generation() {
    let self_pid = std::process::id().to_string();

    // -x matches the process name exactly, so an editor holding the source open
    // does not match.
    if let Ok(out) = Command::new("pgrep")
        .arg("-x")
        .arg("yashiki-bridge")
        .output()
    {
        kill_pids(out, &self_pid);
    }

    // Ours is not spawned yet, so anything matching here is orphaned. The filter
    // makes the pattern specific to this bridge.
    let pattern = format!("yashiki {}", SUBSCRIBE_ARGS.join(" "));
    if let Ok(out) = Command::new("pgrep").arg("-f").arg(&pattern).output() {
        kill_pids(out, &self_pid);
    }
}

fn subscribe() -> Option<Child> {
    Command::new("yashiki")
        .args(SUBSCRIBE_ARGS)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()
}

fn pump(stdout: ChildStdout) {
    // Read on a thread so the main loop can wait for "nothing more arrived"
    // with a timeout, which is what makes coalescing possible.
    let (tx, rx) = mpsc::channel::<String>();
    thread::spawn(move || {
        for line in BufReader::new(stdout).lines() {
            match line {
                Ok(line) => {
                    if tx.send(line).is_err() {
                        return;
                    }
                }
                Err(_) => return,
            }
        }
    });

    let mut state = State::default();
    let mut last_fire: Option<Instant> = None;
    while let Ok(mut line) = rx.recv() {
        let mut pending = Pending::default();
        let in_burst = last_fire.is_some_and(|t| t.elapsed() < BURST_DETECT);
        let quiet = if in_burst { BURST_QUIET } else { COALESCE };
        let deadline = Instant::now() + BURST_CAP;
        loop {
            if let Ok(msg) = serde_json::from_str::<Value>(line.trim()) {
                let next = state.apply(&msg);
                pending.workspace |= next.workspace;
                pending.focus |= next.focus;
                if next.mode.is_some() {
                    pending.mode = next.mode;
                }
            }
            let now = Instant::now();
            if now >= deadline {
                break;
            }
            match rx.recv_timeout(quiet.min(deadline - now)) {
                Ok(next) => line = next,
                Err(_) => break,
            }
        }

        if pending.workspace {
            trigger("yashiki_workspace_change", &state.workspace_args());
        }
        if pending.focus {
            let floating = state.focused_is_floating();
            trigger("yashiki_focus_change", &[format!("FLOAT={floating}")]);
        }
        if let Some(mode) = pending.mode {
            trigger("yashiki_mode_change", &[format!("MODE={mode}")]);
        }
        last_fire = Some(Instant::now());
    }
}

fn main() {
    kill_previous_generation();
    loop {
        if let Some(mut child) = subscribe() {
            if let Some(stdout) = child.stdout.take() {
                pump(stdout);
            }
            let _ = child.wait();
        }
        thread::sleep(RESUBSCRIBE_DELAY);
    }
}
