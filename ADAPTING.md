# Adapting home-sweet-home

This guide documents the original author's (saimonmoore) choices across
this dotfiles repo and points out exactly what to change to tailor it to your
own preferences. Work through sections top-down; each builds on the last.

## Mental model

Two managers drive everything:

- **chezmoi** — renders dotfiles from `chezmoi/` into `$HOME` on every machine.
  `.chezmoiroot` (at repo root) points chezmoi at the `chezmoi/` subdirectory
  so `chezmoi init --apply <user>/home-sweet-home` works directly.
- **lima** — boots an Ubuntu LTS VM on the macOS host using `lima/dev-ubuntu.yaml`.
  The VM is where *all* development happens; the host stays minimal.

The repo is split into three top-level folders:

| Folder        | Purpose                                                      |
|---------------|--------------------------------------------------------------|
| `chezmoi/`    | Templated dotfiles (zsh, Zellij, Yazi, Lazygit, etc.) |
| `bootstrap/`  | One-shot scripts: `host/` (Brewfile) and `vm/` (VM create, JFrog sync) |
| `lima/`       | Lima VM definition (`dev-ubuntu.yaml`) and provisioning (`dev-ubuntu-system.sh`) |

`.chezmoiscripts/` under `chezmoi/` holds `run_once` / `run_after` hooks that
fire from chezmoi based on template conditions.

## Identity & chezmoi prompts

On first `chezmoi init`, you answer a few questions that become template
variables used throughout the repo. See `chezmoi/.chezmoi.toml.tmpl`.

| Prompt                       | Variable                   | Effect                                                    |
|------------------------------|----------------------------|-----------------------------------------------------------|
| Is this the Linux dev VM?    | `develop`                  | Gates the full VM/editor toolchain (Neovim, Zellij, mise tools). macOS host: `no`; Ubuntu dev VM: `yes`. |
| Git author name / email      | `name`, `email`            | Written into `dot_gitconfig.tmpl`                         |
| GitHub username              | `github_username`          | `[github] user =` and `,ghclone` target layout            |

Taskwarrior is also conditional (`needs_taskwarrior`) — check the template
for the exact prompt set.

**Host answers:** `develop=no`.
**VM answers:** `develop=yes`, same identity.

**To adapt:** edit `chezmoi/.chezmoi.toml.tmpl` to rename/remove prompts, then
update every `.tmpl` file that branches on the removed variable. The easiest
way to find them is `grep -r '{{ \.<var_name>' chezmoi/`.

## Host vs VM split

Almost every template gate is either `.develop` or `.chezmoi.os`. The
ignore list in `chezmoi/.chezmoiignore.tmpl` is the source of truth for
which files land where:

- Host-only (when `develop=false`) skips `.local/bin/,dev`, `,create-vm`,
  `,sync-jfrog-to-vm`, most editor/IDE tools.
- VM-only skips `.ssh/config`, `.npmrc`, `.yarnrc*`, the `Library/` folder,
  the `05_homebrew` zsh rc.
- `needs_taskwarrior=false` removes `dot_taskrc*` and `,task-popup`.

If you want a different split (e.g., Neovim on the host too), flip the
relevant entries in `.chezmoiignore.tmpl` and re-apply.

## The Lima VM

Defined in `lima/dev-ubuntu.yaml`:

- **Distro:** Ubuntu LTS via `template:ubuntu-lts` (vzNAT, vz VMType — native on Apple Silicon)
- **Resources:** 6 CPUs, 6 GiB RAM, 60 GiB disk
- **User:** `dev` with login shell `/usr/bin/zsh`
- **Mounts:** none (intentional — keeps host/VM cleanly separated)
- **Containerd:** disabled (podman installed instead)
- **Networking:** vzNAT; localhost-bound ports auto-forward to host; 0.0.0.0 services reached via `,vm-ip`

