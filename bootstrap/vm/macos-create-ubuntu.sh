#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "Error: bootstrap/vm/macos-create-ubuntu.sh must be run on macOS." >&2
	exit 1
fi

if ! command -v limactl >/dev/null 2>&1; then
	echo "Error: limactl is required but was not found on PATH." >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTANCE_NAME="dev"
CONTEXT="work"
TEMPLATE_PATH="$REPO_ROOT/lima/dev-ubuntu.yaml"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--name)
		INSTANCE_NAME="$2"
		shift 2
		;;
	--context)
		CONTEXT="$2"
		shift 2
		;;
	-h | --help)
		echo "Usage: bootstrap/vm/macos-create-ubuntu.sh [--name dev] [--context work]"
		exit 0
		;;
	*)
		echo "Error: unknown argument '$1'." >&2
		exit 1
		;;
	esac
done

if [[ "$CONTEXT" != "work" ]]; then
	echo "Error: only context=work is implemented right now." >&2
	exit 1
fi

if [[ ! -f "$TEMPLATE_PATH" ]]; then
	echo "Error: Lima template not found: $TEMPLATE_PATH" >&2
	exit 1
fi

if limactl list | awk 'NR > 1 { print $1 }' | grep -Fxq "$INSTANCE_NAME"; then
	echo "Error: Lima instance '$INSTANCE_NAME' already exists." >&2
	exit 1
fi

limactl start --name="$INSTANCE_NAME" "$TEMPLATE_PATH"

echo "Ubuntu VM '$INSTANCE_NAME' created."
echo "Dev shell:   limactl shell --tty --reconnect --workdir /home/dev --shell /usr/bin/zsh $INSTANCE_NAME"
echo "Then run chezmoi init --apply saimon-moore/home-sweet-home as dev."
