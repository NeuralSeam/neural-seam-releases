# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report it privately through GitHub's private vulnerability reporting on this repository:
**Security > Report a vulnerability**
(<https://github.com/NeuralSeam/neural-seam-releases/security/advisories/new>).

If private reporting is unavailable to you, use the in-product support form at
<https://app.neuralseam.cloud> and mark the request as a security issue. Do not include working
exploit code or credentials in that form; say that you have them and we will arrange a private
channel.

Please include, as far as you can:

- what an attacker gains, and what access they need to start;
- the version involved (`neural-seam version`) and your operating system;
- the smallest reproduction you have.

We aim to acknowledge a report within **5 business days** and to give you an assessment and a plan
within **15 business days**. Please give us reasonable time to ship a fix before disclosing publicly.
We will credit you in the release notes unless you ask us not to.

## Scope

This repository distributes the **Neural Seam Client Runtime**: the `neural-seam` binary, the Windows
installer and the system tray, plus the scripts that install them. The source code is not here.

**In scope:**

- The published executables and the installer.
- `install.ps1` and `install.sh`, which are served raw from this repository and executed by the
  one-liner. Anything that lets those scripts install something other than the verified release asset
  is a vulnerability.
- The integrity chain of a release: `checksums.txt`, and how each install path verifies against it.
- Anything in this repository or its history that should not be public.

**Out of scope here, but still wanted:** vulnerabilities in the Neural Seam backend or the web
applications, and in the plugins for the supported agent hosts. Report those through the same private
channel and they will be routed. Vulnerabilities in an agent host itself belong to that host's vendor.

## Integrity of a download, stated honestly

Every install path verifies the downloaded asset's **SHA-256** against the `checksums.txt` published
with the release, and aborts on mismatch or on a missing entry. That check is mandatory in
`install.ps1`, in `install.sh` and in `neural-seam upgrade`.

What that gives you, and what it does not:

| Property | Status |
| --- | --- |
| The file you got is the file we published | **Yes**, via SHA-256 plus HTTPS from GitHub |
| The file was not corrupted in transit or on disk | **Yes** |
| A publisher identity you can verify offline | **Not yet.** There is no Authenticode signature and no signed manifest |
| Release tags signed by a maintainer key | **No.** Tags in this repository are created by the release pipeline and are not signed |

`checksums.txt` is served from the same release as the binary, so the trust root today is your HTTPS
connection to GitHub and the account that published the release, not a publisher key you hold. We are
not going to describe that as more than it is. Publisher code signing is planned; until it ships, treat
the SHA-256 check plus HTTPS as the guarantee.

Two consequences worth knowing:

- On first run, Windows SmartScreen will warn about an unknown publisher, and Windows Defender has in
  the past flagged the unsigned installer as a false positive. An unsigned Go binary packaged with
  NSIS is a known trigger for machine-learning detections. If your Defender quarantines an installer
  you downloaded from a release here, tell us through the channel above.
- Do not trust a copy of `neural-seam` obtained anywhere else. Verify with `neural-seam version` and
  compare the SHA-256 against the release you meant to install.

## What the runtime does on your machine

Relevant when assessing a report.

- It **never authenticates to a model provider** and holds no model provider credentials. Every model
  call originates from your own action in your own agent host, which is not in this software's path.
- It runs **no daemon and no timer**. `neural-seam upgrade` runs because you typed it.
- The local HTTP bridge listens on **loopback only**, on the first free port in a small fixed range,
  and is used during project setup.
- It runs language servers locally to answer symbolic queries. **Your source code is read on your
  machine and is not uploaded to run them.**
- Credentials are stored in your operating system's credential vault where one is available, and
  otherwise in an owner-only file. See [PRIVACY.md](./PRIVACY.md).

## Supported versions

Only the latest published version receives fixes. Releases are listed at
<https://github.com/NeuralSeam/neural-seam-releases/releases>. To update, run `neural-seam upgrade`.