`lima/dev-ubuntu-system.sh` provisions via `apt-get`: git, curl, zsh,
zsh-autosuggestions, openssh-client, podman, podman-compose, uidmap,
ripgrep, fd-find, bat, eza, zoxide, fzf, jq, tar, unzip, gzip, and
build-essential. `chezmoi`, `helm`, and `mise` are not in the default Ubuntu
repositories, so they're installed from their upstream install scripts.

Because Ubuntu ships `fd-find` as `fdfind` and `bat` as `batcat`, the
provisioning script symlinks `/usr/local/bin/fd` → `/usr/bin/fdfind` and
`/usr/local/bin/bat` → `/usr/bin/batcat` so the zsh aliases
(`cat=bat`, `ff='fd --glob'`) work unchanged.

**Common adaptations:**

| Change                  | File / line                                                    |
|-------------------------|----------------------------------------------------------------|
| Swap distro             | `lima/dev-ubuntu.yaml` (base template) + rewrite provisioning apt commands in `lima/dev-ubuntu-system.sh` |
| Change resources        | `cpus`, `memory`, `disk` in `dev-ubuntu.yaml`                  |
| Add host mounts         | `mounts:` list in `dev-ubuntu.yaml` (empty by default)         |
| Different VM name       | Pass `--name` to `,create-vm`; update `,dev`, `,vm-ip`, `,vm-open`, `,sync-jfrog-to-vm` scripts if you want a different default |
| Different default shell | `user.shell` in `dev-ubuntu.yaml` and the `chsh` step          |

Existing VMs predating the vzNAT change need a one-off network reset — see
the README.

## Shell environment (zsh)

Entrypoint: `chezmoi/dot_zshrc` sources every file in `~/.config/zsh/rc.d/`.
All rc fragments live in `chezmoi/dot_config/zsh/rc.d/`:

| File                 | Role                                                  |
|----------------------|-------------------------------------------------------|
| `00_init`            | shell options, history, PATH, EDITOR=nvim, truecolor  |
| `10_tools`           | mise activate, starship, fzf, zoxide, eza/bat aliases, zsh-autosuggestions |
| `20_apps`            | short aliases: `g=lazygit`, `e=yazi`, `t=task`, …     |
| `05_homebrew.tmpl`   | host only (Homebrew path)                             |
| `20_jfrog.tmpl`      | exports JFrog creds if synced                         |
| `20_opencode`        | opencode bootstrap (if enabled)                       |

The prompt is **starship** (`chezmoi/dot_config/starship.toml.tmpl`) with a
yellow `[VM]` badge and `dev>` prompt inside the VM, green `>` on the host.

### The `,`-prefixed command convention

Custom scripts live in `chezmoi/dot_local/bin/executable_,*` and use a
leading comma so they cluster together in completion and never collide with
system binaries. Inventory:

| Command               | Purpose                                                  |
|-----------------------|----------------------------------------------------------|
| `,dev`                | attach/create the zellij session inside the VM           |
| `,create-vm`          | bootstrap the Ubuntu VM via limactl                      |
| `,vm-ip`              | print the VM's lima0 IPv4 address                        |
| `,vm-open [PORT]`     | open `http://<vm-ip>[:PORT]` in the host browser         |
| `,chezmoi-init`       | `chezmoi apply`                                          |
| `,chezmoi-update`     | `chezmoi update`                                         |
| `,zlayout <name>`     | open new zellij tab with a layout (`default`/`dev`/`dev-agentic`) |
| `,zdev`, `,zagent`    | shortcuts for the dev / dev-agentic layouts              |
| `,zj [name]`          | attach/create a zellij session (default "local")         |
| `,ghclone owner/repo` | clone into `~/code/github/owner/repo` via SSH            |
| `,ghotspots`          | top 20 most-edited files in the last year                |
| `,gauthors`           | commit count by author                                   |
| `,gbugs`              | commits mentioning "fix/bug/broken" grouped by file      |
| `,gfire`              | commits mentioning "revert/hotfix/emergency/rollback"    |
| `,gbranches`          | branches sorted by most recent commit                    |
| `,gactivity`          | commits grouped by month                                 |
| `,sync-jfrog-to-vm`   | copy JFrog OIDC creds from host into the VM              |
| `,cheatsheet`         | display the terminal-tool keybinding reference           |
| `,task-popup`         | taskwarrior popup (if enabled)                           |

