# Copilot Documentation — vim-arsync

> This file is intended to be read at the start of every Copilot conversation to provide
> full context on the project, its architecture, and its evolution. Update it after every
> meaningful session.

---

## Project Overview

**Repository:** `jenkeeri/vim-arsync`
**Fork of:** `kenn7/vim-arsync`

A Vim/Neovim plugin for **asynchronous rsync-based synchronisation** between a local machine
and a remote host (or between two local paths). The primary use-case for this fork's author is:

- **Local (edit):** MacBook running Neovim
- **Remote (build/run):** Linux host where all C++ compilation happens
- Workflow: edit on Mac → auto-sync to Linux → build remotely → optionally pull results back

---

## Repository Layout

```
vim-arsync/
├── plugin/
│   └── vim-arsync.vim          # Main plugin file: config parsing, rsync command builder,
│                               #   async job dispatch, auto-sync autocmds, user commands
├── autoload/
│   └── arsync/
│       └── job.vim             # Bundled async job library (from prabirshrestha/async.vim)
│                               #   Abstracts nvimjob / vimjob differences
├── README.md
├── LICENSE
└── copilot-documentation.md    # This file
```

---

## Key Architecture Points

### `plugin/vim-arsync.vim`

| Function | Purpose |
|---|---|
| `LoadConf()` | Parses `.vim-arsync` config file (walks up from cwd), returns a dict. Handles comments (`#`), blank lines, list fields (`ignore_path`, `include_path`). |
| `ARsync(direction)` | Builds the rsync command list for `up`, `down`, `upDelete`, `downDelete`. Handles remote vs local mode. Dispatches via `arsync#job#start`. |
| `JobHandler(...)` | Callback for stdout/stderr/exit. Streams rsync output to quickfix list; opens quickfix on non-zero exit. |
| `AutoSync()` | Registers (or clears) `BufWritePost`/`FileWritePost` autocmd for auto-sync. Re-evaluated on `VimEnter` and `DirChanged`. |
| `ShowConf()` | `:ARshowConf` — dumps parsed config dict to the command line. |

### `autoload/arsync/job.vim`

Thin wrapper around Neovim's `jobstart` / Vim's `job_start`. Provides:
- `arsync#job#start(cmd, opts)` — start a job, returns job id
- `arsync#job#stop(jobid)` — stop a job
- Unified `on_stdout`, `on_stderr`, `on_exit` callback interface

### `.vim-arsync` Config File

Placed at the root of a project. Key fields:

| Field | Default | Notes |
|---|---|---|
| `remote_host` | *(required)* | SSH hostname |
| `remote_path` | *(required)* | Path on remote |
| `remote_user` | — | SSH username |
| `remote_port` | 22 | SSH port |
| `remote_passwd` | — | Plaintext password (requires `sshpass`) |
| `local_path` | dir of `.vim-arsync` | Local root |
| `ignore_path` | — | List of rsync `--exclude` patterns |
| `include_path` | — | List of rsync `--include` patterns |
| `ignore_dotfiles` | 0 | Exclude `.*` when `1` |
| `auto_sync_up` | 0 | Auto-upload on every buffer write |
| `remote_or_local` | `remote` | `remote` = SSH, `local` = local fs |
| `sleep_before_sync` | 0 | Delay in seconds before rsync fires |
| `remote_options` | `-vazr` | rsync flags for remote mode |
| `local_options` | `-var` | rsync flags for local mode |

---

## Session History

### Session 1 — 2026-04-23 (Initial Analysis & Roadmap)

**Goal:** Understand the plugin and plan improvements for a C++ Mac↔Linux developer workflow.

**Key context shared by the developer:**
- Uses Neovim on MacBook to edit, Linux host to compile C++.
- Wants Git information but syncing `.git/` causes conflicts (commits on Linux overwrite local state).
- Needs improvements that help day-to-day C++ development over rsync.

**Outcome:** Created this documentation file. Improvement roadmap outlined below (see next section).

---

## Improvement Roadmap

Items are grouped by theme. Priority reflects usefulness for the primary C++ Mac↔Linux workflow.

### 🔴 High Priority

#### 1. `ignore_git` config option (Git-safe syncing)
- Add a boolean `ignore_git` field (default `0`). When set to `1`, automatically appends
  `--exclude '.git/'` to every rsync command.
