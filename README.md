# linux-profiles

Project for common profile settings

- [linux-profiles](#linux-profiles)
  - [Setup](#setup)
    - [Manual / One-off](#manual--one-off)
    - [Testing](#testing)
    - [ZSH](#zsh)
    - [direnv](#direnv)

## Setup

Supports RHEL/Rocky, Ubuntu, Raspberry Pi OS (Debian-based), and Arch. Run:

```bash
curl -fsSL https://raw.githubusercontent.com/Godu92/linux-profiles/main/install.sh | bash
```

This clones the repo to `~/git/linux-profiles`, installs zsh/oh-my-zsh/
Powerlevel10k/the custom zsh plugins/direnv (whichever are missing), symlinks
the dotfiles into `$HOME`, and offers to change your default shell to zsh.
It's safe to re-run any time (e.g. after a `git pull`) — every step skips
anything already installed or linked, backing up any pre-existing file it
would otherwise overwrite.

Root's dotfiles aren't linked automatically; re-run the script as root if you
want the same setup there.

### Manual / One-off

You can still just copy or symlink individual dotfiles by hand instead of
running the installer:

```bash
ln -s linux-profiles/vim/.vimrc .vimrc
```

### Testing

`test/docker-compose.yml` builds a disposable container per distro family
(`ubuntu`, `rockylinux`, `archlinux`) that copies the current working tree in
and runs `install.sh` at build time — a quick way to smoke-test dotfile or
installer changes before committing:

```bash
docker compose -f test/docker-compose.yml build            # smoke-test install.sh on every distro
docker compose -f test/docker-compose.yml run --rm ubuntu  # drop into a provisioned shell
```

### ZSH

ZSH is currently being used with `FiraMono Nerd Font`

### direnv

`.aliases` hooks `direnv` into the shell automatically if it's installed. The
`direnv/` folder holds templates to copy where needed, rather than files that
get symlinked wholesale:

- `direnv/envrc.venv` — copy to a project's `.envrc` to auto-create/activate
  a `.venv` on `cd`.
- `direnv/envrc.conda` — copy to a project's `.envrc` to activate a named
  conda environment on `cd`. Requires the helper below.
- `direnv/envrc.ansible` — copy to an Ansible project's `.envrc`; activates a
  `.venv` like `envrc.venv` and also sets `ANSIBLE_CONFIG`/
  `ANSIBLE_INVENTORY`/`ANSIBLE_ROLES_PATH` when those files/dirs exist in the
  project.
- `direnv/direnvrc` — symlink to `~/.config/direnv/direnvrc` once per
  machine; adds the `layout anaconda <env>` helper that `envrc.conda` uses
  (direnv doesn't ship conda support out of the box).
