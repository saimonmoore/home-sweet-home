# home-sweet-home (personal)

Dotfiles for my macOS host plus an isolated Ubuntu LTS dev VM. The
host is intentionally minimal: Homebrew, chezmoi, the `,*` helper
scripts, a curated set of GUI casks, and `nb` for notes. All
development — editor, language runtimes, LSPs, git tooling — lives
inside the VM.

---

## One-line install on a fresh Mac

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/saimonmoore/home-sweet-home/main/bootstrap/host/install.sh)
```

Idempotent — safe to re-run.

---

## Prerequisites

Before running the installer:

1. **macOS Sonoma or newer** on an Apple Silicon Mac. `install.sh`
   refuses to run elsewhere.
2. **Xcode Command Line Tools** — the Homebrew install in
   `install.sh` will trigger the CLT installer if missing. Click
   through it when prompted and re-run if needed.
3. **Backed-up SSH keys** reachable from the new machine (iCloud,
   external drive, password manager, etc.). After the installer
   finishes you'll copy this into `~/.ssh/`:
   - `id_ed25519_personal` (+ `.pub`) — primary personal GitHub
     identity, signing key.
4. **A few chezmoi prompt answers** ready:
   - Git author name + email
   - Personal GitHub username (`saimonmoore`)
   - Whether this machine will be used for `develop` (`no` for the
     host, `yes` inside the VM later)
   - Whether you want `opencode` installed

---

## What the installer does

1. Installs Homebrew (non-interactive) if missing.
2. Installs `chezmoi` via Homebrew.
3. `chezmoi init --apply saimonmoore/home-sweet-home` which:
   - Renders every templated dotfile into `$HOME`.
   - Fires `run_once_after_host-brew-bundle.sh.tmpl` → runs
     `brew bundle` against `bootstrap/host/Brewfile` (installs the
     curated brew formulae and 39 GUI casks).
   - Fires `run_once_after_nb-notebooks-bootstrap.sh.tmpl` → clones
     the `home` nb notebook into `~/.nb/home`.
   - Drops `~/Desktop/home-sweet-home.md` (a daily-use quick
     reference).
4. Runs `,verify` so you see a colour-coded pass/fail summary before
   the next-steps instructions print.

The Homebrew bundle step can take a while on first run and will
occasionally pause for macOS to ask permission for a cask install
(accessibility, input monitoring, etc.). Approve and let it resume.

---

## Post-install

1. **Open a new terminal.** Shell PATH changes and integrations load
   on shell start, not mid-session.
2. **Drop your SSH key into `~/.ssh/`:**
   ```bash
   chmod 700 "$HOME/.ssh"
   cp <backup>/id_ed25519_personal     "$HOME/.ssh/"
   cp <backup>/id_ed25519_personal.pub "$HOME/.ssh/"
   chmod 600 "$HOME/.ssh"/id_ed25519_personal
   chmod 644 "$HOME/.ssh"/id_ed25519_personal.pub
   ```
   Confirm with `,verify`.
3. **Create the dev VM:** `,create-vm`. This provisions lima with the
   Ubuntu LTS template defined in `lima/dev-ubuntu.yaml`.
4. **Open the VM:** `,dev`.
5. **Bootstrap `dev` inside the VM** (one time):
   ```bash
   mkdir -p "$HOME/.ssh"
   chmod 700 "$HOME/.ssh"
   ssh-keygen -q -t ed25519 -N '' -C "dev@dev" -f "$HOME/.ssh/id_ed25519"
   chezmoi init --apply saimonmoore/home-sweet-home
   mise install
   chezmoi apply
   ```
   Answer `develop=yes` and use the same identity as on the host.
6. **Manual installs** from `ADAPTING.md` → *Manual installs*
   section: Guitar Pro 7, Hofmann, Paseo.

---

## Verify

`,verify` on the host checks:

- Homebrew, chezmoi, git installed
- Spot-check of Brewfile CLIs (`eza`, `fzf`, `ripgrep`, `fd`,
  `lazygit`, `lima`, `gh`, `jq`, `bat`, `nb`)
- `chezmoi status` — no pending changes
- Git aliases loaded (`git pam` et al.) + `commit.gpgsign = true`
- `~/.ssh/config` references `id_ed25519_personal` and the key file
  is present
- `~/.nb/home` is a real git repo
- lima dev VM exists
- `~/Desktop/home-sweet-home.md` is in place

Exits non-zero on any hard failure so you can wire it into scripts or
CI.

---

## Daily use

See `~/Desktop/home-sweet-home.md` — that's where the real cheatsheet
lives now. Short version:

- `,dev` enters the dev VM shell (a zellij session).
- `,cheatsheet` prints the full terminal-tool keybinding reference.
- `,chezmoi-update` pulls this repo and applies.
- `,verify` re-runs the health check.

Daily commands, VM networking, the terminal IDE stack, and `nb`
basics are all covered on the Desktop README.

---

## Manual chezmoi init (without the one-liner)

```bash
# Install Homebrew (https://brew.sh) yourself, then:
brew install chezmoi
chezmoi init --apply saimonmoore/home-sweet-home
```

`chezmoi` can read this repo directly from GitHub because the repo
root has `.chezmoiroot` pointing at `chezmoi/`.

---

## OpenCode browser auth in the VM

OpenCode's browser auth redirects back to `localhost` on the machine
that started `opencode`. When it runs inside the VM, the final
browser redirect therefore fails on the host. The working flow:

1. Run `/connect` inside `opencode` in the VM.
2. Complete the browser login on the host.
3. When the browser lands on the failing `http://localhost:...`
   callback URL, copy that full URL.
4. Back in the VM: `curl '<paste-the-final-localhost-url-here>'`.

That delivers the auth callback to the OpenCode process running
inside the VM.

---

## Troubleshooting

- **`,verify` reports failures** → it names what's missing. Usually
  the fix is `chezmoi apply` or `brew bundle --file
  ~/.local/share/chezmoi/bootstrap/host/Brewfile` in a fresh shell.
- **`chezmoi status` non-empty** → `chezmoi diff` to inspect, then
  `chezmoi apply`. If the diff shows changes you didn't make,
  probably a drift from `,chezmoi-update`.
- **VM won't start** → `limactl stop dev; limactl delete dev;
  ,create-vm`. VMs from before the vzNAT change need this recreate.
- **Cask install hung on permission prompt** → re-run `brew bundle`
  after approving; casks are idempotent.
- **`chezmoi init` with username-only shorthand resolves elsewhere**
  → always use `saimonmoore/home-sweet-home` explicitly.

---

## Other references

- `ADAPTING.md` — customization guide: every prompt, every gate,
  manual-install catalog, opinionated choices at a glance.
- `bootstrap/host/Brewfile` — the full host manifest.
- `bootstrap/host/install.sh` — the one-line installer (you can read
  it end-to-end in <100 lines).
