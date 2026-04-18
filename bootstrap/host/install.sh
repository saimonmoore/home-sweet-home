#!/usr/bin/env bash
# One-shot bootstrap for a fresh macOS host.
#
# Installs Homebrew (if missing), installs chezmoi (needed to apply the
# dotfiles — it is also listed in the Brewfile for later installs), then
# runs `chezmoi init --apply saimon-moore/home-sweet-home`. After chezmoi
# finishes, the post-apply hook on work hosts runs `brew bundle` against
# bootstrap/host/Brewfile.work to install the rest of the host tooling.
#
# Re-running this script is safe: each step skips work that's already done.

set -euo pipefail

log() { printf '==> %s\n' "$*"; }
err() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
	err "this installer targets macOS. Inside the Ubuntu VM, see README.md for the manual chezmoi init flow."
fi

# --- Homebrew ---------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
	log "Installing Homebrew"
	NONINTERACTIVE=1 /bin/bash -c \
		"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	if [[ -x /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -x /usr/local/bin/brew ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	else
		err "Homebrew install finished but 'brew' is not on PATH."
	fi
else
	log "Homebrew already installed"
fi

# --- chezmoi ----------------------------------------------------------------
if ! command -v chezmoi >/dev/null 2>&1; then
	log "Installing chezmoi via Homebrew"
	brew install chezmoi
else
	log "chezmoi already installed"
fi

# --- Apply dotfiles ---------------------------------------------------------
log "Running: chezmoi init --apply saimon-moore/home-sweet-home"
chezmoi init --apply saimon-moore/home-sweet-home

# --- Next steps -------------------------------------------------------------
cat <<'NEXT'

============================================================
home-sweet-home host bootstrap is complete.

Open a new terminal so PATH changes and shell integrations
load, then:

  1. Create the Ubuntu dev VM (macOS host only):
       ,create-vm

  2. Open a shell inside the VM:
       ,dev

  3. In the VM, as the `dev` user, run the one-time setup:
       mkdir -p "$HOME/.ssh"
       chmod 700 "$HOME/.ssh"
       ssh-keygen -q -t ed25519 -N '' \
         -C "dev@dev" -f "$HOME/.ssh/id_ed25519"
       chezmoi init --apply saimon-moore/home-sweet-home
       mise install
       chezmoi apply

  4. For a terminal-tool keybinding reference at any time:
       ,cheatsheet

Full docs (VM networking, JFrog credentials, OpenCode auth):
  https://github.com/saimon-moore/home-sweet-home#readme
============================================================
NEXT
