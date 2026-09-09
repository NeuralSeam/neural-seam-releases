# Neural Seam Client Runtime: User Manual

This manual covers the `neural-seam` binary: how to install it, connect a project, use it day to day, and diagnose problems.

## 1. What it is (and what it is not)

The **Neural Seam Client Runtime** is a single binary (`neural-seam`) written in Go. It runs on **your workstation** and connects your local project to Neural Seam. While it is running it does two things at once:

- **MCP server (stdio):** exposes tools for your agent host (Claude Code) to consume: list activities, fetch harness artifacts, update card status, and semantic code capabilities backed by language servers.
- **Local HTTP bridge:** a small `localhost` server that talks to the Neural Seam web app while you create or connect a project, and writes the resulting files into your repository.

The runtime does **not**:

- run AI inference. Every model call happens in your agent host, started by you.
- act as an autonomous agent, worker, or replacement for your agent host.
- authenticate with Anthropic, or store any Anthropic key or secret.

### 1.1. Compliance promises

| Promise | What it means for you |
|---------|-----------------------|
| No Anthropic credentials | The runtime never uses an Anthropic OAuth token or API key. Your Anthropic login belongs to your agent host only. |
| Nothing runs on its own | Every step that reaches a model starts from an action you take in your terminal. `upgrade` and `register` are always started by you too. |
| Product account, not "Sign in with Anthropic" | Neural Seam sign-in uses a device flow against the Neural Seam backend. |
| Explicit extension | The binary identifies itself as `neural-seam-runtime`. It does not impersonate the official client. |
| Telemetry is opt-in | Off by default. Nothing leaves your machine unless you turn it on. |

---

## 2. Quick start (5 minutes)

From nothing to the first tool call in your agent host:

```sh
# 1. Install (Linux/macOS; Windows: see 4.1 for the graphical installer or 4.2 for PowerShell)
curl -fsSL https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.sh | sh

# 2. Confirm
neural-seam version

# 3. One-step onboarding, from your project directory
cd /path/to/your/project
neural-seam setup
#   -> signs you in (device flow), provisions language servers,
#      registers the project and validates the manifest. Ends in "ready".

# 4. Register the runtime in the project's .mcp.json so the host can see it
neural-seam register
```

Now **open your agent host in that directory**. The `session-start` hook runs `check_setup` automatically. Confirm that the `neural-seam-runtime` server connected, then invoke a tool, for example by asking the agent to **list the project activities** (tool `list_activities`).

---

## 3. Requirements and supported platforms

| Item | Required? | Notes |
|------|-----------|-------|
| **Agent host** (Claude Code) | Yes | It is what consumes the runtime's MCP tools over stdio. The runtime detects a host in a host agnostic way (`neural-seam doctor`, check `agent-host`). The runtime never installs, launches, imitates or authenticates as the host. |
| **Git** | Yes, for `neural-seam clone` | Required by the `clone` subcommand. The runtime writes files into your project root; versioning them is up to you. |
| `curl` or `wget` plus `sha256sum`/`shasum` | Only for the one-liner install (Linux/macOS) | The installer needs a download tool and a sha256 tool. |
| **Language toolchains** (Node, Go, .NET SDK, ...) | Depends | The runtime tries to provision language servers on its own; some still need a base toolchain on the machine (see section 9). |
| **Docker** | No, for basic use | Only relevant for environment orchestration. |

Platform coverage:

| Component | Windows | macOS | Linux |
|-----------|---------|-------|-------|
| `neural-seam` CLI (`serve`, `setup`, `doctor`, ...) | Yes | Yes | Yes |
| Graphical installer | Yes | No | No |
| System tray (`neural-seam-tray`) | Yes | No | No |
| Tray autostart | Yes | No | No |

On macOS and Linux the full onboarding flow is available through the CLI (`neural-seam setup`, then `neural-seam serve`). The tray and the graphical installer are Windows only. On other platforms `neural-seam setup` prints a banner stating that the tray is unavailable and that the CLI is the supported path.

---

## 4. Installation

Two paths, two roles. They are not competing options:

- The **graphical installer** (Windows) is the desktop path: it delivers the tray, autostart, guided onboarding (sign-in, project connect, language servers) and the component that performs local cleanup if your access is revoked.
- The **one-liner** is the developer, CI, and headless path: it installs the `neural-seam` CLI only, works on all three platforms, and provides no tray, autostart, or desktop integration.

Every install path verifies the **sha256** of the binary against the `checksums.txt` published with each release. The check is **mandatory** and aborts the installation on a mismatch, a missing checksum, or a failed download.

> **Integrity, stated honestly:** publisher code signing and TLS certificate pinning are **not in place yet**. Today the integrity guarantee is sha256 plus HTTPS, not a publisher signature. Treat that as a known limitation when deciding how to distribute the binary inside your organization.

Package manager installs (Homebrew, Scoop, winget) are **not available yet**. Use the one-liner or the manual download.

### 4.1. Graphical installer (Windows)

The graphical installer is the fastest way to get set up without opening a terminal.