- Prevents the most common pain point: Linux-side git commits overwriting the Mac's `.git/`.
- Simpler and more explicit than relying on `ignore_dotfiles` (which also hides useful files
  like `.clang-format`, `.clangd`, etc.).
- **Config example:** `ignore_git 1`

#### 2. Remote command execution after sync (`:ARsyncUpAndRun`)
- Add a `post_sync_cmd` config field: a shell command run on the remote host via `ssh` after
  a successful up-sync.
- Examples: `make -C ~/project/build -j8`, `cmake --build build/`, `ninja -C build/`.
- Output piped into the quickfix list — compiler errors immediately navigable in Neovim.
- This closes the primary C++ workflow loop: edit → sync → build → see errors — all inside Neovim.
- **Config example:** `post_sync_cmd make -C ~/project/build -j8`

#### 3. Dry-run preview mode (`:ARsyncDryRun`)
- Add a `:ARsyncDryRun` command that runs rsync with `--dry-run --itemize-changes`.
- Shows exactly which files would be transferred without touching anything.
- Vital before running `ARsyncUpDelete` or `ARsyncDownDelete`.

### 🟡 Medium Priority

#### 4. Remote Git status display (`:ARgitStatus`)
- Add a command that SSHs to the remote and runs `git -C <remote_path> log --oneline -5`
  and/or `git status --short`, piping output into a scratch buffer or the quickfix list.
- Lets the developer see what commits/changes exist on the Linux side without syncing `.git/`.
- No file transfer involved — read-only query over SSH.

#### 5. Statusline / notification integration
- Expose a `g:arsync_status` variable updated on every sync start/complete/error.
- Values: `''` (idle), `'syncing'`, `'ok'`, `'error'`.
- Allows statusline plugins (lualine, airline, lightline) to show a sync indicator.
- Add `g:arsync_last_sync_time` (timestamp string) for display.

#### 6. Debounce / coalesce rapid saves
- Currently every `BufWritePost` fires an immediate rsync. Saving multiple files in quick
  succession (e.g., a macro, a `:bufdo`) launches multiple parallel rsync processes.
- Add a configurable debounce timer (`debounce_ms`, default e.g. `500`): reset the timer on
  each save, only fire rsync when the timer expires.

#### 7. Multiple profile support
- Allow multiple `.vim-arsync` profiles (e.g. `.vim-arsync.debug`, `.vim-arsync.release`).
- Add `:ARsyncProfile <name>` command to switch the active profile.
- Useful when syncing to different build directories or different remote hosts.

### 🟢 Lower Priority / Nice to Have

#### 8. Per-file / per-directory sync (`ARsyncFile`, `ARsyncDir`)
- `:ARsyncFile` — sync only the currently open buffer to the remote, without syncing the
  whole project tree. Faster for single-file edits in large projects.
- `:ARsyncDir` — sync only the directory containing the current buffer.

#### 9. Conflict / newer-file warning
- Before a down-sync, optionally SSH and compare remote file modification times against local.
- Warn (but don't block) if local files are newer than remote — could indicate unsaved edits
  would be overwritten.

#### 10. `:ARshowConf` improvements
- Pretty-print the config instead of raw dict dump.
- Show the resolved rsync command that would be built, so the user can verify flags.

#### 11. Sync history / log buffer
- Keep an in-memory (or file-backed) log of the last N sync operations with timestamps,
  direction, and exit code. Viewable via `:ARsyncLog`.

---

## Known Issues / Tech Debt

- `eval()` is used to parse `ignore_path` / `include_path` list values — a potential
  code injection risk if the `.vim-arsync` file comes from an untrusted source.
- No lock/guard against concurrent rsync jobs: rapid saves or manual commands can spawn
  multiple simultaneous rsync processes targeting the same paths.
- `g:arsync_qfid` and `g:arsync_sleep_time` are global — if multiple projects are open in
  split windows, the last-registered config wins.
- Auto-sync group is fully replaced on every `DirChanged` / `VimEnter`, which is correct
  but means the `sleep_before_sync` global is clobbered if projects share a session.

---

## How to Read This File

At the start of a new Copilot session, paste the contents of this file or say:
> "Read copilot-documentation.md and use it as context for this session."

After completing work in a session, update:
1. The **Session History** section with a brief summary of what was done.
2. The **Improvement Roadmap** to mark completed items or add new ones.
3. Any new **Known Issues** discovered.
