#!/usr/bin/env node
// @vicinae.schemaVersion 1
// @vicinae.title Switch App Windows
// @vicinae.mode silent
// @vicinae.exec ["/bin/sh", "-c", "exec \"$(ls -d \"$HOME\"/.local/share/vicinae/node/*/node | tail -n 1)\" --no-warnings \"$0\" \"$@\""]

// Like vicinae's "Switch Windows", but limited to the windows of the app that
// is currently in focus.
//
// No node on PATH, so the exec line above runs this with the node that vicinae
// bundles for its extensions (>= 22.18, which strips TypeScript types natively).
//
// Windows are read and raised through System Events, which needs the
// Accessibility permission (System Settings > Privacy & Security).

import { spawnSync } from "node:child_process";

// vicinae is a GUI app, so scripts don't inherit the shell's PATH.
process.env.PATH = `/opt/homebrew/bin:${process.env.HOME}/.local/bin:${process.env.PATH}`;

interface FocusedApp {
  name: string;
  pid: number;
  /** Window titles, front to back. */
  windows: string[];
}

/** Runs a JXA script whose `run(argv)` returns JSON. */
function jxa<T>(script: string, ...args: string[]): T {
  const res = spawnSync("osascript", ["-l", "JavaScript", "-e", script, ...args], {
    encoding: "utf8",
  });
  if (res.error) throw res.error;
  if (res.status !== 0) throw new Error(res.stderr.trim());
  return JSON.parse(res.stdout);
}

// Chrome web apps leave the window title empty, but carry the page title on
// the group that wraps the window's content, so that is the fallback.
const FOCUSED_APP = `
function run() {
  const app = Application("System Events").applicationProcesses.whose({ frontmost: true })[0];
  const titles = app.windows.name();
  let groups = [];
  try { groups = app.windows.groups.name(); } catch (e) {}
  const windows = titles.map((title, i) => title || (groups[i] || []).find(Boolean) || "");
  return JSON.stringify({ name: app.displayedName(), pid: app.unixId(), windows });
}`;

// The window is looked up again by position, so it must run before anything
// else reorders the app's windows.
const RAISE_WINDOW = `
function run([pid, index]) {
  const app = Application("System Events").applicationProcesses.whose({ unixId: Number(pid) })[0];
  const win = app.windows[Number(index)];
  const minimized = win.attributes.byName("AXMinimized");
  if (minimized.value()) minimized.value = false;
  win.actions.byName("AXRaise").perform();
  app.frontmost = true;
  return "null";
}`;

/** Shows a vicinae list and returns the picked entry, or null if dismissed. */
function pick(placeholder: string, entries: string[]): string | null {
  const res = spawnSync("vicinae", ["dmenu", "--placeholder", placeholder], {
    input: entries.join("\n"),
    encoding: "utf8",
  });
  if (res.error) throw res.error;
  return res.stdout.trim() || null;
}

const app = jxa<FocusedApp>(FOCUSED_APP);

// Label -> window position. Titles can repeat, so repeats get a counter.
const windows = new Map<string, number>();
app.windows.forEach((title, index) => {
  const base = title?.trim() || "(untitled)";
  let label = base;
  for (let n = 2; windows.has(label); n++) label = `${base} (${n})`;
  windows.set(label, index);
});

// The front window is the one already in focus, so list it last.
const [current, ...others] = windows.keys();
const entries = current === undefined ? [] : [...others, current];

const picked = entries.length ? pick(`${app.name} windows:`, entries) : null;
const index = picked === null ? undefined : windows.get(picked);

if (index !== undefined) jxa(RAISE_WINDOW, String(app.pid), String(index));
