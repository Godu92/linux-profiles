# linux-profiles

Project for common profile settings

- [linux-profiles](#linux-profiles)
  - [Source files](#source-files)
    - [One Time](#one-time)
    - [Always Updated](#always-updated)
    - [ZSH](#zsh)

## Source files

The various `./profile` files are for Linux based preferences.

> TODO: Move to own repo

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
