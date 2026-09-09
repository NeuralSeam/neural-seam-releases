# Privacy

What the **Neural Seam Client Runtime** does with your data. This describes the behaviour of the
software you install from this repository; it is not the Neural Seam service agreement.

## What is sent, and when

Some of this is sent because it is how the product works. **Only the last row is optional.**

| Data | Sent | When | Why |
| --- | --- | --- | --- |
| Your sign in, via device flow | Always | When you run `neural-seam login` | To authenticate you |
| Your machine's host name and operating system family (`windows`, `darwin`, `linux`) | Always | At sign in only | So a sign in notice can tell you **which** machine is asking, when your account already has an active session. There is no machine fingerprint, and if the host name is unavailable the field is simply omitted |
| Your project's coordination data: spec, backlog, cards, status | Always | When you use the product | It is the product: this data is what makes your project's knowledge available to any developer and any agent on the team |
| Telemetry | **Only if you turn it on** | Off by default | Configured under the `telemetry` key of `config.json`, with a declared scope. Off is the default and the absence of the key means off |

Signing in, identifying the machine at sign in, and your project's coordination data are sent whether
or not telemetry is enabled. **Turning telemetry off does not make the runtime offline**: it is a
coordination client, and coordination data is what it coordinates.

The runtime talks to the Neural Seam backend and to nothing else, over HTTPS. It **never authenticates
to a model provider**, holds no model provider credentials, and makes no model calls of its own.

## What stays on your machine

- **Your source code.** The runtime runs language servers locally to answer symbolic questions about
  your code. Those run on your machine and read your files there. Code is not uploaded to run them.
- **Your credentials.** See below.
- **The local dashboard and setup bridge.** Served on loopback only, never exposed to the network.
- **Local state**, under `~/.neural-seam/`: configuration, the local project registry, your language
  preferences, the language servers the runtime provisioned, and session logs.

## Where credentials are kept

On **Windows**, tokens are stored in the operating system's Credential Manager, encrypted per user,
and **no plaintext token is written to disk**. A pre-existing plaintext credential file is imported
into the vault on first run and then removed, without asking you to sign in again.

On other platforms, and whenever you set a custom `NEURAL_SEAM_HOME`, tokens live in a file with
owner-only permissions (`0600` on POSIX, an owner-only ACL on Windows).

Either way: never commit that credential, and never copy it to another machine. `neural-seam logout`
removes it from **both** stores.

## What your agent sends

Worth being explicit about, because it is easy to miss. The runtime connects Neural Seam to an agent
host, and **that host has its own privacy behaviour**. Your prompts, and whatever context the agent
gathers, go to that host's vendor under that vendor's terms. Neural Seam is not in that path and
cannot see it.

## What this repository collects

Nothing. It is a distribution point. Downloading a release is a request to GitHub, subject to GitHub's
own privacy practices, and we receive only the aggregate download counts GitHub shows publicly on the
release page.

## Removing your local data

Uninstalling is described in the [User Manual](./USER-MANUAL.md). Deleting `~/.neural-seam/` removes
your local credentials, the local project registry and the provisioned language servers. It does not
delete anything held in your Neural Seam account; for that, use the support form at
<https://app.neuralseam.cloud>.
