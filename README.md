# Neural Seam Client Runtime

Public distribution point for the **Neural Seam Client Runtime** (`neural-seam`), the single Go binary
that runs on your workstation and connects your local project to Neural Seam. The source code lives in
a private repository; this one hosts the published binaries, their checksums, and the install scripts.

[Português](./README.pt-BR.md) · [User Manual](./USER-MANUAL.md) · [Security](./SECURITY.md) ·
[Privacy](./PRIVACY.md) · [Support](./SUPPORT.md) · [License](./LICENSE.md)

## What it is

The runtime runs **no inference of its own**. It is an MCP server, spoken over stdio, that exposes
tools to your agent host, plus a small loopback HTTP bridge used during project setup.

What it gives your agent: your project's activities and cards, the harness artifacts your project
declares, semantic code navigation backed by real language servers, and the lifecycle commands that
keep the two sides in step.

Every model call originates from an action of yours, in your own agent host. The binary never
authenticates to a model provider and holds no model provider credentials.

## Requirements

| | |
| --- | --- |
| Operating system | Windows 10 or 11, x64. See "Platform coverage" below |
| Account | A Neural Seam account. Sign in with `neural-seam login` |
| Agent host | An MCP-capable agent host, which consumes the runtime's tools over stdio |
| Network | Outbound HTTPS to the Neural Seam backend and to GitHub, for install and update |

Language servers are provisioned by the runtime itself where possible, so you do not need to install
them by hand. The manual lists which languages still need a toolchain present.

**Platform coverage.** The pilot publishes **windows/amd64**. The install scripts detect your platform
and fail with a clear message on anything else, rather than downloading something that will not run.
Linux and macOS builds are planned.

## Install

Two paths, two roles. Pick by how you work.

### End users on Windows: the graphical installer

Download **`neural-seam-installer-windows-amd64-setup.exe`** from the
[latest release](https://github.com/NeuralSeam/neural-seam-releases/releases/latest) and run it.

It installs the CLI, sets up the system tray and autostart, and walks you through onboarding: signing
in, connecting a project, and provisioning language servers. This is the recommended path if you are
not going to live in a terminal.

On first run Windows will warn about an unknown publisher. That is expected today and
[SECURITY.md](./SECURITY.md) explains exactly why and what the warning does and does not tell you.

### Developers, CI, headless: the one-liner

Windows, PowerShell:

    irm https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.ps1 | iex

Linux and macOS:

    curl -fsSL https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.sh | sh

The script detects your OS and architecture, downloads the matching release asset, **verifies its
SHA-256 against the release's `checksums.txt` and aborts on mismatch**, and places `neural-seam` on a
per-user location in your `PATH`.

It installs the CLI only: no tray, no autostart, no desktop integration.

### Manual download

From the [latest release](https://github.com/NeuralSeam/neural-seam-releases/releases/latest),
download `neural-seam-windows-amd64.exe`, verify its hash against `checksums.txt`, rename it to
`neural-seam.exe`, and put it on your `PATH`.

## First steps

```sh
neural-seam version          # confirm the install
neural-seam setup            # sign in, provision language servers, connect this directory
neural-seam doctor           # diagnose anything that did not come up
```

Run `neural-seam setup` from your project's directory. It is the one-step onboarding: it signs you in
through a device flow, provisions the language servers your project needs, registers the project and
validates its signed manifest.

Then open your agent host in that directory. The [User Manual](./USER-MANUAL.md) covers registering
the runtime with your host, what the tools do, and how to configure the rest.

## Update

    neural-seam upgrade

A developer-initiated self-update: it fetches the latest published release, verifies the checksum, and
replaces the binary in place. There is no daemon and no timer. Nothing updates unless you ask it to.

## Verify what you downloaded

Every install path verifies the asset's SHA-256 against the `checksums.txt` published with the
release. To check by hand:

```powershell
Get-FileHash .\neural-seam-windows-amd64.exe -Algorithm SHA256
```

```sh
sha256sum neural-seam-linux-amd64
```

and compare against the matching line in the release's `checksums.txt`.

**Publisher code signing is not yet in place.** Until it is, the SHA-256 check plus HTTPS from GitHub
is the integrity guarantee, and [SECURITY.md](./SECURITY.md) states plainly what that does and does
not cover.

## Uninstall

1. Remove the binary from where it was installed.
2. Optionally delete `~/.neural-seam/`, which holds your credentials, the local project registry and
   the provisioned language servers.
3. Optionally remove the managed entries the runtime added to your projects.

The manual lists the exact paths per platform. If you installed with the graphical installer on
Windows, use the usual Windows uninstall entry instead of step 1.

## Privacy, security, support

- [PRIVACY.md](./PRIVACY.md): what is sent, when, and what never leaves your machine. Telemetry is off
  by default and opt-in.
- [SECURITY.md](./SECURITY.md): how to report a vulnerability, and an honest account of the integrity
  chain.
- [SUPPORT.md](./SUPPORT.md): where a question goes, and what to include.

## License

The Neural Seam Client Runtime is **proprietary software**, not open source. See
[LICENSE.md](./LICENSE.md) for what you may and may not do with the binaries published here, and
[THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for the open-source components built into them,
each of which keeps its own license.

The Neural Seam plugins for agent hosts are separate projects and are open source under MIT. The
license of those plugins does not extend to this software.
