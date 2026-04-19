# home-sweet-home — quick reference

This file is managed by chezmoi (from `home-sweet-home-personal`) and
kept on the Desktop as a one-click reference.

---

## Daily commands

```
,dev              enter the dev VM shell
,create-vm        create the Ubuntu dev VM (first time only)
,vm-ip            print the dev VM's IPv4 address
,vm-open [PORT]   open http://<vm-ip>[:PORT] in the host browser
,cheatsheet       full terminal-tool keybinding reference
,chezmoi-init     re-apply the current machine's chezmoi state
,chezmoi-update   pull the latest home-sweet-home and apply
,verify           re-run the health check from the installer
,agent            launch the currently selected AI coding harness
,agent-select     switch between opencode / claude (show + pick)
```

---

## Host vs VM

**Host (macOS):** minimal. Homebrew, chezmoi, Ghostty terminal,
AeroSpace window manager, `nb` notes, 1Password CLI, the `,*` helper
scripts — and the GUI apps from the Brewfile. All dev CLIs live in
the VM.

**VM (Ubuntu LTS via lima):** where all coding happens. Git clones
under `~/code`. Mise manages language versions (neovim, go, ruby,
node, rust, bun, plus lots of editor/LSP tools). No shared mounts by
default — host and VM filesystems are separate.

Enter the VM with `,dev`. That drops you into a zellij session.

---

## Terminal IDE (inside the VM)

Catppuccin Mocha everywhere. Locked-mode zellij keybindings — the
chord is `Alt+<key>` (on macOS with Ghostty's `macos-option-as-alt
= true`, that's just **Option+<key>**).

| Tool       | Role                                     | Floating zellij binding |
|------------|------------------------------------------|-------------------------|
| Neovim (LazyVim) | Editor. `nvim`.                    | inline in dev layout    |
| Zellij     | Terminal multiplexer / layouts.          | —                       |
| Lazygit    | Git UI.                                  | `Alt+g`           |
| Yazi       | File manager. Opens files in nvim.       | `Alt+e`           |
| Scooter    | Workspace-wide search & replace.         | `Alt+r`           |
| Delta      | Better `git diff` paging.                | —                       |

Zellij layouts (`,zlayout <name>` or the shortcuts):

- `default` — single focused pane
- `,zdev`   — editor 70% / shell 30%
- `,zagent` — editor 70% / OpenCode 30%
- `zj [name]` — attach or create a session (default "local")

Full keybinding list: `,cheatsheet`.

---

## Notes (`nb`)

```
nb add "title"      new note
nb ls               list notes
nb edit <id>        open in editor
nb sync             pull + push to GitHub
```

This machine is wired to the **home** notebook at
`~/.nb/home` → `git@github.com:saimonmoore/nb.git`.

---

## Git helpers

Aliases (see `git config --get-regexp alias`):

- `git pam`      — fzf branch picker; checkout
- `git pamadd`   — fzf file picker; stage
- `git pamfix`   — fzf commit picker; auto-fixup + rebase
- `git pamshow`, `git pamlog`, `git pamreset`, `git pamrebase`, `git pamvim`

Scripts:

- `,ghclone owner/repo` → clone into `~/code/github/owner/repo`
- `,ghotspots`          → most-edited files in the last year
- `,gauthors`           → commit count by author
- `,gbugs`              → "fix/bug/broken" commits grouped by file
- `,gfire`              → revert/hotfix/rollback commits
- `,gbranches`          → branches sorted by most recent commit
- `,gactivity`          → commits per month

---

## Access a VM service from the host

Prefer binding app servers to `127.0.0.1` inside the VM; lima
forwards guest localhost ports to host localhost.

```
# inside the VM
bin/rails server -b 127.0.0.1 -p 3000
# on the host
open http://localhost:3000
```

For services on `0.0.0.0`, use `,vm-open PORT` (or `,vm-ip` + a
manual URL).

---

## Troubleshooting

- **Something looks broken** → `,verify`. Prints a pass/fail summary.
- **Files drifted** → `chezmoi diff` to inspect, `chezmoi apply` to
  re-render.
- **VM won't start** → `limactl stop dev && limactl delete dev && ,create-vm`.
- **brew bundle failed mid-install** → `brew bundle --file
  ~/.local/share/chezmoi/bootstrap/host/Brewfile` in a fresh shell.

---

## Where to look for more

- `~/Development/home-sweet-home-personal/README.md` — install + post-install
- `~/Development/home-sweet-home-personal/ADAPTING.md` — customization guide
- GitHub: https://github.com/saimonmoore/home-sweet-home
