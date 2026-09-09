# Support

## Before opening anything

Most problems are one of four things, and this order resolves them fastest:

1. `neural-seam version` answers, so the binary is on your `PATH`.
2. `neural-seam doctor` runs. It is the starting point for every problem and it names the next step.
3. Your agent host sees the MCP server. In a host that lists MCP servers, `neural-seam-runtime`
   should be connected.
4. You are signed in: `neural-seam login`.

The [User Manual](./USER-MANUAL.md) has a troubleshooting section covering the common cases,
including the Windows SmartScreen warning on first run.

## Where to go

| What you have | Where it goes |
| --- | --- |
| A bug in the runtime, the installer or the tray | [Open an issue](https://github.com/NeuralSeam/neural-seam-releases/issues) on this repository |
| A problem with `install.ps1` or `install.sh` | Same: an issue on this repository |
| A security vulnerability | [SECURITY.md](./SECURITY.md). **Not** a public issue |
| A question about your account, plan, projects or data | The support form at <https://app.neuralseam.cloud> |
| A billing question | The support form at <https://app.neuralseam.cloud> |
| A problem in your agent host itself | That host vendor's own channels |

Issues on this repository are read by the maintainers. They are not an account support channel, and
they are public: do not paste tokens, project identifiers you consider private, or source code you
cannot share.

## What to include in an issue

The first three questions are always the same, so including them saves a round trip:

```
neural-seam version
neural-seam doctor
```

plus your operating system and version, and which install path you used (the graphical installer, the
one-liner, or a manual download).

If the problem is an install or update failure, the SHA-256 you got and the one in the release's
`checksums.txt` are the two numbers that settle it fastest.

## What is not supported

- Builds obtained anywhere other than a release in this repository.
- Modified binaries.
- Running the runtime against an endpoint other than the one it ships with.
