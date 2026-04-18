# Adapting home-sweet-home

This guide documents the original author's (david-krentzlin) choices across
this dotfiles repo and points out exactly what to change to tailor it to your
own preferences. Work through sections top-down; each builds on the last.

## Mental model

Two managers drive everything:

- **chezmoi** — renders dotfiles from `chezmoi/` into `$HOME` on every machine.
  `.chezmoiroot` (at repo root) points chezmoi at the `chezmoi/` subdirectory
  so `chezmoi init --apply <user>/home-sweet-home` works directly.
- **lima** — boots a Fedora VM on the macOS host using `lima/dev-fedora.yaml`.
  The VM is where *all* development happens; the host stays minimal.

The repo is split into three top-level folders:

| Folder        | Purpose                                                      |
|---------------|--------------------------------------------------------------|
| `chezmoi/`    | Templated dotfiles (zsh, Zellij, Yazi, Lazygit, etc.) |
| `bootstrap/`  | One-shot scripts: `host/` (Brewfile) and `vm/` (VM create, JFrog sync, Scala setup) |
| `lima/`       | Lima VM definition (`dev-fedora.yaml`) and provisioning (`dev-fedora-system.sh`) |

`.chezmoiscripts/` under `chezmoi/` holds `run_once` / `run_after` hooks that
fire from chezmoi based on template conditions.

## Identity & chezmoi prompts

On first `chezmoi init`, you answer a few questions that become template
variables used throughout the repo. See `chezmoi/.chezmoi.toml.tmpl`.

| Prompt                       | Variable                   | Effect                                                    |
|------------------------------|----------------------------|-----------------------------------------------------------|
| Will you develop on this machine? | `develop`             | Gates the full VM/editor toolchain (Neovim, Zellij, mise tools) |
| Will you need opencode?      | `needs_opencode`           | Installs opencode via mise, adds opencode zsh rc + config |
| Git author name / email      | `name`, `email`            | Written into `dot_gitconfig.tmpl`                         |
| GitHub username              | `github_username`          | `[github] user =` and `,ghclone` target layout            |
| Work username                | `work_username`            | Gates work-specific config (JFrog, Brewfile, URL rewrites) |

Taskwarrior is also conditional (`needs_taskwarrior`) — check the template
for the exact prompt set.

**Host answers:** `develop=no`, `needs_opencode=no`.
**VM answers:** `develop=yes`, opencode as you prefer, same identity.

**To adapt:** edit `chezmoi/.chezmoi.toml.tmpl` to rename/remove prompts, then
update every `.tmpl` file that branches on the removed variable. The easiest
way to find them is `grep -r '{{ \.work_username' chezmoi/`.

## Host vs VM split

Almost every template gate is either `.develop` or `.chezmoi.os`. The
ignore list in `chezmoi/.chezmoiignore.tmpl` is the source of truth for
which files land where:

- Host-only (when `develop=false`) skips `.local/bin/,dev`, `,create-vm`,
  `,sync-jfrog-to-vm`, most editor/IDE tools, the `10_java` zsh rc.
- VM-only skips `.ssh/config`, `.npmrc`, `.yarnrc*`, the `Library/` folder,
  the `05_homebrew` zsh rc.
- `needs_opencode=false` removes `dot_config/opencode/`.
- `needs_taskwarrior=false` removes `dot_taskrc*` and `,task-popup`.

If you want a different split (e.g., Neovim on the host too), flip the
relevant entries in `.chezmoiignore.tmpl` and re-apply.

## The Lima VM

Defined in `lima/dev-fedora.yaml`:

- **Distro:** Fedora (vzNAT, vz VMType — native on Apple Silicon)
- **Resources:** 6 CPUs, 6 GiB RAM, 60 GiB disk
- **User:** `dev` with login shell `/usr/bin/zsh`
- **Mounts:** none (intentional — keeps host/VM cleanly separated)
- **Containerd:** disabled (podman installed instead)
- **Networking:** vzNAT; localhost-bound ports auto-forward to host; 0.0.0.0 services reached via `,vm-ip`