To rename the prefix (e.g., `.` or `w-`), rename every file under
`dot_local/bin/` *and* update internal cross-references — several scripts
call each other by name (`,dev` invokes `,zj`, etc.). A `grep -l ',dev' chezmoi/`
will find them.

## Terminal IDE stack

The editor story is **Neovim (LazyVim) + Zellij + Lazygit + Yazi + Scooter**.
Zellij, Lazygit, Yazi, and Scooter all ship Catppuccin Mocha themes managed
from this repo; Neovim pulls its theme from LazyVim's defaults (easy to swap).

### Neovim / LazyVim

- Binary: installed via mise (`neovim = "stable"`) on develop machines only.
- Config: **not** in chezmoi — cloned from [LazyVim/starter](https://github.com/LazyVim/starter)
  on first apply by `chezmoi/.chezmoiscripts/run_after_nvim-lazyvim-bootstrap.sh.tmpl`.
  The script skips if `~/.config/nvim` already exists and is non-empty, so
  it's safe to re-run `chezmoi apply`.
- Open `nvim` once after bootstrap so `lazy.nvim` installs plugins and
  treesitter parsers.
- Customize `~/.config/nvim` directly. If you later want chezmoi to track
  your tweaks, `chezmoi add ~/.config/nvim` and commit.

Integrations wired around nvim:

- `EDITOR=nvim`, `VISUAL=nvim` (`dot_config/zsh/rc.d/00_init`)
- Yazi opens files in nvim (`dot_config/yazi/yazi.toml`)
- Scooter opens matches with `nvim +<line> <file>` (`dot_config/scooter/config.toml`)
- Lazygit `editPreset: nvim` (`.chezmoitemplates/lazygit/config.yml`)
- Zellij `scrollback_editor "nvim"` and pane commands in `dev.kdl` /
  `dev-agentic.kdl` layouts

To switch to a different editor: replace `nvim` in the above touchpoints and
either swap the LazyVim bootstrap script for a different config provisioner,
or drop the bootstrap script entirely and bring your own config.

### Zellij

- Config: `chezmoi/dot_config/zellij/config.kdl.tmpl`
- Layouts in `chezmoi/dot_config/zellij/layouts/`:
  - `default.kdl` — single focused pane
  - `dev.kdl` — Neovim 70% / shell 30%
  - `dev-agentic.kdl` — Neovim 70% / opencode 30%
- Uses locked-mode workflow (Alt+Shift combos); see `,cheatsheet` for the full
  map. Floating helpers: `Alt+Shift+g` lazygit, `Alt+Shift+r` scooter,
  `Alt+Shift+e` yazi.

Add your own layout by dropping a new `.kdl` next to the existing ones —
`,zlayout <name> [zoxide-args]` will pick it up.

### Yazi

- Config: `chezmoi/dot_config/yazi/yazi.toml`
- Hidden files on, Neovim as editor, Catppuccin Mocha flavor in
  `flavors/catppuccin-mocha.yazi/`.

### Lazygit & Scooter

- Lazygit config lives at `chezmoi/dot_config/lazygit/config.yml.tmpl` with a
  macOS-specific copy under `chezmoi/Library/Application Support/lazygit/`
  (Linux uses `dot_config`, ignored on macOS by chezmoiignore).
- Scooter: config at `chezmoi/dot_config/scooter/config.toml`, theme at
  `themes/Catppuccin Mocha.tmTheme`.

### Changing the color scheme

Catppuccin Mocha is applied in at least six places. Swapping palettes means
editing: starship.toml, yazi flavor, scooter theme, dir_colors, and the
taskrc.d theme. Neovim's theme comes from LazyVim defaults — swap in nvim
config directly. Easiest path: fork the existing files and do a global
find/replace on color hex values.

## Languages & tooling (mise)

mise (<https://mise.jdx.dev>) is the single source of truth for language/tool
versions. Config at `chezmoi/dot_config/mise/config.toml.tmpl`.

Always installed: `starship`, optional `opencode`, optional `taskwarrior` +
`taskwarrior-tui`.

On development machines (`develop=true`) the list expands to: `neovim`
(stable), `bun`, `go`, `ruby`, `node` (LTS), `rust` (stable), plus IDE tools
(`yazi`, `lazygit`, `zellij`, `delta`, `golangci-lint`, `prettier`,
`emmet-ls`, `scooter`, `shfmt`, `yq`), and language servers (`gopls`,
`gofumpt`, `dlv`, `ruby-lsp`, `rufo`, `yaml-language-server`,
`bash-language-server`, `vscode-langservers-extracted`,
`dockerfile-language-server`, `compose-language-service`).

To add/remove: edit the tool list in the template. To pin versions, use
mise's `version = "x.y.z"` syntax.

### JFrog credentials sync

Optional; set up for private artifact-registry access in the dev VM.

1. Credentials live in 1Password on the host; `,jfrog_oidc_env` exports
   `JFROG_OIDC_USER` / `JFROG_OIDC_TOKEN`.
2. `,sync-jfrog-to-vm --host <jfrog-host>` (driven by
   `bootstrap/vm/sync-jfrog.sh`) writes `~/.config/home-sweet-home/jfrog-oidc.env`
   inside the VM with the env vars plus a `BUNDLE_<host>` variable for
   Bundler (Ruby gems hosted on private JFrog repos).
3. `dot_config/zsh/rc.d/20_jfrog.tmpl` sources that file on every VM shell,
   so Bundler/CLI tools see the credentials automatically.

If you don't use JFrog, delete `bootstrap/vm/sync-jfrog.sh`,
`,sync-jfrog-to-vm`, and `20_jfrog.tmpl`. If you use a different private
repo, the flow is a reasonable template — keep the shape, swap the URL and
credential sources.

### Notes (`nb`)

`nb` (https://github.com/xwmx/nb) is the host-side notes CLI. Installed
via `xwmx/taps/nb` in `bootstrap/host/Brewfile`, with `~/.nbrc` tracked
as `chezmoi/dot_nbrc`.

The `chezmoi/.chezmoiscripts/run_once_after_nb-notebooks-bootstrap.sh.tmpl`
hook runs on macOS hosts (`develop=false`) and, if `~/.nb/home` is not
already a git repo, clones `git@github.com:saimonmoore/nb.git` into it.
Re-runs are no-ops once the notebook is present.

If you don't use `nb`, delete the Brewfile line, the bootstrap script,
and `chezmoi/dot_nbrc`.

## AI coding harnesses

Both `opencode` and `claude` (Claude Code) are installed
unconditionally — `opencode` via Homebrew on the host and mise in the
VM; `claude` via the `claude-code` cask on the host and
`npm:@anthropic-ai/claude-code` via mise in the VM.

A chezmoi-managed shim (`chezmoi/dot_local/bin/executable_,agent`)
reads a selection from `~/.config/home-sweet-home/agent` (set with
`,agent-select`) and exec's the chosen binary. The `dev-agentic`
zellij layout runs `,agent` in its right pane, so `,zagent` always
opens whichever harness is currently selected. See README "AI coding
harnesses" for the switching UX and how to add new harnesses.

`chezmoi/dot_config/opencode/opencode.json.tmpl` stays chezmoi-managed
for opencode's own config (model, auth, permissions). The previously
shipped `AGENTS.md`, `commands/`, and `skills/` directories under
`dot_config/opencode/` were removed; skills now live centrally in
`~/.agent/skills/` and are managed by openskills (see below).

**VM browser-auth gotcha** is documented in the README: finish the browser
login on the host, copy the failing `http://localhost:…` URL, `curl` it from
inside the VM to complete the OAuth callback.

## Agent skills (`openskills`)

`~/.agent/skills/` is the single source of truth for skills available
to every harness. [openskills](https://github.com/numman-ali/openskills)
installs skills there (`--universal` mode) and writes an origin
`.openskills.json` alongside each skill.

This repo commits the shape, not the content:

- `chezmoi/dot_agent/openskills-manifest.txt` — plain list of skill
  names this machine should have.
- `chezmoi/dot_agent/skills/<name>/create_dot_openskills.json` — the
  origin metadata. `create_` prefix so chezmoi drops it once and
  openskills can then refresh it without producing apply drift.

The `run_after_agent-skills-bootstrap.sh.tmpl` hook reconciles disk
state against the manifest on every apply: installs each unique
source, prunes dirs whose names aren't in the manifest, and
regenerates `~/.agent/AGENTS.md` via `openskills sync`. `npx` + `jq`
are the runtime requirements — both come in via the Brewfile on the
host and mise in the VM.

To add a skill:

1. `npx openskills install <source> --universal`
2. `chezmoi add ~/.agent/skills/<name>/.openskills.json`
3. Add the skill name to `chezmoi/dot_agent/openskills-manifest.txt`
4. Commit.

To remove a skill: drop its line from the manifest and `chezmoi rm`
its `.openskills.json` file. The hook prunes on next apply.

## Writing chezmoi hooks that need mise-managed tools

chezmoi hooks run as bash subshells that inherit PATH from the shell
that invoked `chezmoi apply`. Inside the dev VM, mise-managed tools
(`npx`, `node`, `nvim`, `go`, `ruby`, `rust`, `prettier`, `yq`,
`shfmt`, language servers) live under `~/.local/share/mise/installs/`
and are only reachable via `~/.local/share/mise/shims/`, which mise
puts on PATH **only when the shell has been activated** (via the
managed zshrc). A pre-existing shell that ran `mise install` but
wasn't restarted doesn't yet see those tools — and neither do
chezmoi's hook subshells inheriting from it.

If a new hook needs a mise-managed tool, make it self-sufficient by
prepending the shims dir yourself near the top:

```bash
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
fi
```

Shims work without activation — they're thin dispatchers. This is
what `run_onchange_after_openskills-bootstrap.sh.tmpl` already does
for `npx`. Hooks that only need system tools (`git`, `apt-get`,
`brew`, `nb`, `jq`) don't need the snippet.

## Git

`chezmoi/dot_gitconfig.tmpl` sets:

- Identity and signing key (ed25519 everywhere; distinct keys per context)
- SSH GPG signing, `osxkeychain` helper on the host
- URL rewrite inside the VM mapping `https://github.com/` to the SSH form
- `push.default = current`, `push.autoSetupRemote = true`,
  `pull.rebase = false`, `init.defaultBranch = main`
- Editor = `nvim`
- A curated alias set covering log/status/commit/fixup helpers and a
  `pam*` family of fzf-driven pickers. `[help] autocorrect`, `[rebase]
  autosquash`, and `[rerere] enabled` are turned on.

The `,g*` diagnostics scripts are standalone bash and portable as-is.

## Taskwarrior (optional)

`dot_taskrc.tmpl` stores data at `~/Documents/tasks` and applies a
Catppuccin Mocha Black theme. Custom urgency coefficients bias `+bug`,
`+security`, `+problem` up and `+maybe`, `+someday`, `+later` down.

## macOS host specifics

- Brewfile: `bootstrap/host/Brewfile`. Runs via
  `run_once_after_host-brew-bundle.sh.tmpl` only when
  `develop=false AND darwin`.
- Terminal emulator: WezTerm (brew cask). Config at
  `chezmoi/dot_config/wezterm/wezterm.lua`.
- Lazygit's macOS config lives under `chezmoi/Library/Application Support/`
  via chezmoi's Library handling.

To trim or extend the host brew set, edit `bootstrap/host/Brewfile`
directly. The `run_once_after_host-brew-bundle.sh.tmpl` hook runs
`brew bundle` against that file on every macOS host apply.

## Manual installs

Apps that don't automate cleanly via Homebrew or `mas`. Install these
by hand on a fresh macOS host after `bootstrap/host/install.sh`
finishes.

**No cask / no MAS entry:**
- Guitar Pro 7 — the `guitar-pro` cask is v8+; install v7 manually
  from your license.
- Hofmann — install from vendor site.
- Paseo — install manually.

**Built-in / bundled (no action needed):**
- Safari, Utilities folder, Chrome Apps.localized — preinstalled or
  auto-created by Chrome.
- iTermAI, iTermBrowserPlugin — enabled from within iTerm2
  preferences.
- Proton Mail Uninstaller — ships alongside Proton Mail.
- Claude Code URL Handler — installed by the Claude Code CLI.

## Bootstrap scripts

`bootstrap/host/`:
- `Brewfile` — brew bundle manifest

`bootstrap/vm/`:
- `macos-create-ubuntu.sh` — `limactl start` driven by `lima/dev-ubuntu.yaml`
- `sync-jfrog.sh` — JFrog creds into the VM

chezmoi run hooks (in `chezmoi/.chezmoiscripts/`):
- `run_once_after_host-brew-bundle.sh.tmpl` — macOS host only
- `run_after_nvim-lazyvim-bootstrap.sh.tmpl` — develop machines; clones LazyVim starter if `~/.config/nvim` is empty
- `run_after_taskwarrior-linux.sh.tmpl` — Linux taskwarrior

## Opinionated choices at a glance

| Choice                         | Keep, swap, or remove?                          |
|--------------------------------|-------------------------------------------------|
| chezmoi as dotfile manager     | Keep unless you really prefer stow/yadm         |
| Ubuntu LTS on Lima             | Swap distro in `lima/dev-ubuntu.yaml` if you want Fedora/Arch/NixOS |
| `,`-prefix for custom commands | Rename all at once if you dislike it            |
| Neovim + LazyVim as editor     | Swap for Helix/Emacs/etc; replace `nvim` in zsh/git/yazi/scooter/zellij/lazygit + LazyVim bootstrap script |
| Catppuccin Mocha everywhere    | Replace in five config files (Zellij, Yazi, Scooter, starship, taskrc); nvim theme is set by LazyVim |
| mise for language versions     | Keep — it's already doing asdf's job and more   |
| Zellij + layouts               | Keep or swap for tmux (you'd rewrite `,zlayout`, `,zdev`, `,zagent`) |
| OpenCode as AI agent           | Fully opt-in                                    |
| Taskwarrior                    | Fully opt-in                                    |
| JFrog credentials sync         | Optional; drop if you don't use a private artifact registry |
| `nb` notes + notebook sync     | Optional; drop the Brewfile line, bootstrap script, and `dot_nbrc` |
| VM `~/code` repo layout        | Change in `,ghclone` if you want a flat layout  |
| No VM mounts                   | Add `mounts:` in `dev-ubuntu.yaml` if you want shared code with the host |
| zsh only                       | Swap means rewriting every file in `dot_config/zsh/rc.d/` |

## Recommended adaptation order

1. Fork, update `README.md` to point at your repo, and change `.chezmoiroot`
   references only if you restructure directories.
2. Walk through `chezmoi/.chezmoi.toml.tmpl` — keep/remove prompts first so
   everything downstream has stable variables.
3. Update `chezmoi/.chezmoiignore.tmpl` to match any new host/VM split.
4. Edit `lima/dev-ubuntu.yaml` for your resources/distro.
5. Trim/extend `bootstrap/host/Brewfile` and the mise config.
6. Rename `,`-prefixed commands (or don't).
7. Replace the color scheme (or don't).
8. Swap the editor (big surgery — do last).

Reapply iteratively with `,chezmoi-init` on both host and VM. Start with
`develop=no` on the host, spin up the VM, then iterate from inside it.
