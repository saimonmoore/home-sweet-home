# home-sweet-home

Dotfiles for my host plus an isolated Fedora VM for development.


## First-Time Setup

### Work

#### Host

Install Homebrew first. `chezmoi` will run `brew bundle` once on the macOS host.

```bash
chezmoi init --apply david-krentzlin/home-sweet-home
,create-vm
```

When `chezmoi` prompts on the host, answer:

- `Will you develop on this machine?` -> `no`
- `Will you need opencode on this machine?` -> `no`
- fill in `Git author name`, `Git author email`, `GitHub username`, and `Work username`

#### VM as `dev`

```bash
limactl shell --tty --reconnect --workdir /home/dev --shell /usr/bin/zsh dev
# or
,dev
```

Run inside the VM as `dev`:

```bash
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ssh-keygen -q -t ed25519 -N '' -C "dev@dev" -f "$HOME/.ssh/id_ed25519"
chezmoi init --apply david-krentzlin/home-sweet-home
mise install
chezmoi apply
```

This also installs the terminal IDE support managed here for Neovim (LazyVim), Zellij, Lazygit, Yazi, and related editor tooling.

When `chezmoi` prompts as `dev`, answer:

- `Will you develop on this machine?` -> `yes`
- `Will you need opencode on this machine?` -> `yes` if you want OpenCode in the VM, otherwise `no`
- fill in the same identity values as on the host

Open the VM as `dev` when you need a shell.

```bash
,dev
```

Use `,dev` instead of raw `limactl shell` commands.

Existing VMs created before the login-shell fix may still have `/bin/bash` as `dev`'s login shell. Recreate the VM or run `sudo usermod -s /usr/bin/zsh dev` inside it once.

Keep repos under `~/code` in the VM.

`chezmoi` can read this repo directly from GitHub because the repo root now contains `.chezmoiroot` pointing at `chezmoi/`.

Every machine also gets:

- `,chezmoi-init` to run `chezmoi apply`
- `,chezmoi-update` to run `chezmoi update`

Use `david-krentzlin/home-sweet-home` with `chezmoi init`. Username-only shorthand resolves to `david-krentzlin/dotfiles`, which is not this repo.

## OpenCode Browser Auth In The VM

OpenCode browser auth currently redirects back to `localhost` on the machine that started `opencode`.

When `opencode` runs in the VM, the final browser redirect therefore fails on the host. The working flow is:

1. Run `/connect` inside `opencode` in the VM.
2. Complete the browser login on the host.
3. When the browser lands on the failing `http://localhost:...` callback URL, copy that full URL.
4. Back in the VM, call it manually:

```bash
curl '<paste-the-final-localhost-url-here>'
```

That delivers the auth callback to the OpenCode process running inside the VM.

## What you get

* Managed dotfiles for your host machine
* A virtual machine that is used to isolate all development from the host system
* Managed dotfiles for the `dev` user in the development VM
* Optional OpenCode setup in the development VM

## Daily Use

- Open the dev shell with `,dev`
- Open a project tab from `zoxide` with `,zlayout [default|dev|dev-agentic]`
- Open a `dev` project tab with `,zdev`
- Open a `dev-agentic` project tab with `,zagent`
- Re-apply the current machine config with `,chezmoi-init`
- Open `,cheatsheet` for the terminal tool quick reference
- Show the VM IP with `,vm-ip`
- Open a VM-hosted service in the browser with `,vm-open 9000`
- Create the VM from the host with `,create-vm`
- Keep repos under `~/code` on the VM
- Pull and apply host changes with `,chezmoi-update`
- Pull and apply VM changes with `,chezmoi-update` as `dev`
- Run `,setup-scala` in the VM after syncing JFrog credentials when you need Scala/Metals tooling
- Clone GitHub repos via SSH into `~/code/github/<owner>/<repo>` with `,ghclone owner/repository`
- Use `,ghotspots`, `,gauthors`, `,gbugs`, `,gactivity`, `,gfire`, and `,gbranches` for quick git repo diagnostics
- For OpenCode browser auth in the VM, finish login on the host and `curl` the final localhost callback URL from inside the VM