`lima/dev-fedora-system.sh` provisions system packages via `dnf`: git, curl,
chezmoi, zsh, zsh-autosuggestions, ripgrep, fd, bat, eza, zoxide, fzf, jq,
make, gcc, helm, podman, podman-compose, and bootstraps `mise`.

**Common adaptations:**

| Change                  | File / line                                                    |
|-------------------------|----------------------------------------------------------------|
| Swap distro             | `lima/dev-fedora.yaml` (base template) + rewrite provisioning dnf commands in `lima/dev-fedora-system.sh` |
| Change resources        | `cpus`, `memory`, `disk` in `dev-fedora.yaml`                  |
| Add host mounts         | `mounts:` list in `dev-fedora.yaml` (empty by default)         |
| Different VM name       | Pass `--name` to `,create-vm`; update `,dev`, `,vm-ip`, `,vm-open`, `,sync-jfrog-to-vm` scripts if you want a different default |
| Different default shell | `user.shell` in `dev-fedora.yaml` and the `chsh` step          |

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
| `10_java`            | VM only (Java env for Scala)                          |
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
| `,create-vm`          | bootstrap the Fedora VM via limactl                      |
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
| `,setup-scala`        | install/update the Scala toolchain inside the VM         |
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
(stable), `bun`, `go`, `ruby`, `node` (LTS), `rust` (stable), `java` plus IDE tools (`yazi`,
`lazygit`, `zellij`, `delta`, `golangci-lint`, `prettier`, `emmet-ls`,
`scooter`, `shfmt`, `yq`), language servers (`gopls`, `gofumpt`, `dlv`,
`ruby-lsp`, `rufo`, `yaml-language-server`, `bash-language-server`,
`vscode-langservers-extracted`, `dockerfile-language-server`,
`compose-language-service`), plus `scalafmt` and a custom `coursier` binary.

To add/remove: edit the tool list in the template. To pin versions, use
mise's `version = "x.y.z"` syntax.

### Scala / JFrog work flow

Work-specific; entirely conditional on `work_username`.

1. Credentials live in 1Password on the host; `,jfrog_oidc_env` exports
   `JFROG_OIDC_USER` / `JFROG_OIDC_TOKEN`.
2. `,sync-jfrog-to-vm --host <jfrog-host>` (driven by
   `bootstrap/vm/sync-jfrog.sh`) writes three files inside the VM:
   - `~/.config/home-sweet-home/jfrog-oidc.env`
   - `~/.ivy2/.credentials`
   - `~/.config/coursier/credentials.properties`
3. `,setup-scala` (script `bootstrap/vm/setup-scala.sh`) mise-installs the
   toolchain and then `cs install sbt metals`.
4. `SBT_CREDENTIALS` / `COURSIER_CREDENTIALS` are exported automatically by
   `dot_config/zsh/rc.d/20_jfrog.tmpl` when those files exist.

If you don't use JFrog, delete the three scripts, `20_jfrog.tmpl`, and the
Scala-related mise entries. If you use a different private repo, the flow is
a good template — keep the shape, swap the URL/realm logic.

## OpenCode (optional)

Gated by `needs_opencode`. Config: `chezmoi/dot_config/opencode/opencode.json.tmpl`.

Permissions are opinionated:
- `edit: allow` globally
- `bash: allow` with explicit denies for `rm -rf*`, `git push --force*`,
  `git reset --hard*`, `npm/pnpm/yarn publish*`
- A separate `plan` agent is read-only (bash restricted to status/log/show,
  grep, rg, cat, ls, tree, find, wc)

Commands and skills live under `dot_config/opencode/commands/` and
`dot_config/opencode/skills/` (debug, improve, prototype, check, review,
test, pair-debugging, git-commit, software-design, ddd, fix-defect).

**VM browser-auth gotcha** is documented in the README: finish the browser
login on the host, copy the failing `http://localhost:…` URL, `curl` it from
inside the VM to complete the OAuth callback.

## Git

`chezmoi/dot_gitconfig.tmpl` sets:

- Identity and signing key (ed25519 on VM, rsa on work host)
- SSH GPG signing, `osxkeychain` helper on the work host
- URL rewrites inside the VM for `github.com` and XING's Gitea
- `push.default = current`, `push.autoSetupRemote = true`,
  `pull.rebase = false`, `init.defaultBranch = main`
