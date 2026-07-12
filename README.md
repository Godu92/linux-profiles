# linux-profiles

Project for common profile settings

- [linux-profiles](#linux-profiles)
  - [Source files](#source-files)
    - [One Time](#one-time)
    - [Always Updated](#always-updated)
    - [ZSH](#zsh)
    - [direnv](#direnv)

## Source files

The various dotfiles (dot-profile files) in this project are for Linux based preferences.

### One Time

They can be used by simply copying into your `home` directory and then restarting your terminal.

### Always Updated

Alternatively, you can link to the files and thus they will be updated anytime this project gets updates.

Example:

```bash
ln -s linux-profiles/.vimrc .vimrc
```

> Note: You can take this one step further and do the link as `root` as well to have the same alias and preferences there as well
> TODO: Make script to simplify this process

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
- `direnv/direnvrc` — symlink to `~/.config/direnv/direnvrc` once per
  machine; adds the `layout anaconda <env>` helper that `envrc.conda` uses
  (direnv doesn't ship conda support out of the box).
