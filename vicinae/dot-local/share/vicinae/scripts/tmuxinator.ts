#!/usr/bin/env node
// @vicinae.schemaVersion 1
// @vicinae.title Tmuxinator
// @vicinae.mode silent
// @vicinae.exec ["/bin/sh", "-c", "exec \"$(ls -d \"$HOME\"/.local/share/vicinae/node/*/node | tail -n 1)\" --no-warnings \"$0\" \"$@\""]

// No node on PATH, so the exec line above runs this with the node that vicinae
// bundles for its extensions (>= 22.18, which strips TypeScript types natively).

import { spawn, spawnSync } from "node:child_process";

// vicinae is a GUI app, so scripts don't inherit the shell's PATH.
process.env.PATH = `/opt/homebrew/bin:${process.env.HOME}/.local/bin:${process.env.PATH}`;

const ACTIVE_MARK = " *";

function tmuxinator(...args: string[]): string {
  const res = spawnSync("tmuxinator", args, { encoding: "utf8" });
  if (res.error) throw res.error;
  return res.stdout;
}

function listProjects(...flags: string[]): string[] {
  return tmuxinator("list", "-n", ...flags)
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && line !== "tmuxinator projects:");
}

/** Shows a vicinae list and returns the picked entry, or null if dismissed. */
function pick(placeholder: string, entries: string[]): string | null {
  const res = spawnSync("vicinae", ["dmenu", "--placeholder", placeholder], {
    input: entries.join("\n"),
    encoding: "utf8",
  });
  if (res.error) throw res.error;
  return res.stdout.trim() || null;
}

const shellQuote = (arg: string): string => `'${arg.replaceAll("'", `'\\''`)}'`;

const NEW_GHOSTTY_WINDOW = `
on run argv
  tell application "Ghostty"
    activate
    new window with configuration {command:(item 1 of argv)}
  end tell
end run`;

/**
 * Runs tmuxinator in a new window of the already running Ghostty (via its
 * AppleScript API), through an interactive login zsh so $EDITOR and PATH are set.
 */
function inTerminal(...args: string[]): void {
  const command = `/bin/zsh -lic 'tmuxinator "$@"' zsh ${args.map(shellQuote).join(" ")}`;
  spawn("osascript", ["-e", NEW_GHOSTTY_WINDOW, command], {
    detached: true,
    stdio: "ignore",
  }).unref();
}

const active = new Set(listProjects("-a"));
const projects = new Map(
  listProjects().map((name) => [active.has(name) ? name + ACTIVE_MARK : name, name]),
);

const picked = pick("tmuxinator projects:", [...projects.keys()]);
const project = picked && projects.get(picked);

if (project) {
  const actions = active.has(project)
    ? ["start", "stop", "restart", "edit"]
    : ["start", "edit"];

  switch (pick(`project: ${project}`, actions)) {
    case "start":
      inTerminal("start", project);
      break;
    case "restart":
      tmuxinator("stop", project);
      inTerminal("start", project);
      break;
    case "stop":
      tmuxinator("stop", project);
      break;
    case "edit":
      inTerminal("edit", project);
      break;
  }
}