- Editor = `nvim`
- Aliases: `ci co st br`

Remove the XING-specific URL rewrite + credential block if you don't work at
XING. The `,g*` diagnostics scripts are standalone bash and portable as-is.

## Taskwarrior (optional)

`dot_taskrc.tmpl` stores data at `~/Documents/tasks` and applies a
Catppuccin Mocha Black theme. Custom urgency coefficients bias `+bug`,
`+security`, `+problem` up and `+maybe`, `+someday`, `+later` down.

## macOS host specifics

- Brewfile: `bootstrap/host/Brewfile.work`. Runs via
  `run_once_after_host-brew-bundle.sh.tmpl` only when
  `develop=false AND darwin AND work_username`.
- Terminal emulator: Ghostty (brew cask). WezTerm config is present but
  ignored on macOS — it's kept for reference/alt use.
- Lazygit's macOS config lives under `chezmoi/Library/Application Support/`
  via chezmoi's Library handling.

Add a personal Brewfile by creating `Brewfile.personal` and updating the
`run_once_after_host-brew-bundle` script's file-picking logic.

## Bootstrap scripts

`bootstrap/host/`:
- `Brewfile.work` — brew bundle manifest

`bootstrap/vm/`:
- `macos-create-fedora.sh` — `limactl start` driven by `lima/dev-fedora.yaml`
- `setup-scala.sh` — mise trust/install + `cs install sbt metals`
- `sync-jfrog.sh` — JFrog creds into the VM

chezmoi run hooks (in `chezmoi/.chezmoiscripts/`):
- `run_once_after_host-brew-bundle.sh.tmpl` — macOS host only
- `run_after_nvim-lazyvim-bootstrap.sh.tmpl` — develop machines; clones LazyVim starter if `~/.config/nvim` is empty
- `run_after_taskwarrior-linux.sh.tmpl` — Linux taskwarrior

## Opinionated choices at a glance

| Choice                         | Keep, swap, or remove?                          |
|--------------------------------|-------------------------------------------------|
| chezmoi as dotfile manager     | Keep unless you really prefer stow/yadm         |
| Fedora on Lima                 | Swap distro in `lima/dev-fedora.yaml` if you want Ubuntu/Arch/NixOS |
| `,`-prefix for custom commands | Rename all at once if you dislike it            |
| Neovim + LazyVim as editor     | Swap for Helix/Emacs/etc; replace `nvim` in zsh/git/yazi/scooter/zellij/lazygit + LazyVim bootstrap script |
| Catppuccin Mocha everywhere    | Replace in five config files (Zellij, Yazi, Scooter, starship, taskrc); nvim theme is set by LazyVim |
| mise for language versions     | Keep — it's already doing asdf's job and more   |
| Zellij + layouts               | Keep or swap for tmux (you'd rewrite `,zlayout`, `,zdev`, `,zagent`) |
| OpenCode as AI agent           | Fully opt-in                                    |
| Taskwarrior                    | Fully opt-in                                    |
| JFrog + Scala work flow        | Work-specific; drop if not needed               |
| VM `~/code` repo layout        | Change in `,ghclone` if you want a flat layout  |
| No VM mounts                   | Add `mounts:` in `dev-fedora.yaml` if you want shared code with the host |
| zsh only                       | Swap means rewriting every file in `dot_config/zsh/rc.d/` |

## Recommended adaptation order

1. Fork, update `README.md` to point at your repo, and change `.chezmoiroot`
   references only if you restructure directories.
2. Walk through `chezmoi/.chezmoi.toml.tmpl` — keep/remove prompts first so
   everything downstream has stable variables.
3. Update `chezmoi/.chezmoiignore.tmpl` to match any new host/VM split.
4. Edit `lima/dev-fedora.yaml` for your resources/distro.
5. Trim/extend `bootstrap/host/Brewfile.work` and the mise config.
6. Rename `,`-prefixed commands (or don't).
7. Replace the color scheme (or don't).
8. Swap the editor (big surgery — do last).

Reapply iteratively with `,chezmoi-init` on both host and VM. Start with
`develop=no` on the host, spin up the VM, then iterate from inside it.
