#!/bin/bash
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

# GitHub SSH can hang inside the Lima guest on some host/VPN/Wi-Fi
# paths when the default 1500-byte MTU on lima0 is too optimistic.
# Keep the guest-side MTU conservative so PMTU black holes don't break
# git pull/push while leaving the host networking untouched.
LIMA_PRIMARY_IFACE="${LIMA_PRIMARY_IFACE:-lima0}"
LIMA_PRIMARY_MTU="${LIMA_PRIMARY_MTU:-1280}"

apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates curl git sudo zsh zsh-autosuggestions openssh-client \
	uidmap dbus-user-session fuse-overlayfs slirp4netns iptables \
	qemu-user-static binfmt-support \
	ripgrep fd-find bat eza zoxide fzf jq \
	tar unzip gzip \
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

# subuid / subgid are required for Docker rootless (user namespace
# remapping). 100000-165535 gives 65536 contiguous IDs, the standard
# minimum.
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

# Install Docker Engine + CLI + Buildx + Compose v2 from Docker's
# official apt repo. Rootless mode is completed per-user by the
# chezmoi run_once hook (dockerd-rootless-setuptool.sh install),
# which creates the user systemd unit and socket at
# $XDG_RUNTIME_DIR/docker.sock (matching DOCKER_HOST in ~/.zprofile).
if ! command -v docker >/dev/null 2>&1; then
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
		-o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc

	# shellcheck disable=SC1091
	. /etc/os-release
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
		>/etc/apt/sources.list.d/docker.list

	apt-get update
	apt-get install -y --no-install-recommends \
		docker-ce \
		docker-ce-cli \
		containerd.io \
		docker-buildx-plugin \
		docker-compose-plugin \
		docker-ce-rootless-extras
fi

# We use rootless Docker only. Disable the system-wide rootful dockerd
# and its socket so they don't race with the per-user service set up by
# dockerd-rootless-setuptool.sh.
systemctl disable --now docker.service docker.socket 2>/dev/null || true

# Let the dev user's systemd session persist across SSH disconnects so
# the rootless Docker service stays up even when no interactive shell
# is attached.
loginctl enable-linger dev

cat >/usr/local/sbin/home-sweet-home-fix-lima-mtu <<EOF
#!/bin/sh
set -eu

iface="${LIMA_PRIMARY_IFACE}"
mtu="${LIMA_PRIMARY_MTU}"

i=0
while [ "\$i" -lt 30 ]; do
	if ip link show dev "\$iface" >/dev/null 2>&1; then
		ip link set dev "\$iface" mtu "\$mtu"
		exit 0
	fi
	i=\$((i + 1))
	sleep 1
done

echo "warning: interface \$iface not found; skipped MTU adjustment" >&2
exit 0
EOF
chmod 0755 /usr/local/sbin/home-sweet-home-fix-lima-mtu

cat >/etc/systemd/system/home-sweet-home-fix-lima-mtu.service <<EOF
[Unit]
Description=Apply a conservative MTU to Lima's primary NIC
After=network-pre.target systemd-udev-settle.service
Wants=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/home-sweet-home-fix-lima-mtu
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable home-sweet-home-fix-lima-mtu.service
