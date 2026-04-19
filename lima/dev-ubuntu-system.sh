#!/bin/bash
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates curl git sudo zsh zsh-autosuggestions openssh-client \
	podman podman-compose podman-docker uidmap \
	ripgrep fd-find bat eza zoxide fzf jq \
	tar unzip gzip \
	pipx \
	build-essential

# Ubuntu ships fd-find as `fdfind` and bat as `batcat`. The zsh config
# aliases and other tools expect the unprefixed names, so expose them.
ln -sf /usr/bin/fdfind /usr/local/bin/fd
ln -sf /usr/bin/batcat /usr/local/bin/bat

# chezmoi is not in the default Ubuntu repositories; install via the
# upstream script, matching how mise is installed below.
if ! command -v chezmoi >/dev/null 2>&1; then
	sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

# helm is not in the default Ubuntu repositories; install via the
# upstream script.
if ! command -v helm >/dev/null 2>&1; then
	curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if ! grep -q '^dev:' /etc/subuid; then
	usermod --add-subuids 100000-165535 dev
fi

if ! grep -q '^dev:' /etc/subgid; then
	usermod --add-subgids 100000-165535 dev
fi

install -d -m 755 -o dev -g dev /home/dev/code

if ! command -v mise >/dev/null 2>&1; then
	curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
fi

# Upgrade podman-compose beyond Ubuntu 24.04's apt 1.0.6 (too old for
# --profile and other docker-compose-v2 flags). pipx drops the latest
# release in ~dev/.local/bin, which shadows /usr/bin/podman-compose on
# the dev user's PATH (set in ~/.zprofile). Kept as a fallback for
# anything invoking podman-compose directly; the primary compose
# provider is real docker compose v2 (installed below).
sudo -u dev -H bash -c '
	set -eu
	export PATH="$HOME/.local/bin:$PATH"
	if pipx list --short 2>/dev/null | grep -q "^podman-compose "; then
		pipx upgrade podman-compose || true
	else
		pipx install podman-compose
	fi
'

# Install real docker compose v2 (Go binary). Wired in as podman's
# external compose provider via ~/.config/containers/containers.conf.
# It supports every docker-compose-spec feature (environment-sourced
# secrets, named profiles, healthcheck conditions, etc.) and talks to
# podman's user socket via DOCKER_HOST set in ~/.zprofile.
DOCKER_COMPOSE_VERSION="v5.1.3"
case "$(dpkg --print-architecture)" in
amd64) COMPOSE_ARCH=x86_64 ;;
arm64) COMPOSE_ARCH=aarch64 ;;
*)
	echo "unsupported architecture for docker compose v2: $(dpkg --print-architecture)" >&2
	exit 1
	;;
esac
install -d /usr/local/lib/docker/cli-plugins
if [[ ! -x /usr/local/lib/docker/cli-plugins/docker-compose ]] \
	|| ! /usr/local/lib/docker/cli-plugins/docker-compose version --short 2>/dev/null | grep -q "^${DOCKER_COMPOSE_VERSION#v}$"; then
	# Download to a tmpfile first and `install` atomically into place.
	# curl writing directly into /usr/local/lib has been observed to
	# fail occasionally (network blip, fs-cache race) with "Failure
	# writing output to destination"; staging via /tmp and then
	# `install`ing the fully-downloaded file is resilient to it.
	dc_tmp="$(mktemp -t docker-compose.XXXXXX)"
	curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" \
		-o "$dc_tmp"
	install -m 0755 "$dc_tmp" /usr/local/lib/docker/cli-plugins/docker-compose
	rm -f "$dc_tmp"
fi

# Let the dev user's systemd session persist across SSH disconnects so
# podman.socket (which compose v2 talks to via DOCKER_HOST) stays up
# even when no interactive shell is attached.
loginctl enable-linger dev
