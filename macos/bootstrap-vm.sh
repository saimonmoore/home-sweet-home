#!/usr/bin/env bash
set -euo pipefail

# One-time VM bootstrap for agent development inside Lima.
# Run this script from the cloned setup repository inside the VM.
# Usage:
#   ./bootstrap-vm.sh <git-email> [git-name]
#
# Prerequisites (inside the Lima VM):
#   sudo dnf install -y git
#   echo 'export OPENAI_API_KEY="sk-..."' >> ~/.bashrc && source ~/.bashrc

BASHRC="$HOME/.bashrc"
STARSHIP_CONFIG_PATH="$HOME/.config/starship-agent.toml"
STARSHIP_CONFIGURED=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
GIT_EMAIL="${1:-}"
GIT_NAME="${2:-${USER:-Agent VM}}"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519_agent_vm"
SSH_CONFIG_PATH="$HOME/.ssh/config"
SSH_BLOCK_START="# >>> agentex github key >>>"
SSH_BLOCK_END="# <<< agentex github key <<<"
MISE_BIN="$HOME/.local/bin/mise"

append_if_missing() {
	local line="$1"
	local file="$2"
	touch "$file"
	if ! grep -Fqx "$line" "$file"; then
		echo "$line" >>"$file"
	fi
}

replace_block_in_file() {
	local file="$1"
	local start="$2"
	local end="$3"
	local block_content="$4"
	touch "$file"
	awk -v s="$start" -v e="$end" '
    $0==s {skip=1; next}
    $0==e {skip=0; next}
    !skip {print}
  ' "$file" >"${file}.tmp"
	mv "${file}.tmp" "$file"
	{
		echo ""
		echo "$start"
		printf "%s\n" "$block_content"
		echo "$end"
	} >>"$file"
}

run_as_root() {
	if [[ "$(id -u)" -eq 0 ]]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		echo "Error: need root privileges for: $*" >&2
		exit 1
	fi
}

setup_system_dependencies() {
	if ! command -v dnf >/dev/null 2>&1; then
		echo "Error: dnf not found. This bootstrap currently expects a Fedora-based VM." >&2
		exit 1
	fi

	echo "Installing system dependencies via dnf..."
	run_as_root dnf install -y git ripgrep fd-find jq make gcc gcc-c++ curl openssh-clients
}

setup_mise() {
	if command -v mise >/dev/null 2>&1; then
		MISE_BIN="$(command -v mise)"
	elif [[ -x "$MISE_BIN" ]]; then
		:
	else
		echo "Installing mise..."
		curl https://mise.run | sh
	fi

	if [[ ! -x "$MISE_BIN" ]]; then
		if command -v mise >/dev/null 2>&1; then
			MISE_BIN="$(command -v mise)"
		else
			echo "Error: mise installation failed or mise not on PATH." >&2
			exit 1
		fi
	fi

	append_if_missing 'eval "$($HOME/.local/bin/mise activate bash)"' "$BASHRC"
	export PATH="$HOME/.local/bin:$PATH"
}

setup_tools() {
	echo "Configuring mise Ruby to prefer precompiled binaries..."
	"$MISE_BIN" settings ruby.compile=false

	echo "Installing global tools via mise (opencode, ruby, go, starship)..."
	"$MISE_BIN" use -g opencode@latest ruby@latest go@latest starship@latest
	eval "$("$MISE_BIN" activate bash)"
}

setup_opencode_config() {
	if [[ ! -d "$TEMPLATES_DIR" ]]; then
		echo "Error: templates directory not found at '$TEMPLATES_DIR'" >&2
		exit 1
	fi

	echo "Installing OpenCode templates into home directory..."
	cp "$TEMPLATES_DIR/AGENTS.md" "$HOME/AGENTS.md"
	cp "$TEMPLATES_DIR/opencode.json" "$HOME/opencode.json"
	mkdir -p "$HOME/.opencode"
	cp -R "$TEMPLATES_DIR/dot-opencode/." "$HOME/.opencode/"
}

setup_git() {
	if [[ -z "$GIT_EMAIL" ]]; then
		echo "Usage: ./bootstrap-vm.sh <git-email> [git-name]" >&2
		exit 1
	fi

	echo "Configuring global git identity..."
	git config --global user.email "$GIT_EMAIL"
	git config --global user.name "$GIT_NAME"
	git config --global init.defaultBranch main
	git config --global pull.rebase false
	git config --global core.editor vim
}

setup_ssh() {
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"

	if [[ ! -f "$SSH_KEY_PATH" ]]; then
		echo "Generating dedicated SSH key for this VM..."
		ssh-keygen -t ed25519 -C "$GIT_EMAIL (agent-vm)" -f "$SSH_KEY_PATH" -N ""
	else
		echo "SSH key already exists: $SSH_KEY_PATH"
	fi

	chmod 600 "$SSH_KEY_PATH"
	chmod 644 "${SSH_KEY_PATH}.pub"

	replace_block_in_file "$SSH_CONFIG_PATH" "$SSH_BLOCK_START" "$SSH_BLOCK_END" \
		"Host github.com
  HostName github.com
  User git
  IdentityFile $SSH_KEY_PATH
  IdentitiesOnly yes"
	chmod 600 "$SSH_CONFIG_PATH"
}

setup_agent_shell() {
	append_if_missing 'export AGENT_SHELL=1' "$BASHRC"
	append_if_missing 'eval "$(mise activate bash)"' "$BASHRC"

	if ! command -v starship >/dev/null 2>&1; then
		echo "Warning: starship command not found; AGENT_SHELL env marker is still enabled."
		return
	fi

	append_if_missing 'export STARSHIP_CONFIG="$HOME/.config/starship-agent.toml"' "$BASHRC"
	append_if_missing 'eval "$(starship init bash)"' "$BASHRC"

	mkdir -p "$(dirname "$STARSHIP_CONFIG_PATH")"
	cat >"$STARSHIP_CONFIG_PATH" <<'STARSHIP'
format = "$custom$directory$git_branch$git_status$line_break$character"

[custom.agent]
command = "echo AGENT-SHELL"
when = "test \"$AGENT_SHELL\" = \"1\""
shell = ["bash", "--noprofile", "--norc"]
style = "bold black bg:green"
format = "[$output]($style) "
STARSHIP

	STARSHIP_CONFIGURED=1
}

echo "Bootstrapping VM tools, OpenCode config, git, ssh, and shell markers..."
setup_system_dependencies
setup_mise
setup_tools
setup_opencode_config
setup_git
setup_ssh
setup_agent_shell

echo ""
if [[ "$STARSHIP_CONFIGURED" -eq 1 ]]; then
	echo "Starship AGENT-SHELL prompt marker configured."
else
	echo "AGENT_SHELL env marker configured (without Starship prompt module)."
fi

echo "Open a new shell or run: source ~/.bashrc"
echo "OpenCode config installed in home: ~/opencode.json, ~/AGENTS.md, ~/.opencode/"
echo "Add this SSH public key to GitHub (Settings -> SSH and GPG keys):"
echo "File: ${SSH_KEY_PATH}.pub"
echo "----- BEGIN PUBLIC KEY -----"
cat "${SSH_KEY_PATH}.pub"
echo "----- END PUBLIC KEY -----"
echo "VM bootstrap complete."