Download `neural-seam-installer-windows-amd64-setup.exe` from the [latest release](https://github.com/NeuralSeam/neural-seam-releases/releases/latest).

Double-click the `.exe`. SmartScreen may warn that the publisher is unknown (the binary is not signed yet): click **More info**, then **Run anyway**.

The wizard detects the current state and shows only the screens you need:

| Screen | When it appears |
|--------|-----------------|
| **Install** | `neural-seam` is not on the `PATH`. Includes the checkbox "Start Neural Seam Tray when the computer starts" (**unchecked** by default), which controls autostart (see section 11). |
| **Update** | An outdated version is detected. |
| **Sign in** | No credentials stored yet. |
| **Configure project** | The current directory is not bound to a project. On completion it writes the project files described in section 8.4. Equivalent to `neural-seam connect` on the CLI. |
| **Languages** | Right after configuring the project. Lists the supported languages with checkboxes pre-selected from what was detected in the directory. Your selection is persisted and the matching language servers are installed with progress feedback. See section 9.1. |
| **Done** | Everything is configured. Close the installer and open your agent host in the directory, or use **Open Neural Seam Tray now** to start the tray immediately. |
| **Diagnostics** | Available from any state. Same engine as `neural-seam doctor --fix` and the tray: checks for auth, manifest, language servers, developer tools, agent host, and git, with a **Fix** button per item. |

### 4.2. One-liner (CLI only)

**Linux / macOS:**

```sh
curl -fsSL https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.sh | sh
```

Installs into `~/.local/bin` by default. If that directory is not on your `PATH`, the script prints the exact line to add.

Useful variations:

```sh
# Pin a version (plain SemVer, no prefix):
curl -fsSL .../install.sh | NEURAL_SEAM_VERSION=1.2.3 sh

# Without a pipe, choosing version and directory:
sh install.sh --version 1.2.3 --dir /usr/local/bin

# Change only the install directory:
curl -fsSL .../install.sh | NEURAL_SEAM_INSTALL_DIR=/usr/local/bin sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.ps1 | iex
```

Installs into `%LOCALAPPDATA%\Programs\neural-seam` and adds it to the **user** `PATH` (no elevation, never touches the machine `PATH`). **Open a new terminal** afterwards for the `PATH` change to take effect. To pin a version while using the pipe:

```powershell
$env:NEURAL_SEAM_VERSION = '1.2.3'; irm https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.ps1 | iex
```

### 4.3. First run: Gatekeeper (macOS) and SmartScreen (Windows)

The binary is **not signed yet**, so the operating system may warn about or block the first run. This is expected and does not indicate tampering: integrity was already verified by sha256 during installation.

**macOS (Gatekeeper):** if you see "cannot be opened because the developer cannot be verified", remove the quarantine attribute or use the context menu:

```sh
# Option 1: remove the quarantine attribute from the downloaded binary
xattr -d com.apple.quarantine "$(command -v neural-seam)"

# Option 2: Finder -> right click the binary -> "Open" -> confirm once
```

**Windows (SmartScreen):** if "Windows protected your PC" appears, click **More info**, then **Run anyway**. Installing with `install.ps1` into a user directory reduces friction, but the first run may still ask for confirmation.

### 4.4. Manual download

Download the `neural-seam-<os>-<arch>` asset from the release, verify its sha256 against `checksums.txt` by hand, and place the binary in a directory on your `PATH`. The "Download and install" section of the [releases repository README](https://github.com/NeuralSeam/neural-seam-releases) is the canonical reference.

### 4.5. Confirm the installation

```sh
neural-seam version
```

Prints the SemVer of the installed release.

### 4.6. Verify the download

Every release publishes **`checksums.txt`**, holding the sha256 of each published executable: the
CLI, the installer and the tray. Every install path verifies against it automatically and aborts on a
mismatch or on a missing entry, so the check below is only needed for a manual download.

```powershell
Get-FileHash .
eural-seam-windows-amd64.exe -Algorithm SHA256
```

```sh
sha256sum neural-seam-linux-amd64
```

Compare the result against the matching line of `checksums.txt`. If it does not match, do not run the
binary: download it again, and if the mismatch persists, report it through SECURITY.md.

**What this does and does not prove.** The sha256 check tells you the file is the one published in
that release, and HTTPS tells you it came from GitHub. It is not a publisher identity you can verify
offline: there is no code signature and no signed manifest yet, so `checksums.txt` is served from the
same release as the binary it describes. SECURITY.md states the boundary in full. Do not treat a copy
of the runtime obtained anywhere else as verified.

---

## 5. One-step onboarding: `neural-seam setup`

This is the happy path. From a project directory, run:

```sh
cd /path/to/your/project
neural-seam setup
```

`setup` runs, in order:

1. **Sign-in** (starts the device flow if you do not have valid credentials yet).
2. **Project and language detection** in the current directory, or your explicit selection (see below).
3. **Language server provisioning** for the resolved language set (see section 9).
4. **Project registration and activation** in the local registry, plus the `/ns-guide` entry point command (see section 7.1).
5. **Manifest validation** (signed manifest).
6. A final **"ready"** summary.

Flags:

| Flag | Effect |
|------|--------|
| `--languages go,python,...` | Explicit language selection for language server provisioning (comma separated, case insensitive). Overrides auto-detection and is **persisted** for the project. Empty or omitted means auto-detection (the default). An invalid key aborts with an error listing the valid options. |
| `--set-default-languages` | Also saves `--languages` as your **global default** (`preferences.json`), applied to any project without its own selection. Only meaningful together with `--languages` (error if used alone). |
| `--no-lsp` | Skips language server provisioning. |
| `--yes` | Assumes consent (does not ask before downloading or installing). |

**Choosing languages.** By default `setup` detects the project languages from the files on disk and provisions the matching language servers. You can instead declare the languages explicitly with `--languages`, which is useful when the project is still empty, when you want a language server the current files do not reveal, or when you want to pin the set. The choice is stored in the project registry (`~/.neural-seam/projects.json`, field `languages`) and, with `--set-default-languages`, as a global default. The same selection is available in the graphical installer (section 4.1) and in the tray **Settings** tab (section 11). Resolution order: **project selection** -> **global default** -> **auto-detection**. Supported languages: Go, C#, Python, TypeScript/JavaScript, Rust (see section 9).

```sh
# Declare and persist Go + Python for this project, and pin them as the global default:
neural-seam setup --languages go,python --set-default-languages
```

If you prefer finer control, run each step yourself (`login`, `project register`, and so on; see section 6).

---

## 6. Command reference

```
neural-seam <command>
```

| Command | What it does | Main flags |
|---------|--------------|------------|
| `serve` | Starts the MCP server (stdio) plus the local HTTP bridge. If the current directory contains a manifest, it is used by default (and auto-registered). Otherwise the active project from the registry is used, with a warning on stderr when the resolved project differs from the current directory. | `--project-from-cwd` (force the current directory as the project root) |
| `login` | Authenticates against the backend using the **device flow**. | |
| `logout` | Clears stored credentials. | |
| `doctor` | Diagnoses auth, manifest, bridge, connectivity, language servers, and the environment orchestration entry point. Also reports the active agent host, the hosts detected on the `PATH`, and the ones missing. Errors come with an actionable next step. | `--fix` (remediates auth, language servers, and project registration) |
| `setup` | One-step onboarding (see section 5). | `--languages`, `--set-default-languages`, `--no-lsp`, `--yes` |
| `import` | Imports an existing (brownfield) project into Neural Seam: detects the preset, creates the project, writes the overlay, opens a PR. | `--dir <path>` (default: current directory), `--no-pr` |
| `clone` | Clones the project's code repository, with submodules, into a local directory. **Idempotent:** if the target is already a clone of the same origin it runs `git pull --recurse-submodules`; it refuses with a clear message if the origin differs. Requires `git` on the `PATH`. | `--dir <path>` (default: `<cwd>/<repository_name>`) |
| `connect` | Connects an existing project to a local directory: fetches the signed manifest, writes `.neural-seam/manifest.json` verbatim (preserving the Ed25519 signature), and writes the project files described in section 8.4. **Refuses without writing anything** when the directory already carries a manifest for a different project, an unreadable manifest, or a hand-written harness; `--force` proceeds anyway. It also refuses when the project has a code repository registered and this directory is not a clone of it (see section 6.2). | `--dir <path>` (default: current directory), `--force`, `--host <id>` (see section 6.1) |
| `hook` | Runs an agent host lifecycle hook. **You do not call this by hand**; the host's hook configuration does. | `session-start` \| `pre-tool-use` \| `stop` |
| `project` | Manages the **local project registry** and the maturity stage. | `register` \| `activate` \| `list` \| `advance-stage <stage>` |
| `register` | Registers the runtime in the host's MCP registration file (with Claude Code, `.mcp.json`), as a managed entry. **Different** from `project register`. | `--host <id>` |
| `upgrade` | Self-update to the latest release (verifies sha256, then swaps the binary atomically). | |
| `version` | Prints the version and exits. | |

> **`project register` vs `register` (do not confuse them):**
> - `project register` adds the **current directory** to the runtime's local project registry (state under `~/.neural-seam/`).
> - `register` writes the managed entry in the project's `.mcp.json`, which is what makes your agent host see the `neural-seam-runtime` server.

> **`project advance-stage <stage>`** advances the project maturity stage (`ideacao` < `poc` < `pre_mvp` < `beta` < `mvp` < `pos_mvp`). It is **monotonic**: it only moves forward, never back. Without `--yes` it prints the current and target stage, warns that the change is permanent, and touches nothing. With `--yes` it applies the change; an attempted regression is reported as a conflict.

### 6.1. Choosing the agent host (`--host`)

The runtime writes the harness **for one agent host**. **Claude Code is the default, and it is the host this manual documents.** The binary also carries adapters for other CLIs, selectable with `--host`:

| `--host <id>` | Host | State |
|---------------|------|-------|
| `claude-code` | Claude Code | Default |
| `codex` | OpenAI Codex CLI | Adapter available by explicit choice; **not announced as supported** |
| `antigravity` | Antigravity CLI (`agy`) | Adapter available by explicit choice; **not announced as supported** |

The two non-default adapters work but have not gone through host acceptance, so this manual does not document their behavior and they carry no support commitment.

**How the host is resolved**, in order (first decision wins):

1. `--host <id>` on the invocation;
2. the `host` field in `~/.neural-seam/config.json`;
3. autodetection of a host binary on the `PATH`;
4. the build default.

A new choice is **persisted**, so the next invocation does not ask again. Two situations **refuse instead of guessing**, listing the valid ids: an unknown `--host`, and an **ambiguous** `PATH` (two or more host binaries installed). No host detected is **not** an error: the default applies.

You can also choose the host in the graphical installer (host selection screen) and in the tray **Settings** tab. Both write to the same `config.json` that the CLI reads. Switching in the tray re-materializes the selected project for the new host and removes the previous wiring, so two wirings never stay live at once.

### 6.2. First run: where your code must be before `connect`

`connect` writes the project files **inside** the directory it runs in, and `clone` puts the code in a **subdirectory**. Running both in the same folder, in that order, leaves the manifest in one place and the code in another. Nothing downstream detects that, so follow this order.

**1. `check_setup` tells you when the code is missing.** When you are signed in, there is no local manifest, you have accessible projects, and the folder has no `.git`, `check_setup` returns `needs_clone` with the list of projects, a connect URL, and a message covering both outcomes:

- the project **has** a provisioned repository: run `neural-seam clone <projectId>` and connect **from inside the clone**;
- the project **has no** repository yet: go straight to `neural-seam connect <projectId>` in this folder.

**2. Reopen the session inside the clone.** After `clone`, do **not** continue in the same agent host session. The MCP server resolves the project root from the session's working directory, so a session opened in the parent folder still points there and `connect` writes to the wrong place. Close the session, enter the cloned subdirectory, and open the host there:

```sh
neural-seam clone <projectId>      # creates ./<repository>/
cd <repository>
neural-seam connect <projectId>    # the resolved root is now the clone
```

**3. `connect` guards the root.** It **refuses without writing anything** when the project has a code repository registered and the current directory is not a clone of it (no `.git`, or a different `origin`). The refusal names the expected repository, the origin it found, and the correct path (`clone`, `cd`, `connect`). Deliberate limits:

- it requires evidence: a project **without** a provisioned repository has nothing to compare against and stays connectable in an empty folder;
- it **fails open**: if the lookup does not complete, `connect` proceeds. Only a successful lookup that finds a real mismatch refuses;
- it runs **before** any write, so a refused `connect` leaves no state behind;
- `--force` materializes here anyway.

---

## 7. MCP tools

While the runtime is serving, your agent host sees the tools prefixed with the MCP server name (`mcp__neural-seam-runtime__<name>` in Claude Code). You rarely invoke them by raw name: ask in natural language ("list the activities", "move card X to done") and the agent picks the tool.

### Neural Seam domain

| Tool | What it is for |
|------|----------------|
| `check_setup` | Checks credentials, manifest, and trial, then points at the next step (sign in, create, connect, clone, import). Fired by the `session-start` hook. |
| `list_activities` | Lists the project cards (kanban / activities). |
| `create_activity` | Creates a new activity card. Accepts optional `component_ids` to associate the card with target Components. |
| `update_activity_status` | Moves a card between statuses (for example `todo` -> `in_progress` -> `done`). Failures are reported explicitly, never degraded silently. |
| `move_to_board` | Moves a card to a board column. `board_id` must be one of `discovery`, `development`, `deploy`. |
| `finalize_sprint` | Closes the current sprint and opens a new one, rolling incomplete activities over. |
| `exec_activity` | Prepares the execution context for a card and moves it from backlog to in progress. |
| `next_epic_sub` | **Read-only advisor.** Given an epic, shows the next executable subactivity, the blocked set, and progress. Changes no state. |
| `next_job` | Consumes the next pending agent job (for example generating project inputs). Always started by you. |
| `get_artifact` | Fetches the content of a harness artifact (skill, subagent, rule) on demand. |
| `load_context` | Loads the project base context. |
| `save_insumos` | Persists generated project inputs (spec, discovery, backlog) back to the project. |
| `save_harness_artifacts` | Writes back the product artifacts your agent authored, from a fixed set of names. In imported (brownfield) projects it requires an explicit `approved: true`. |
| `analyze_existing_project` | **Imported (brownfield) projects only.** Builds an analysis prompt from the project fingerprint, `README.md`, and directory tree so you can generate the discovery backlog. |
| `list_project_gaps` | **Read-only advisor.** Lists the interview questions the project has not answered yet, with label, hint, phase, and the artifacts that answering would unlock, ordered by impact. |
| `suggest_interview_answers` | Records proposed answers (`question_id`, `value`, `evidence`) without answering anything. `evidence` is required and must not be empty. |
| `answer_project_gap` | Writes your confirmed answers for one or more gaps. Answers merge by key; previously unlocked artifacts are never removed. |
| `update_living_doc` | Updates a project living document. |
| `get_branch_strategy`, `get_branch_instructions` | **Advisory.** The project's branch strategy and the operational instructions derived from it. |
| `execute_branch_commit` | Creates or reuses the shared feature branch defined by the project's branch strategy, commits with the strategy's prefix, and pushes to `origin`. Git errors are typed and reported explicitly. |
| `check_advance_gate` | Confirms that the card's commit reached the feature branch and, when the feature is complete, that it was incorporated into the target base, before the next card is released. |

Git operations touch your source control provider's remote only, never Anthropic.

### Local project registry

`activate_project`, `remove_project`, `list_queryable_projects`, `query_project`, `open_dashboard`.

### Semantic code tools (language servers)

`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, `safe_delete_symbol`, `restart_language_server`, `find_implementations`, `find_declaration`, `get_diagnostics_for_file`.

These require a provisioned language server for the language (see section 9). Without one they return `lsp_unavailable` with a hint instead of an empty result: "there are no results" and "this server cannot answer" must not collide.

Notable behavior:

- **Write tools refuse instead of guessing.** When a symbol's span cannot be resolved, `replace_symbol_body` and `insert_after_symbol` refuse and point at the text-anchor alternative. Refusing costs one turn; writing against a wrong span costs a corrupted file.
- **C# caveat:** the span of a documented symbol starts at the XML doc comment, not at the declaration. Include the doc comment in the replacement body, or edit by text anchor with `replace_content`.
- **Reference fidelity.** `find_referencing_symbols` uses real language server references where the server supports it and marks the result `"confidence": "high"`. Otherwise it falls back to a textual match and marks `"confidence": "low"`. `rename_symbol` and `safe_delete_symbol` **refuse** to act on low-confidence results rather than rewriting code from an unreliable signal.

### Files and search

`read_file`, `create_text_file`, `list_dir`, `find_file`, `search_for_pattern`, `replace_content`, `insert_at_line`, `delete_lines`, `replace_lines`, `replace_in_files`.

`replace_in_files` applies a textual replacement across every file a glob selects. It is **deliberately textual**, for what no language server sees: a string inside a comment, a literal in a config file, an i18n key. To rename a **symbol**, use `rename_symbol`. It preserves line endings per file, offers a preview mode that writes no bytes, writes atomically, preserves file mode, and skips binary files.

### Project memory

`write_memory`, `read_memory`, `list_memories`, `edit_memory`, `rename_memory`, `delete_memory`.

### Environment orchestration

`aspire_up`, `aspire_down`, `aspire_status` start, stop, and inspect the project's Components through the generated app host. Requires Docker and the provisioned Aspire CLI (`neural-seam setup` or `neural-seam doctor --fix` download the CLI and Node into `~/.neural-seam/bin/`). With more than one app host in the repository, detection **refuses** and lists the candidates: choose one by writing `{"apphost_path": "<path relative to the root>"}` into `.neural-seam/apphost.json`. Every lifecycle action is started by you.

### 7.1. Command surface (`/ns-*`)

The full `/ns-*` command surface lives in the **`neural-seam-claude`** plugin (11 commands). The runtime writes a single local command into your project, **`/ns-guide`**, which is a static pointer: it explains that the `neural-seam-runtime` MCP server is already registered and works without the plugin, and how to install the plugin to get the command surface.

Install the plugin once, globally, from inside Claude Code. Two commands, **in this order** (the second alone fails on a machine that never registered the marketplace):

```
/plugin marketplace add NeuralSeam/neural-seam-claude
/plugin install neural-seam@neural-seam
```

Command surface (`/neural-seam:ns-*`): onboarding (`ns-status`, `ns-start`, `ns-create`, `ns-connect`, `ns-clone`, `ns-doctor`) and the work loop (`ns-generate`, `ns-list`, `ns-open`, `ns-exec`, `ns-help`). Start with `/neural-seam:ns-start`, which is guided.

Installing the plugin does **not** replace `neural-seam login` or `neural-seam connect`: sign-in, the signed manifest, and project binding are product state that only the runtime handles. If the plugin is missing, `connect` and `doctor` tell you how to install it and never block.

---

## 8. Configuration

### 8.1. Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `NEURAL_SEAM_HOME` | `<user home>/.neural-seam` | Base directory for local runtime state (credentials, language servers, project registry). |
| `NEURAL_SEAM_PLUGIN_HINT` | (unset) | Set to `off` (or `0`, `false`, `no`) to **condense** the "plugin not installed" guidance to a single line. It does not silence it: the condensed line still names the plugin, the reference, and the commands. |

> Released binaries always talk to the production Neural Seam backend. Backend and web app URL overrides, whether from environment variables or from `config.json`, are **ignored** in released builds; an override that is present is logged as a warning and discarded. `NEURAL_SEAM_HOME`, telemetry, and TLS pin settings are not affected.

### 8.2. `config.json`

Persisted settings live in `~/.neural-seam/config.json`:

```json
{
  "host": "claude-code"
}
```

The **`host`** field is the selected agent host (see section 6.1); valid ids are `claude-code`, `codex`, and `antigravity`. You normally do not write it by hand: `connect --host`, the installer, and the tray write it, and every later invocation reads the choice from there. Absent or unknown, resolution falls through to autodetection and then to the default.

A malformed `config.json` falls back to defaults with a warning; it never aborts. The file is read locally and is never fetched from a remote URL.

### 8.3. Layout of `~/.neural-seam/`

```
~/.neural-seam/                 # state root (NEURAL_SEAM_HOME), mode 0700 on POSIX
  credentials                   # JWT tokens (access + refresh), 0600 / owner-only ACL
  projects.json                 # local project registry ({Name, Root, languages?})
  preferences.json              # global developer preferences (default_languages)
  servers/                      # language servers provisioned by the runtime
  bin/                          # developer tools provisioned by the runtime
```

- **`credentials`** holds the device flow tokens. **On Windows**, by default, tokens live in the system **Credential Manager** (per-user encryption via DPAPI, target `NeuralSeam:runtime`) and **no plaintext token is written to disk**; the `credentials` file is only a fallback when the vault is unavailable. On other platforms, and whenever `NEURAL_SEAM_HOME` is set, tokens live in the `credentials` file with owner-only permissions (`0600` on POSIX, ACL on Windows). Never commit a credential or copy it to another machine.
  - **Transparent migration:** on the first run with the vault available, an existing `credentials` file is imported into the vault and the plaintext file is removed, without asking you to sign in again.
  - **`logout`** (CLI or tray) removes the credential from **both** stores.
- **`projects.json`** is the local project registry. Each project stores `{Name, Root}` and, optionally, `languages` (the explicit per-project language selection; absent means auto-detection). Written with `0600`.
- **`preferences.json`** holds global developer preferences, today only `default_languages` (see section 9.1). Absent or empty means no default.
- **`servers/`** holds the language servers the runtime downloads or installs, isolated from the system.

### 8.4. Files added to your repository

Connecting a project writes a small set of files into your project directory. They are tracked by **your** Git, so review them in your first commit.

| Path | What it is | What to do with it |
|------|------------|--------------------|
| `.neural-seam/manifest.json` | The signed project manifest (Ed25519). | Commit it. Do not edit it by hand: the signature will no longer verify. |
| `CLAUDE.md` | Project memory for the agent. The runtime owns a managed block delimited by comment markers. | Edit freely **outside** the markers. Content outside them is never touched. |
| `.claude/settings.json` | The lifecycle hooks (section 10), pointing at the `neural-seam` binary. | Leave the managed entries alone. Your own entries are preserved. |
| `.mcp.json` | The managed `neural-seam-runtime` entry that lets the host find the MCP server. | Commit it so teammates get the same wiring. Written by `neural-seam register`. |
| `.claude/agents/`, `.claude/commands/` | Subagent and command stubs derived from your project manifest. | Treat as generated. A file of yours with the same name is preserved, not overwritten. |
| `.claude/commands/ns-guide.md` | The `/ns-guide` entry point (section 7.1). | Nothing. It is refreshed as the runtime evolves. |
| `.claude/skills/` | The **index** of your project's coding conventions. | Read it; do not look for the convention bodies on disk. They are served on demand while the runtime is running. |
| `apphost.mts` | Entry point for environment orchestration. | Relevant only if you use `aspire_up` and friends. |

Practical notes:

- Writing is **idempotent and non-destructive**. Re-running `connect` on a directory that already holds the same project verifies and refreshes instead of failing.
- `connect` **refuses without writing anything** (unless you pass `--force`) when the directory holds a manifest for a **different** project, an unreadable manifest, a `CLAUDE.md` without the managed block, or a hand-written harness occupying the stub directories.
- Stubs that the manifest no longer declares are removed as managed orphans on the next `setup` or `register`. Files you created with the same name are preserved.
- Without network access, the convention index stays on disk but the convention bodies cannot be opened. Run `neural-seam doctor` to check connectivity.

---

## 9. Language servers

The runtime provisions missing language servers into `~/.neural-seam/servers/`, so you do not have to install everything by hand. Resolution order per server: **(a)** download a prebuilt binary when one exists; **(b)** otherwise install through a detected toolchain into a managed prefix, without polluting the system; **(c)** otherwise use whatever is on the `PATH`; **(d)** otherwise fail with a clear, actionable error.

"Zero toolchain" does not hold for every language. Per-server strategy:

| Server | Managed strategy | Base toolchain still required? |
|--------|------------------|--------------------------------|
| `rust-analyzer` | Prebuilt binary plus checksum | No |
| `gopls` | `go install` into a managed prefix | Go |
| `pyright` | Managed npm/pip prefix | Node (or Python) |
| `typescript-language-server` | Managed npm prefix | Node |
| `csharp-ls` | `dotnet tool` into a managed tool path | .NET SDK |

Run `neural-seam doctor` to see, per project language, what is present or missing, the version (best effort), and the install hint. `neural-seam doctor --fix` (or `setup`) provisions what is missing. To skip the step, use `setup --no-lsp`.

### 9.1. Choosing which languages are provisioned

By default the language set is **detected automatically** from the project files. You can also **choose explicitly**, and the runtime then provisions exactly that set even if the current files do not reveal it. Three surfaces write the same state:

- **CLI:** `neural-seam setup --languages go,python` (and `--set-default-languages` for the global default), see section 5.
- **Graphical installer:** the **Languages** step, with checkboxes pre-selected from what was detected, see section 4.1.
- **Tray:** the **Settings** tab (check, uncheck, install on demand), see section 11.

Supported languages:

| Key | Label | Server |
|-----|-------|--------|
| `Go` | Go | `gopls` |
| `C#` | C# | `csharp-ls` |
| `Python` | Python | `pyright` |
| `TypeScript` | TypeScript / JavaScript | `typescript-language-server` |
| `Rust` | Rust | `rust-analyzer` |

**Resolution order:** project selection (`projects.json` -> `languages`) -> global default (`preferences.json` -> `default_languages`) -> auto-detection. With no selection saved, behavior is 100% automatic. Installation is always started by you and runs locally: no token leaves the runtime, and no telemetry is emitted.

---

## 10. Lifecycle hooks

The runtime writes agent host lifecycle hooks into your project's `.claude/settings.json`. They point at the `neural-seam` binary itself, with no other dependency:

| Hook | When it fires |
|------|---------------|
| `session-start` | At the start of a host session (checks setup, lists pending jobs). |
| `pre-tool-use` | Before a tool call. |
| `stop` | When the session ends. |

These are session and verification hooks only. No telemetry hook is enabled by default. Writing the block is idempotent and preserves entries you already had in `settings.json`.

If `check_setup` reports missing hooks, run `neural-seam connect <projectId>` in the project directory. That is the command that rewrites them on disk.

---

## 11. System tray (Windows)

`neural-seam-tray` is a separate binary that adds a high-frequency visual interface in the Windows notification area. It runs as a **system singleton** (a single process, even with several `serve` sessions open) and survives closing your agent host.

### What the tray shows

| Element | What it is |
|---------|------------|
| Agent job queue | Pending jobs in the backend, copyable to the clipboard |
| "live" badge | Projects with an active local `serve` session |
| Compact kanban | Cards of the selected project |
| Sprint meter | Current sprint plus progress |
| Trial badge | Plan or trial status |
| Project switcher | Projects registered locally (`~/.neural-seam/projects.json`) |

The popover has five tabs: **Jobs**, **Kanban**, **Backlog**, **Diagnostics**, and **Settings**.

### Settings tab (agent host and languages)

The **agent host** sits at the top: it shows the active host and lets you switch. Switching re-materializes the selected project for the new host and removes the previous wiring, so two wirings never stay live. With no project selected, switching only persists the choice, which applies on the next `connect` or `setup`. See section 6.1.

Below it, the language settings, the same control as the graphical installer, available at any time:

- Lists the supported languages with **checkboxes** reflecting the active project's selection, and a per-language status (installed or missing).
- Saving **persists** the selection for the active project (and in your global default), exactly like `neural-seam setup --languages`.
- The install button provisions the missing language servers, reusing the same engine as the **Diagnostics** tab.

Installation is a local operation on a managed binary, started by you. No token crosses into the UI layer; only the catalog, the selection, and install status do. No telemetry by default, and the tray uses its own branding rather than imitating any official client.

### Project identity

The switcher is populated from the **local registry** (`~/.neural-seam/projects.json`), which stores only `{Name, Root}`. The project id sent to the backend is **derived from the manifest** (`.neural-seam/manifest.json`), exactly like `serve`. Without a manifest, the project shows as **"not ready"** in the switcher and API operations (kanban, jobs, sprint) return a clear error instead of sending a folder name to the backend.

> To materialize the manifest: open your agent host in the project directory (the `session-start` hook calls `check_setup` automatically) or run `neural-seam serve` once in the folder.

### "live" badge and job queue

- The **"live"** badge appears for projects with an active `neural-seam serve` session. It does **not** require the tray: any `serve` session is enough. If you started your agent host in the project and it answered `check_setup: ok`, the badge should appear within about 15 seconds.
- The **job queue** shows pending agent jobs from the backend. It does **not** require an active `serve` session: the tray talks to the backend directly. Jobs only appear when there are pending actions.

### First-run states

| State | What the tray shows | Suggested action |
|-------|---------------------|------------------|
| **Not signed in** | Welcome screen with a sign-in call to action, plus "waiting for device flow" feedback | Sign in through the browser; the tray detects completion |
| **Signed in, no project** | Empty state with a registration call to action | `neural-seam project register`, or open the web app to create a project |
| **No active runtime** | "No active runtime": the runtime runs alongside your agent host and none was discovered. This is the normal state when the tray starts (for example via autostart) with no host open | Open your agent host in the project; the tray connects automatically within about 15 seconds |
| **Runtime active, project not connected** | Amber badge ("Select a project"): a runtime is alive but the selected project does not match it | Select (or register) the project whose directory has an active session |
| **Connected** | Green badge ("Runtime active") | None, it is operational |

Connection state is presentation only: it does not change the discovery cadence, it stays read-only, and it emits no telemetry.

### Opening the dashboard

The web app only talks to the local runtime when it is opened in **plugin mode**, which is activated exclusively by the pair of query parameters `?mode=plugin&bridge=http://localhost:<port>`. Opened without them, the web app stays in **web mode**: it does not probe the bridge and the connection indicator never lights up, even with the runtime running.

That is why the tray's **Open Dashboard** resolves the destination before opening the browser:

| Situation | What the tray opens |
|-----------|---------------------|
| The selected project has a live runtime | The dashboard in plugin mode, connected to that runtime |
| No project selected and exactly one live runtime | Plugin mode against that runtime (unambiguous) |
| No live runtime | The plain web app (web mode) |
| A live runtime for a **different** project, or several with no selection | The plain web app (ambiguous; connecting to the wrong one would be worse than not connecting) |

The `bridge` parameter host is always `localhost`, never `127.0.0.1`: that is the only form the web app accepts, and a loopback IP would be discarded silently, leaving the web app in web mode.

> Tray **sign-in** deliberately opens the login page in web mode: that page authenticates against the backend and does not talk to the local runtime.

### Installation and autostart

The graphical installer (Windows) installs the tray alongside the CLI:

- `neural-seam-tray.exe` is copied into `%LOCALAPPDATA%\Programs\neural-seam\` next to the CLI.
- A **Start Menu** shortcut provisions the AppUserModelID (`NeuralSeam.Tray`), which is required for reliable WinRT toasts.
- **Autostart is opt-in:** the checkbox "Start Neural Seam Tray when the computer starts" is **unchecked** by default, and the `NeuralSeamTray` entry under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` is only written when you check it. Copying the binary, the AppUserModelID, and the Start Menu shortcut happen regardless.
- Installation is idempotent: reinstalling does not duplicate entries or shortcuts.

The **Done** screen offers **Open Neural Seam Tray now**, which starts the tray immediately. If the tray is already running, the action is a silent no-op.

To start the tray manually:

```powershell
neural-seam tray   # launcher subcommand (detached spawn)
```

Or run `neural-seam-tray.exe` directly.

### Signing in from the tray

The tray is self-sufficient for authentication: you do not need a terminal to sign in, switch accounts, or sign out.

**Sign in.** When the tray detects missing or expired credentials it shows the embedded device flow (RFC 8628): it displays a user code, **Open in browser** takes you to the verification page, you approve the code, and the tray detects the approval and moves to the signed-in state. The account badge then shows the e-mail decoded locally from the token, with no extra network call.

**Switch account.** Use **Switch account** in the tray menu or the header badge: current credentials are removed and the device flow restarts. The account that approves the new code becomes the active one.

**Sign out.** Use **Sign out** in the tray menu or the header. The tray removes the local credentials and returns to the signed-out state.

> **Session separation is a feature.** The account active in the tray is the one that approved the device flow, not the tab open in your browser. You can be signed in as account A in the browser and account B in the tray, which is intentional (for example personal and corporate accounts).

**Headless alternative (CI, or a developer without a GUI):**

```sh
neural-seam login   # device flow in the terminal
neural-seam logout  # clears credentials
```

### Toasts

The tray emits WinRT toasts for new agent jobs, a trial expiring within 3 days, and sign-in required. Clicking a toast opens the tray window or copies the prompt. It never consumes a job automatically.

> **Toasts without an AppUserModelID:** running `neural-seam-tray.exe` without having installed through the graphical installer (no Start Menu shortcut) falls back to win32 balloon notifications. That is expected in a development setup.

The tray is a **read and copy** interface. No code path in the tray invokes your agent host, consumes jobs, or injects input into any process. You always decide when to act.

### Access revocation (local collapse)

If an administrator **revokes** your Neural Seam access, the local runtime removes itself from the machine. This is client-side license enforcement, decided locally; the backend never deletes anything remotely.

- **What is removed:** the binaries (`neural-seam`, `neural-seam-tray`), the language servers and developer tools the runtime provisioned (`~/.neural-seam/servers/` and `bin/`), credentials and operational state, and the tray registration (autostart, shortcut, AppUserModelID). The tray detects revocation on its poll (up to about 5 minutes) and triggers the cleanup.
- **What is never touched:** your repositories and code, the `.neural-seam/manifest.json` files inside them, and your agent host's own configuration. The collapse removes the Neural Seam installation only.
- **How to recover:** an administrator restores access; after that, open the app and sign in again (device flow). The surviving installer re-downloads the binaries, re-registers the tray, and re-provisions the language servers. If sign-in still fails because the account is revoked, nothing is reinstalled. There is no silent background reinstall: recovery happens on your next attempt to sign in.
- **Diagnostics:** a local JSON-lines log, `collapse-audit.jsonl`, in the install directory (it survives the cleanup) records the event. Nothing is sent over the network.

The collapse is Windows-first, because the tray, autostart, and registration are Windows features.

---

## 12. Updating

```sh
neural-seam upgrade
```

Looks up the latest release, downloads the asset for your OS and architecture, verifies its sha256 against `checksums.txt`, and performs an **atomic swap** of the running binary. It never updates silently or on a remote event: running the command is always your action.

On Windows, the graphical installer also offers an update button, without opening a terminal.

---

## 13. End-to-end walkthrough

The full product flow, from a bare binary to implementing features. **Project creation happens in the web app** (the wizard is the source of truth); the runtime handles local state and writes the files.

1. **Install and onboard.** `neural-seam setup` (sign-in, language servers, registration) and `neural-seam register` (the `.mcp.json` entry). See section 2.
2. **Open your agent host** in the directory. The `session-start` hook runs `check_setup`. Without a manifest it starts the local bridge and points you at the web app, or at connecting an existing project.
3. **Create the project in the web app.** Fill in the wizard (name, Components, stack, interview, branching and CI, design). On completion the web app calls the local bridge, which forwards to the backend.
4. **Files are written automatically.** The backend returns the signed manifest plus the actions; the runtime writes the manifest, the `CLAUDE.md` block, hooks, `.claude/` stubs, and the `.mcp.json` entry (see section 8.4). The backend also queues a bootstrap job carrying the generated harness.
5. **Back to the terminal.** The next `session-start` finds a valid manifest and `check_setup` returns `ok`.
6. **Generate project inputs and cards.** Consume the pending job with `next_job`: your agent generates spec, discovery, and backlog, persisted with `save_insumos`. Then call `derive_dev_cards` to derive the initial activities, and the kanban fills with the expected cards.
7. **Implement features (the loop).** For each feature:
   - `list_activities` to pick a card;
   - `update_activity_status` to move it to `in_progress`;
   - `get_artifact` to pull the relevant skill, subagent, or rule from the harness;
   - your agent implements the code (using the semantic and file tools);
   - `update_activity_status` to `done` when finished.
8. **Repeat.** The dashboard kanban reflects progress.

> **Joining an existing project.** An invited collaborator does not create a project. `check_setup` detects `needs_connect`, lists the accessible projects, and materializes the manifest (verifying the Ed25519 signature) in the local directory. The activities already exist in the backend.

> **Before connecting, the code must be here.** In a folder without `.git`, `check_setup` returns `needs_clone` instead of `needs_connect`: clone the project repository and **reopen the session inside the clone** before connecting. See section 6.2.

---

## 14. Diagnostics and troubleshooting

Always start with **`neural-seam doctor`**. It covers auth, manifest, bridge, connectivity, and language servers. To attempt automatic remediation, run **`neural-seam doctor --fix`**.

| Symptom | Likely cause | What to do |
|---------|--------------|------------|
| `neural-seam: command not found` | Install directory not on the `PATH` | Follow the `PATH` guidance printed by the installer, then reopen the terminal. |
| `doctor` reports `agent-host` not found | No agent host binary detected on the `PATH` | Install the host from its official site. The runtime never installs the host. If the host is installed but outside the `PATH`, select it explicitly with `--host <id>`, which does not depend on detection. |
| `doctor` or `connect` refuses and asks you to choose a host | Two or more host binaries on the `PATH`, so autodetection is **ambiguous** | Run once with `--host <id>`; the choice is persisted (see section 6.1). |
| `aspire_up` / `aspire_status` report that the engine is not configured | One of three causes: the Aspire CLI is missing, no app host was detected, or no project is active in this directory | The response names the cause and the step. For the full picture run `neural-seam doctor`: `tools[aspire]` covers the CLI binary and `aspire-apphost` covers app host detection. |
| `connect` refuses, saying this directory is not a clone of the project repository | The project has a code repository registered and this folder is not a clone of it (no `.git`, or a different `origin`) | Nothing was written. Run `neural-seam clone <projectId>`, `cd` into the clone, and connect from there (see section 6.2). To materialize here anyway, use `--force`. |
| `check_setup` returns `needs_clone` | You have accessible projects, but this folder is not the repository of any of them | Clone and connect from inside the clone. If the project has no repository provisioned yet, go straight to `connect` here. |
| Manifest ended up in the parent folder and the code in a subfolder | `connect` ran before `clone`, or after it without reopening the session in the subfolder | Reopen the session inside the clone and run `neural-seam connect <projectId>` there; remove the `.neural-seam/` created by mistake in the parent folder. |
| `doctor` reports `git` not found | `git` missing from the `PATH` | Install Git from https://git-scm.com. Required for `neural-seam clone`. |
| macOS or Windows blocks the first run | Unsigned binary | See section 4.3. |
| Graphical installer blocked by SmartScreen | Unsigned installer | Click **More info**, then **Run anyway**. |
| A semantic tool returns `lsp_unavailable` | Language server missing | `neural-seam doctor` for the hint; `doctor --fix` or `setup` to provision it. |
| Session reports `needs_login` | Credentials missing or expired | `neural-seam login`. |
| `doctor` reports that this runtime session was replaced by a newer sign-in | A newer sign-in for the same account took this session slot, and this machine's tokens were revoked as superseded | If it was you, run `neural-seam login` to reconnect this machine. If it was not, review the account's active sessions and change the password. The runtime never re-authenticates on its own. |
| `neural-seam login` keeps polling after you approved it in the browser | The account already had an active runtime session, so approval opened a possession challenge; the backend only issues the new session after the challenge code | Complete the challenge where it was opened (the dashboard screen, or the "this was me" link in the e-mail). An account with TOTP enabled uses the authenticator code instead of waiting for e-mail. Once approved, the running poll receives the tokens and sign-in completes on its own: do not interrupt it and do not run `login` again, which would open another device code. |
| `Session expired and refresh failed` right after a successful sign-in | Several Neural Seam processes refreshed the token at the same time | Token refresh is serialized within and across processes. If it reappears, look for the `refresh lock unavailable` warning in the log, which means the lock could not be acquired. Resolve with `neural-seam login`. |
| Checksum mismatch during installation | Corrupted or tampered download | The installer aborts without installing anything. Retry, and check your network. |
| Tray: project shows "not ready" | `.neural-seam/manifest.json` missing in the project directory | Open your agent host in the project (the `session-start` hook materializes the manifest) or run `neural-seam serve` once. |
| Tray: kanban, sprint, or jobs stay empty | The project id could not be derived from the manifest | Check that the manifest exists and is valid (`neural-seam doctor`), then restart the tray. |
| Tray: "live" badge does not appear | No active `serve` session | Open your agent host in the project; the badge appears within about 15 seconds. |
| Tray: toasts do not appear (Windows) | AppUserModelID not provisioned (tray running without the Start Menu shortcut) | Install through the graphical installer. Without it, the win32 balloon fallback is expected. |

Offline behavior: every network path reports a clear error rather than a stack trace. The harness artifact cache lives in memory for the lifetime of the `serve` process and serves stale content within the session when the backend is unreachable.

---

## 15. FAQ

**Does the runtime phone home or collect telemetry?**
Not by default. Telemetry is opt-in with a zero default. The runtime talks to the Neural Seam backend for authentication and project data, and the local bridge listens on loopback only.

**Does it work offline?**
Partially. Tools that touch the network return a clear error, and the artifact cache serves stale content within the session. The semantic code, file, and memory tools are local and keep working.

**Do I need the web app for everything?**
To **create or connect** a project, yes: the wizard is the source of truth and the signed manifest comes from the backend. After that, daily tool use happens in the terminal with no browser open.

**Where are my tokens? Can I copy them to another machine?**
On Windows, by default, in the system Credential Manager (per-user encryption, no plaintext on disk). On other platforms, or with a custom `NEURAL_SEAM_HOME`, in `~/.neural-seam/credentials` with owner-only permissions. See section 8.3. Do not copy or commit them: run `neural-seam login` on each machine.

**Does the runtime replace or imitate my agent host?**
No. It is an explicit extension (`neural-seam-runtime`) that serves tools over MCP and runs no inference.

**Does the runtime cost anything in inference?**
No. Every model call comes from your agent host. The runtime never calls a model.

---

## 16. Security and privacy

- **Credentials** live in the OS vault when available (Windows Credential Manager via DPAPI, no plaintext on disk) or, as a fallback, in `~/.neural-seam/credentials` with owner-only permissions (`0600` or ACL). See section 8.3. Do not commit or share them.
- **Download integrity:** sha256 verification is mandatory on both install and upgrade. **Publisher code signing and TLS pinning are not in place yet**, so the guarantee today is sha256 plus HTTPS.
- **Signed manifest:** `manifest.json` is validated by its **Ed25519** signature against the public key embedded in the binary before any local write in connection flows.
- **Telemetry:** opt-in, zero by default. The runtime exports nothing off your machine by default.
- **Loopback only:** the local bridge listens on `127.0.0.1` / `localhost` and is never exposed to the network.
- **Device label at sign-in:** `neural-seam login` sends the machine's **host name** and operating system (`windows`, `darwin`, `linux`), and nothing else. They let the possession notice identify which machine is trying to sign in when the account already has an active session. There is no machine fingerprint; if the host name is unavailable, the field is omitted.

---

## 17. Uninstalling

There is no uninstall command yet. Removal is manual, in three steps:

1. **Remove the binary** from the install directory: `~/.local/bin/neural-seam`, `/usr/local/bin/neural-seam`, or `%LOCALAPPDATA%\Programs\neural-seam` (which also holds `neural-seam-tray.exe` on Windows).
2. **Delete the local state**: `~/.neural-seam/`. This removes credentials, the project registry, and the language servers and tools the runtime provisioned.
3. **Remove the managed entries from your projects**: the `neural-seam-runtime` entry in `.mcp.json`, the managed block between the comment markers in `CLAUDE.md`, the Neural Seam hooks in `.claude/settings.json`, and, if you no longer want them tracked, `.neural-seam/` and the generated stubs under `.claude/`.

On Windows, if you enabled autostart, also delete the `NeuralSeamTray` value under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` and the Start Menu shortcut.

---

## 18. Where to get help

- `neural-seam` with no arguments prints the command summary.
- `neural-seam doctor` is the starting point for any problem, and `neural-seam doctor --fix` remediates
  what it can.
- Releases, downloads and checksums: <https://github.com/NeuralSeam/neural-seam-releases/releases>.

Where a given question goes:

| What you have | Where it goes |
| --- | --- |
| A bug in the runtime, the installer, the tray or the install scripts | An issue on the releases repository. SUPPORT.md says what to include |
| A security vulnerability | SECURITY.md. Report it privately, never as a public issue |
| A question about your account, plan, projects or data | The support form at <https://app.neuralseam.cloud> |
| A question about what is sent and what stays local | PRIVACY.md |
| A question about what you may do with the binaries | LICENSE.md |
| A problem in your agent host itself | That host vendor's own channels |
