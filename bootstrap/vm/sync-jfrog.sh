#!/usr/bin/env bash
set -euo pipefail

if ! command -v limactl >/dev/null 2>&1; then
	echo "Error: limactl is required but was not found on PATH." >&2
	exit 1
fi

url_encode() {
	local raw="$1"
	local encoded=""
	local i ch byte

	for ((i = 0; i < ${#raw}; i++)); do
		ch="${raw:i:1}"
		case "$ch" in
		[a-zA-Z0-9.~_-])
			encoded+="$ch"
			;;
		*)
			printf -v byte '%%%02X' "'$ch"
			encoded+="$byte"
			;;
		esac
	done

	printf '%s' "$encoded"
}

INSTANCE_NAME="dev"
JFROG_HOST=""
JFROG_REALM="Artifactory Realm"
RUBY_HOST=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--vm-name)
		INSTANCE_NAME="$2"
		shift 2
		;;
	--host)
		JFROG_HOST="$2"
		shift 2
		;;
	--realm)
		JFROG_REALM="$2"
		shift 2
		;;
	--ruby-host)
		RUBY_HOST="$2"
		shift 2
		;;
	-h | --help)
		echo "Usage: bootstrap/vm/sync-jfrog.sh --host HOST [--realm REALM] [--ruby-host HOST] [--vm-name NAME]"
		exit 0
		;;
	*)
		echo "Error: unknown argument '$1'." >&2
		exit 1
		;;
	esac
done
if [[ -z "$JFROG_HOST" ]]; then
	echo "Error: --host is required." >&2
	exit 1
fi

if [[ -z "$RUBY_HOST" ]]; then
	RUBY_HOST="$JFROG_HOST"
fi

if [[ -z "${JFROG_OIDC_USER:-}" || -z "${JFROG_OIDC_TOKEN:-}" ]]; then
	if ! command -v op >/dev/null 2>&1; then
		echo "Error: JFROG_OIDC_USER and JFROG_OIDC_TOKEN are not set. Run ,jfrog_oidc_env first or install 1Password CLI (op)." >&2
		exit 1
	fi

	echo "Exporting jfrog credentials from 1Password"
	JFROG_OIDC_USER="$(op read "op://Private/JFROG_OIDC/username")"
	JFROG_OIDC_TOKEN="$(op read "op://Private/JFROG_OIDC/password")"
	if [[ -z "$JFROG_OIDC_USER" || -z "$JFROG_OIDC_TOKEN" ]]; then
		echo "Error: failed to read JFrog credentials from 1Password." >&2
		exit 1
	fi
fi

BUNDLE_USERNAME_ENCODED="$(url_encode "$JFROG_OIDC_USER")"
BUNDLE_TOKEN_ENCODED="$(url_encode "$JFROG_OIDC_TOKEN")"
BUNDLE_CREDENTIALS_ENCODED="$BUNDLE_USERNAME_ENCODED:$BUNDLE_TOKEN_ENCODED"

TMP_REMOTE_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/home-sweet-home-jfrog-sync.XXXXXX")"
cleanup() {
	rm -f "$TMP_REMOTE_SCRIPT"
}
trap cleanup EXIT

{
	printf 'set -euo pipefail\n'
	printf 'JFROG_OIDC_USER=%q\n' "$JFROG_OIDC_USER"
	printf 'JFROG_OIDC_TOKEN=%q\n' "$JFROG_OIDC_TOKEN"
	printf 'JFROG_HOST=%q\n' "$JFROG_HOST"
	printf 'JFROG_REALM=%q\n' "$JFROG_REALM"
	printf 'RUBY_HOST=%q\n' "$RUBY_HOST"
	printf 'BUNDLE_CREDENTIALS_ENCODED=%q\n' "$BUNDLE_CREDENTIALS_ENCODED"
	cat <<'EOF'
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hsh_config_dir="$config_home/home-sweet-home"
bundle_env_host="${RUBY_HOST//-/___}"
bundle_env_host="${bundle_env_host//./__}"
bundle_env_key="BUNDLE_${bundle_env_host^^}"

install -d -m 700 "$hsh_config_dir"

printf "export JFROG_OIDC_USER=%q\n" "$JFROG_OIDC_USER" > "$hsh_config_dir/jfrog-oidc.env"
printf "export JFROG_OIDC_TOKEN=%q\n" "$JFROG_OIDC_TOKEN" >> "$hsh_config_dir/jfrog-oidc.env"
printf "export JFROG_HOST=%q\n" "$JFROG_HOST" >> "$hsh_config_dir/jfrog-oidc.env"
printf "export JFROG_REALM=%q\n" "$JFROG_REALM" >> "$hsh_config_dir/jfrog-oidc.env"
printf "export %s=%q\n" "$bundle_env_key" "$BUNDLE_CREDENTIALS_ENCODED" >> "$hsh_config_dir/jfrog-oidc.env"
chmod 600 "$hsh_config_dir/jfrog-oidc.env"
EOF
} >"$TMP_REMOTE_SCRIPT"

cat "$TMP_REMOTE_SCRIPT" | limactl shell --workdir /home/dev "$INSTANCE_NAME" bash -s

echo "Synced JFrog credentials for dev on VM $INSTANCE_NAME"
echo "Bundler host: $RUBY_HOST"
