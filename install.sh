#!/bin/sh
# Neural Seam Client Runtime - one-liner installer for Linux and macOS.
#
# Usage (latest release):
#   curl -fsSL https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.sh | sh
#
# Pin a specific version (bare SemVer, no "runtime-v" prefix):
#   curl -fsSL .../install.sh | NEURAL_SEAM_VERSION=1.2.3 sh
#   curl -fsSL .../install.sh | sh -s -- --version 1.2.3
#
# Override the install dir (default: $HOME/.local/bin):
#   curl -fsSL .../install.sh | NEURAL_SEAM_INSTALL_DIR=/usr/local/bin sh
#
# What it does: detect OS/arch, resolve the matching release asset
# (neural-seam-<os>-<arch>), download it, verify its sha256 against the
# release's checksums.txt (MANDATORY - aborts on mismatch), and install it as
# `neural-seam` on a PATH location, printing PATH guidance when needed.
#
# Compliance (P2): this script only fetches, verifies and places a binary. It
# runs no inference and triggers nothing; the developer-initiated update path
# after install is `neural-seam upgrade`.
#
# Hardening: sha256 verification is mandatory here. Code signing and TLS
# pinning are not yet active; this installer does not verify a signature.
# See docs/install.md.
#
# POSIX sh only (no bashisms): `curl | sh` may run under dash. Validated with
# `sh -n`, `bash -n` and shellcheck.

set -eu

# Public distribution repo (source lives in the private neural-seam-runtime;
# releases + this script are published to the public neural-seam-releases).
REPO="NeuralSeam/neural-seam-releases"
BINARY="neural-seam"
# Default per-user install dir; created if absent.
INSTALL_DIR="${NEURAL_SEAM_INSTALL_DIR:-$HOME/.local/bin}"
# Empty means "latest release"; may be set via env or --version.
VERSION="${NEURAL_SEAM_VERSION:-}"

# --- output helpers -------------------------------------------------------

# All diagnostics go to stderr so a piped stdout stays clean.
info() { printf '%s\n' "$*" >&2; }
err() { printf 'neural-seam install: %s\n' "$*" >&2; }

# fail prints an actionable message and aborts. No half-installed binary is
# ever left behind: the download lands in a temp dir wiped by the EXIT trap,
# and the final move is the last step.
fail() {
	err "$*"
	exit 1
}

# --- argument parsing -----------------------------------------------------

while [ $# -gt 0 ]; do
	case "$1" in
	--version)
		[ $# -ge 2 ] || fail "--version requires a value (e.g. --version 1.2.3)"
		VERSION="$2"
		shift 2
		;;
	--version=*)
		VERSION="${1#--version=}"
		shift
		;;
	--dir)
		[ $# -ge 2 ] || fail "--dir requires a value"
		INSTALL_DIR="$2"
		shift 2
		;;
	--dir=*)
		INSTALL_DIR="${1#--dir=}"
		shift
		;;
	-h | --help)
		info "Usage: install.sh [--version <semver>] [--dir <path>]"
		info "  --version  install a specific release (default: latest)"
		info "  --dir      install location (default: \$HOME/.local/bin)"
		exit 0
		;;
	*)
		fail "unknown argument: $1 (try --help)"
		;;
	esac
done

# --- prerequisites --------------------------------------------------------

# Need a downloader (curl or wget) and a sha256 tool.
if command -v curl >/dev/null 2>&1; then
	DL="curl"
elif command -v wget >/dev/null 2>&1; then
	DL="wget"
else
	fail "need curl or wget on PATH to download the release"
fi

# download_to <url> <dest-file>: fetch url into dest, failing loudly. Both curl
# (-f fails on HTTP errors) and wget map a 4xx/5xx to a non-zero exit.
download_to() {
	_url="$1"
	_dest="$2"
	if [ "$DL" = "curl" ]; then
		curl -fsSL -o "$_dest" "$_url"
	else
		wget -qO "$_dest" "$_url"
	fi
}

# download_stdout <url>: fetch url to stdout (used for small text like the
# GitHub API JSON and checksums.txt).
download_stdout() {
	_url="$1"
	if [ "$DL" = "curl" ]; then
		curl -fsSL "$_url"
	else
		wget -qO- "$_url"
	fi
}

# Pick a sha256 tool: GNU coreutils `sha256sum` or BSD/macOS `shasum -a 256`.
if command -v sha256sum >/dev/null 2>&1; then
	sha256_of() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
	sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }
else
	fail "need sha256sum or shasum on PATH to verify the download"
fi

# --- detect OS / arch -----------------------------------------------------

detect_os() {
	_os="$(uname -s)"
	case "$_os" in
	Linux) printf 'linux' ;;
	Darwin) printf 'darwin' ;;
	*) fail "unsupported OS: $_os (supported: Linux, macOS). On Windows use install.ps1." ;;
	esac
}

detect_arch() {
	_arch="$(uname -m)"
	case "$_arch" in
	x86_64 | amd64) printf 'amd64' ;;
	aarch64 | arm64) printf 'arm64' ;;
	*) fail "unsupported architecture: $_arch (supported: amd64, arm64)" ;;
	esac
}

OS="$(detect_os)"
ARCH="$(detect_arch)"
# Asset naming is the release contract: neural-seam-<os>-<arch> (no .exe on
# Unix). Mirrors internal/selfupdate AssetName so installer and self-update
# agree on the layout.
ASSET="${BINARY}-${OS}-${ARCH}"

# --- pilot platform gate --------------------------------------------------

