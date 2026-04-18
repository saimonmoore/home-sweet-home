#!/usr/bin/env bash
# One-shot bootstrap for a fresh macOS host.
#
# Usage:
#   install.sh              # normal run (idempotent)
#   install.sh --reset      # wipe chezmoi prompt answers + rendered
#                           # config so you can answer fresh, then
#                           # re-clone/re-apply everything
#   install.sh --nuke       # also delete the chezmoi source clone at
#                           # ~/.local/share/chezmoi — forces a fresh
#                           # git clone. Use if the local clone is
#                           # corrupted or in a broken state.
#
# Installs Homebrew (if missing), installs chezmoi, then either:
#   - clones and applies saimonmoore/home-sweet-home via
#     `chezmoi init --apply` on a fresh machine, or
#   - pulls the latest source and re-applies via `chezmoi update` on a
#     machine that already has the chezmoi source initialised.
# After that, the post-apply hooks run `brew bundle` against the host
# Brewfile, clone the nb notebook, and sync openskills skills.
#
# Re-running this script is safe and picks up the latest home-sweet-home
# from GitHub each time. If you ran it once and the shell that invoked
# it has since exited (so PATH doesn't include Homebrew), the script
# detects an existing /opt/homebrew or /usr/local brew install and
# sources shellenv without reinstalling Homebrew.

set -euo pipefail

reset=false
nuke=false
for arg in "$@"; do
	case "$arg" in
		--reset) reset=true ;;
		--nuke)  reset=true; nuke=true ;;
		-h|--help)
			sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			printf 'Unknown argument: %s\n' "$arg" >&2
			exit 2
			;;
	esac
done

log() { printf '==> %s\n' "$*"; }
err() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
	err "this installer targets macOS. Inside the Ubuntu VM, see README.md for the manual chezmoi init flow."
fi

chezmoi_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
chezmoi_default_source="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"

source_brew_shellenv() {
	if [[ -x /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -x /usr/local/bin/brew ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	else
		err "Homebrew expected but 'brew' is not on PATH and no /opt/homebrew or /usr/local install was found."
	fi
}

# --- Homebrew ---------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
	if [[ -x /opt/homebrew/bin/brew ]] || [[ -x /usr/local/bin/brew ]]; then
		log "Homebrew already installed; sourcing shellenv"
		source_brew_shellenv
	else
		log "Installing Homebrew"
		NONINTERACTIVE=1 /bin/bash -c \
			"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		source_brew_shellenv
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

# --- Optional reset ---------------------------------------------------------
# --reset: wipe chezmoi's rendered config + prompt state so the next init
#          re-prompts (you can change your answers).
# --nuke:  also delete the chezmoi source clone, forcing a fresh git clone.
if [[ "$reset" == true ]]; then
	log "Removing chezmoi config + state to force re-prompt"
	rm -f "$chezmoi_config_dir/chezmoi.toml" \
	      "$chezmoi_config_dir/chezmoistate.boltdb"
fi
if [[ "$nuke" == true ]]; then
	chezmoi_existing_source="$(chezmoi source-path 2>/dev/null || true)"
	for dir in "$chezmoi_existing_source" "$chezmoi_default_source"; do
		if [[ -n "$dir" && -d "$dir" ]]; then
			log "Removing chezmoi source clone at $dir"
			rm -rf "$dir"
		fi
	done
fi

# --- Apply dotfiles ---------------------------------------------------------
# Fresh (or just-reset) machine: `chezmoi init --apply` so the source gets
# cloned and prompts are answered. Already-initialised machine: `chezmoi
# update` pulls the latest home-sweet-home from GitHub before applying —
# otherwise a re-run would silently re-apply a stale local clone.
chezmoi_source="$(chezmoi source-path 2>/dev/null || true)"
if [[ -n "$chezmoi_source" && -d "$chezmoi_source/.git" ]]; then
	log "chezmoi source already initialised at $chezmoi_source — running 'chezmoi update'"
	chezmoi update
else
	log "Running: chezmoi init --apply saimonmoore/home-sweet-home"
	chezmoi init --apply saimonmoore/home-sweet-home
fi

# --- Verify -----------------------------------------------------------------
verify_cmd="$HOME/.local/bin/,verify"
if [[ -x "$verify_cmd" ]]; then
	log "Running ,verify"
	# Keep going even if some checks warn or fail — the summary tells you
	# what's left, and the next-steps block below still needs to print.
	"$verify_cmd" || true
else
	printf 'Warning: ,verify not found at %s — skipping.\n' "$verify_cmd" >&2
fi

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
       chezmoi init --apply saimonmoore/home-sweet-home
       mise install
       chezmoi apply

  4. For a terminal-tool keybinding reference at any time:
       ,cheatsheet

Full docs (VM networking, JFrog credentials, OpenCode auth):
  https://github.com/saimonmoore/home-sweet-home#readme
============================================================
NEXT
