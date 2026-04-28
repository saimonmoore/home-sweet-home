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
- Spot-check of Brewfile CLIs (`eza`, `fzf`, `rg` (from ripgrep), `fd`,
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

### Moving files between host and VM

Use `,vm-cp` for one-off copies and `,vm-rsync` for larger or
repeated syncs.

`vm:` prefixes a path inside the Lima guest. Paths without that
prefix are on the macOS host.

Quick copy with `,vm-cp`:

```bash
,vm-cp ./notes.md vm:~/notes.md      # host -> VM
,vm-cp vm:~/build.log ./             # VM -> host
,vm-cp -r ./dist vm:~/deploy         # recursive push
,vm-cp -r vm:~/code/myproj ./myproj  # recursive pull
```

This wraps `limactl copy`, so it's the easiest choice for a single
file or a small directory.

Incremental sync with `,vm-rsync`:

```bash
,vm-rsync -avz --progress ./src/ vm:~/dest/
,vm-rsync -avz --delete ./src/ vm:~/dest/
,vm-rsync --dry-run -avz ./src/ vm:~/dest/
,vm-rsync -avz vm:~/code/myproj/ ./myproj/
```

Use `,vm-rsync` when you want rsync features like `--dry-run`,
`--delete`, `--exclude`, resumable transfers, or fast repeated syncs
of a large tree.

---

## AI coding harnesses

The `,zagent` zellij layout opens a `,agent` pane, which routes to
whichever AI coding harness is currently selected. Switch at any time
with `,agent-select`.

### Installed harnesses (personal fork)

- **opencode** — installed unconditionally, both on the host via the
  Brewfile (`brew "opencode"`) and inside the dev VM via mise
  (`opencode = "latest"`).
- **codex** — installed on the host via `cask "codex"` and in the VM
  via mise (`"npm:@openai/codex" = "latest"`).
- **claude** (Claude Code) — installed on the host via
  `cask "claude-code"` and in the VM via mise
  (`"npm:@anthropic-ai/claude-code" = "latest"`).

All three are available. The shim just decides which one launches
when you invoke `,agent`.

### Switching

```bash
,agent-select              # show the current selection + availability of each
,agent-select codex        # persist a selection (sticks across shells)
,agent-select claude       # persist a selection (sticks across shells)
,agent-select --clear      # drop the persistent selection; ,agent falls back to opencode
```

One-shot override without persisting:

```bash
AGENT_HARNESS=claude ,agent
```

`,zagent` always honours whatever `,agent-select` currently says.

### Adding a new harness

1. **Install its CLI.** Add a line to `bootstrap/host/Brewfile`
   (macOS host) and/or `chezmoi/dot_config/mise/config.toml.tmpl`
   (dev VM) — e.g. `"npm:@some-org/foo-agent" = "latest"`.
2. **Register the binary name.** Append it to `KNOWN_HARNESSES`
   near the top of `chezmoi/dot_local/bin/executable_,agent-select`.
3. `chezmoi apply`.

### Skills (`openskills`)

Agent skills live centrally in `~/.agent/skills/` and are managed by
[openskills](https://github.com/numman-ali/openskills). This repo
commits:

- `chezmoi/dot_agent/openskills-manifest.txt` — the list of skill
  names this machine should have.
- `chezmoi/dot_agent/skills/<name>/.openskills.json` — the origin
  metadata openskills needs to fetch each skill.

After every `chezmoi apply`, the
`run_onchange_after_openskills-bootstrap.sh.tmpl` hook reconciles disk state
against the manifest:

1. reads the unique `source` values from the committed
   `.openskills.json` files,
2. runs `npx openskills install <source> --universal` for each,
3. prunes any skill dir on disk whose name is not in the manifest,
4. regenerates `~/.agent/AGENTS.md` via `npx openskills sync`,
5. refreshes `~/.agents/skills` to point at `~/.agent/skills` so
   Codex sees the same installed skills.

Run it manually with `chezmoi apply` or just `npx openskills install
<source> --universal` for ad-hoc additions — then `chezmoi add
~/.agent/skills/<name>/.openskills.json` and update the manifest to
persist the change.

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

## OAuth browser auth in the VM

Every OAuth-based harness (codex, opencode, claude-code) spins up a
local HTTP listener on `127.0.0.1:<port>` and redirects the browser
to it after login. When the harness runs in the VM, the host browser
can't reach that listener, so the redirect lands on a connection
error. **No port forwarding needed** — the callback URL's query
string carries the token, so hitting the URL from inside the VM
completes the flow.

Recipe:

1. Start login in the VM. Depending on harness:
   - codex: `codex login` (or just run `codex` / `,agent` and follow
     the prompt on first use).
   - opencode: `/connect` inside an opencode session.
   - claude-code: `/login` inside claude-code (or first run).

   The harness prints an auth URL.
2. Open the URL on the host Mac and complete sign-in.
3. The browser redirects to `http://localhost:<port>/callback?...`
   and shows a connection error. **Copy the full URL from the
   address bar.**
4. In any VM shell (a new zellij pane, `,dev` in another tab, etc.):

   ```bash
   curl '<paste-the-full-localhost-url-here>'
   ```

The harness's listener inside the VM receives the callback and
finishes auth.

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
- **`git pull` / `git push` hangs inside the VM** → on some
  host/VPN/Wi-Fi paths, PMTU discovery breaks for Lima's `lima0`
  interface and SSH stalls at `expecting SSH2_MSG_KEX_ECDH_REPLY`.
  Fresh VMs now install a boot-time fix that sets `lima0` to MTU
  1280. Existing VMs can apply the same workaround immediately with
  `sudo ip link set dev lima0 mtu 1280`, then either recreate the VM
  with `,create-vm` or install the same change permanently.
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