# The pilot release publishes only windows/amd64; darwin/linux and arm64 are
# DEFERRED in .goreleaser.yml. This script only ever targets Linux/macOS, so no
# matching asset is published yet. Fail early with an actionable message here
# instead of a raw "asset not found" download error further down. When the
# multi-OS pipeline is restored (sibling card
# readd-release-pipeline-steps-after-pilot.md), remove this gate.
case "${OS}/${ARCH}" in
windows/amd64) : ;; # published (unreachable from this script; kept explicit)
*) fail "the pilot release publishes only windows/amd64; ${OS}/${ARCH} is not published yet. Install on Windows (amd64) via install.ps1, or wait for the multi-OS release. See docs/install.md." ;;
esac

# --- resolve version / URLs ----------------------------------------------

# resolve_latest_tag queries the GitHub releases/latest API and extracts
# tag_name with a portable grep/sed (no jq dependency). The releases/latest +
# browser_download_url pair is the documented contract.
resolve_latest_tag() {
	_api="https://api.github.com/repos/${REPO}/releases/latest"
	_json="$(download_stdout "$_api")" || fail "could not reach the GitHub releases API ($_api). Check your network and try again, or pass --version."
	# Pull the first "tag_name": "..." value.
	_tag="$(printf '%s\n' "$_json" | grep -m1 '"tag_name"' | sed -e 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//' -e 's/".*//')"
	[ -n "$_tag" ] || fail "could not determine the latest release tag from the GitHub API response"
	printf '%s' "$_tag"
}

if [ -n "$VERSION" ]; then
	# Accept either a bare SemVer or a full tag; normalise to the runtime-v tag.
	_v="${VERSION#runtime-v}"
	_v="${_v#v}"
	TAG="runtime-v${_v}"
	DISPLAY_VERSION="$_v"
else
	TAG="$(resolve_latest_tag)"
	DISPLAY_VERSION="${TAG#runtime-v}"
fi

BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
ASSET_URL="${BASE_URL}/${ASSET}"
CHECKSUMS_URL="${BASE_URL}/checksums.txt"

# --- download + verify ----------------------------------------------------

TMPDIR_INSTALL="$(mktemp -d 2>/dev/null || mktemp -d -t neural-seam)"
# Wipe the temp dir on any exit so a failed run never leaves a partial binary.
trap 'rm -rf "$TMPDIR_INSTALL"' EXIT INT TERM

info "Installing ${BINARY} ${DISPLAY_VERSION} (${OS}/${ARCH})..."

ASSET_PATH="${TMPDIR_INSTALL}/${ASSET}"
CHECKSUMS_PATH="${TMPDIR_INSTALL}/checksums.txt"

download_to "$ASSET_URL" "$ASSET_PATH" ||
	fail "download failed for ${ASSET_URL}. The asset may not exist for this OS/arch/version, or the network is unavailable."
download_to "$CHECKSUMS_URL" "$CHECKSUMS_PATH" ||
	fail "download failed for ${CHECKSUMS_URL}. Cannot verify integrity, aborting."

# Mandatory sha256 gate. Look up the expected digest for our asset; abort if
# the asset has no line, and abort on mismatch. The checksums.txt format is
# "<hexdigest>  <filename>"; tolerate a leading "*" binary-mode marker.
EXPECTED="$(awk -v f="$ASSET" '{ name=$2; sub(/^\*/,"",name); if (name==f) { print $1; exit } }' "$CHECKSUMS_PATH")"
[ -n "$EXPECTED" ] ||
	fail "no checksum entry for ${ASSET} in checksums.txt; refusing to install an unverifiable binary."

ACTUAL="$(sha256_of "$ASSET_PATH")"
if [ "$(printf '%s' "$EXPECTED" | tr 'A-Z' 'a-z')" != "$(printf '%s' "$ACTUAL" | tr 'A-Z' 'a-z')" ]; then
	fail "checksum mismatch for ${ASSET}: expected ${EXPECTED}, got ${ACTUAL}. The download is corrupt or tampered; aborting (nothing installed)."
fi
info "Checksum verified (sha256)."

# --- install --------------------------------------------------------------

mkdir -p "$INSTALL_DIR" || fail "could not create install dir ${INSTALL_DIR}"
DEST="${INSTALL_DIR}/${BINARY}"

chmod +x "$ASSET_PATH"
# mv within the same filesystem is atomic; fall back to cp+rm across devices so
# a temp dir on another mount still works.
if ! mv "$ASSET_PATH" "$DEST" 2>/dev/null; then
	cp "$ASSET_PATH" "$DEST" || fail "could not install to ${DEST} (permission denied? try --dir with a writable location)"
	chmod +x "$DEST"
fi

info "Installed ${BINARY} to ${DEST}."

# --- PATH guidance --------------------------------------------------------

# Is INSTALL_DIR already on PATH? Compare path-list entries exactly.
on_path() {
	case ":${PATH}:" in
	*":${INSTALL_DIR}:"*) return 0 ;;
	*) return 1 ;;
	esac
}

if on_path; then
	info ""
	info "Run '${BINARY} version' to confirm. Update later with '${BINARY} upgrade'."
else
	info ""
	info "${INSTALL_DIR} is not on your PATH. Add it, e.g.:"
	info ""
	info "  echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.profile"
	info "  # then restart your shell or: export PATH=\"${INSTALL_DIR}:\$PATH\""
	info ""
	info "Then run '${BINARY} version' to confirm. Update later with '${BINARY} upgrade'."
fi