## Access VM Servers From The Host

The VM uses `vzNAT`, so there are two supported access patterns from the host.

If the server binds to `127.0.0.1` or `localhost` inside the VM, Lima forwards guest localhost ports to host localhost.

If the server binds to `0.0.0.0`, open it via the VM IP instead.

Examples:

```bash
# Rails inside the VM
bin/rails server -b 127.0.0.1 -p 3000

# Open on the host
http://localhost:3000
```

```bash
# Another app inside the VM
./server --host 127.0.0.1 --port 8080

# Open on the host
http://localhost:8080
```

```bash
# App bound to all interfaces inside the VM
./server --host 0.0.0.0 --port 9000

# Get the VM IP from the host
limactl shell --workdir /home/dev dev ip -4 addr show lima0

# Open on the host
http://<vm-ip>:9000
```

Notes:

- Prefer binding app servers to `127.0.0.1` in the VM
- Use the same port number on the host for localhost-forwarded services
- Use the VM IP for services bound to `0.0.0.0`
- Existing VMs need a one-time `vzNAT` network update and restart to pick this up
- Host helpers: `,vm-ip` prints the VM IP and `,vm-open [PORT]` opens `http://<vm-ip>[:PORT]`

## Sync JFrog Credentials To The VM

JFrog credentials stay sourced from 1Password on the host and are copied explicitly into the VM when needed.

The host shell already provides `,jfrog_oidc_env`, which exports `JFROG_OIDC_USER` and `JFROG_OIDC_TOKEN`.

Sync credentials for a VM user with:

```bash
,jfrog_oidc_env
,sync-jfrog-to-vm --host your.jfrog.example.com
```

The default realm is `Artifactory Realm`. If `sbt` itself needs authenticated bootstrap access and your setup uses a different realm, pass `--realm` explicitly.

If you are not sure which realm JFrog is using, inspect the `WWW-Authenticate` response header from a protected repository URL and copy the realm value.

If Ruby gems use a different host than Scala/sbt, pass `--ruby-host` too.

The sync writes VM-local files only:

- `~/.config/home-sweet-home/jfrog-oidc.env`
- `~/.ivy2/.credentials`
- `~/.config/coursier/credentials.properties`

On VM work shells, `SBT_CREDENTIALS` and `COURSIER_CREDENTIALS` are exported automatically when those files exist.

## Setup Scala In The VM

After syncing JFrog credentials into the VM, run:

```bash
,setup-scala
```

This installs or updates the Scala toolchain expected by the VM setup:

- trust and install the current `mise` tool config
- add a `helm-ls` symlink when `helm_ls` is installed via `mise`
- install `sbt` and `metals` via `cs`

`COURSIER_CREDENTIALS` and `SBT_CREDENTIALS` are picked up from the JFrog files synced into the VM.

## Terminal IDE

`chezmoi` manages the Zellij, Lazygit, Yazi, and Scooter config from this repo directly. The editor is Neovim with the [LazyVim](https://www.lazyvim.org) starter.

On development machines, `mise install` pulls Neovim (stable) plus the editor-side tools managed here, including `lazygit`, `zellij`, `yazi`, `scooter`, `delta`, `golangci-lint`, `prettier`, and `emmet-ls`.

On first `chezmoi apply` on a development machine, the [LazyVim starter](https://github.com/LazyVim/starter) is cloned into `~/.config/nvim` (with its `.git` directory removed). Open `nvim` once afterwards to let `lazy.nvim` install plugins and treesitter parsers. Customize `~/.config/nvim` directly from there — it's yours.

To put your customized nvim config under chezmoi management later, run `chezmoi add ~/.config/nvim` and commit.

Theme assets for Yazi and Scooter are managed directly in this repo.
