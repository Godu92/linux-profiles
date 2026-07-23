#!/usr/bin/env bash
# linux-profiles installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Godu92/linux-profiles/main/install.sh | bash
#
# Safe to re-run any time (e.g. after a `git pull`) - every step skips
# anything already installed/linked.
#
# Env overrides (mainly useful for local testing):
#   LINUX_PROFILES_DIR       where to clone/find the repo (default: ~/git/linux-profiles)
#   LINUX_PROFILES_REPO_URL  git remote to clone (default: this repo on GitHub)

set -euo pipefail

REPO_DIR="${LINUX_PROFILES_DIR:-$HOME/git/linux-profiles}"
REPO_URL="${LINUX_PROFILES_REPO_URL:-https://github.com/Godu92/linux-profiles.git}"

# Steps/items that failed but didn't abort the run - reported at the end so
# a single bad package or flaky clone doesn't silently leave a half-linked
# profile with no indication anything went wrong.
FAILED_STEPS=()

log() {
    echo "==> $*"
}

# Runs a top-level step; on failure, records it and keeps going instead of
# letting one step's failure (via set -e) abort every step after it.
run_step() {
    local desc="$1"
    shift
    if ! "$@"; then
        log "FAILED: $desc - continuing with remaining steps"
        FAILED_STEPS+=("$desc")
    fi
    return 0
}

maybe_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Corporate/hardened machines commonly have no user-writable directory on
# $PATH at all (no sudo, and ~/.local/bin doesn't exist yet) - guarantee one
# exists so anything installed at the user level (direnv, pip --user, etc.)
# has somewhere to go without needing root.
ensure_local_bin_on_path() {
    mkdir -p "$HOME/.local/bin"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:$PATH" ;;
    esac
}

detect_os() {
    if [ -f /etc/debian_version ]; then
        OS_FAMILY=debian
    elif [ -f /etc/redhat-release ]; then
        OS_FAMILY=redhat
    elif [ -f /etc/arch-release ]; then
        OS_FAMILY=arch
    else
        echo "Unsupported OS: none of /etc/debian_version, /etc/redhat-release, /etc/arch-release found" >&2
        exit 1
    fi
    log "Detected OS family: $OS_FAMILY"
}

pkg_update_cache() {
    case "$OS_FAMILY" in
        debian) maybe_sudo apt-get update -y ;;
        arch) maybe_sudo pacman -Sy --noconfirm ;;
        redhat) : ;;  # dnf/yum sync metadata automatically as needed
    esac
}

pkg_install_one() {
    local pkg="$1"
    case "$OS_FAMILY" in
        debian)
            maybe_sudo apt-get install -y "$pkg"
            ;;
        redhat)
            # --allowerasing: minimal RHEL9-family images ship curl-minimal,
            # which conflicts with the full curl package otherwise.
            if command -v dnf &> /dev/null; then
                maybe_sudo dnf install -y --allowerasing "$pkg"
            else
                maybe_sudo yum install -y "$pkg"
            fi
            ;;
        arch)
            maybe_sudo pacman -S --noconfirm "$pkg"
            ;;
    esac
}

ensure_base_packages() {
    # nano: guarantees the editor fallback chain in .aliases always has at
    # least one link, even on minimal images with no editor at all.
    local packages=(git zsh curl nano)
    case "$OS_FAMILY" in
        debian) packages+=(python3-venv python3-pip) ;;  # also pulls in python3 itself
        redhat) packages+=(python3 python3-pip) ;;
        arch) packages+=(python python-pip) ;;           # provides /usr/bin/python3
    esac
    log "Ensuring base packages are installed: ${packages[*]}"
    pkg_update_cache
    local pkg
    for pkg in "${packages[@]}"; do
        if ! pkg_install_one "$pkg"; then
            log "WARNING: failed to install '$pkg' - continuing with the rest"
            FAILED_STEPS+=("package: $pkg")
        fi
    done
    return 0
}

clone_or_update_repo() {
    if [ -d "$REPO_DIR/.git" ]; then
        log "linux-profiles already cloned at $REPO_DIR, updating"
        git -C "$REPO_DIR" pull --ff-only
    elif [ -d "$REPO_DIR" ]; then
        log "$REPO_DIR already exists (not a git checkout), using as-is"
    else
        log "Cloning linux-profiles to $REPO_DIR"
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone "$REPO_URL" "$REPO_DIR"
    fi
}

install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "oh-my-zsh already installed, skipping"
        return
    fi
    log "Installing oh-my-zsh"
    CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_git_tool() {
    local name="$1" url="$2" dest="$3"
    if [ -d "$dest" ]; then
        log "$name already present at $dest, skipping"
        return
    fi
    log "Installing $name to $dest"
    git clone --depth 1 "$url" "$dest"
}

# Extensibility point: every git-clone-based tool is one row here. Adding a
# new one is a single new line, not a new function.
install_git_tools() {
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local tools=(
        "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions|${zsh_custom}/plugins/zsh-autosuggestions"
        "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting|${zsh_custom}/plugins/zsh-syntax-highlighting"
        "powerlevel10k|https://github.com/romkatv/powerlevel10k|${zsh_custom}/themes/powerlevel10k"
        "zsh-autocomplete|https://github.com/marlonrichert/zsh-autocomplete|${HOME}/git/zsh-autocomplete"
    )
    local entry name url dest
    for entry in "${tools[@]}"; do
        IFS='|' read -r name url dest <<< "$entry"
        if ! install_git_tool "$name" "$url" "$dest"; then
            log "WARNING: failed to install $name - continuing with the rest"
            FAILED_STEPS+=("git tool: $name")
        fi
    done
    return 0
}

install_direnv() {
    if command -v direnv &> /dev/null; then
        log "direnv already installed, skipping"
        return
    fi
    log "Installing direnv"
    # Pin bin_path explicitly rather than let the installer scan $PATH for a
    # writeable directory - on a machine with no sudo and nothing writeable
    # on $PATH yet, that scan finds nothing and the installer just dies.
    curl -sfL https://direnv.net/install.sh | bin_path="$HOME/.local/bin" bash
}

backup_if_needed() {
    local target="$1" source="$2"
    if [ -L "$target" ]; then
        if [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
            return
        fi
        # A symlink carries no unique content of its own (whatever it points
        # to still exists untouched elsewhere) - just remove the pointer
        # rather than "backing it up" as a second, possibly-stale symlink.
        log "Removing stale symlink $target (was -> $(readlink "$target"))"
        rm "$target"
        return
    fi
    if [ -e "$target" ]; then
        local backup
        backup="${target}.pre-linux-profiles.$(date +%s).bak"
        log "Backing up existing $target to $backup"
        mv "$target" "$backup"
    fi
}

symlink_one_dotfile() {
    local file="$1" base
    base="$(basename "$file")"
    backup_if_needed "$HOME/$base" "$file" || return 1
    ln -sf "$file" "$HOME/$base" || return 1
    log "Linked $base"
}

symlink_dotfiles() {
    # Every dotfile (name starting with `.`) in one of these folders gets
    # symlinked into $HOME under its own name - add a new dotfile to an
    # existing folder and it's picked up with no further changes here.
    # Folders not listed (direnv/, test/) are intentionally excluded: direnv/
    # mixes in envrc.* templates that must NOT be auto-linked.
    local folders=(zsh bash common vim nano)
    local folder file
    for folder in "${folders[@]}"; do
        for file in "$REPO_DIR/$folder"/.[!.]*; do
            [ -e "$file" ] || continue
            if ! symlink_one_dotfile "$file"; then
                log "WARNING: failed to link $(basename "$file") - continuing with the rest"
                FAILED_STEPS+=("symlink: $(basename "$file")")
            fi
        done
    done
    return 0
}

symlink_direnvrc() {
    mkdir -p "$HOME/.config/direnv"
    backup_if_needed "$HOME/.config/direnv/direnvrc" "$REPO_DIR/direnv/direnvrc"
    ln -sf "$REPO_DIR/direnv/direnvrc" "$HOME/.config/direnv/direnvrc"
    log "Linked direnv/direnvrc"
}

maybe_change_shell() {
    local zsh_path
    zsh_path="$(command -v zsh || true)"
    if [ -z "$zsh_path" ]; then
        return
    fi
    if [ "${SHELL:-}" = "$zsh_path" ]; then
        log "Default shell is already zsh"
        return
    fi

    # chsh edits /etc/passwd directly, which only works for genuinely local
    # accounts. LDAP/FreeIPA-managed accounts resolve fine via sssd (id/login
    # work normally) but have no /etc/passwd entry at all, so chsh can't
    # touch them - detect that up front instead of prompting for something
    # that's guaranteed to fail.
    local acct
    acct="$(id -un)"
    if ! grep -q "^${acct}:" /etc/passwd 2> /dev/null; then
        log "Account '$acct' isn't in /etc/passwd (likely managed remotely, e.g. FreeIPA/LDAP) - chsh can't change it locally."
        log "Ask your admin, or if self-service is allowed: ipa user-mod --shell $zsh_path $acct"
        return
    fi

    if ! { : < /dev/tty; } 2> /dev/null; then
        log "No TTY available, skipping shell-change prompt (run 'chsh -s $zsh_path' manually if wanted)"
        return
    fi

    local reply
    printf '%s' "Change default shell to zsh ($zsh_path)? [y/N] " > /dev/tty
    read -r reply < /dev/tty
    case "$reply" in
        [Yy]*)
            if ! chsh -s "$zsh_path"; then
                log "WARNING: chsh failed - if your account is managed by FreeIPA/LDAP, try: ipa user-mod --shell $zsh_path $acct (or ask your admin)"
                FAILED_STEPS+=("chsh (default shell change)")
            fi
            ;;
        *) log "Skipping shell change" ;;
    esac
    return 0
}

print_summary() {
    cat <<EOF

==> linux-profiles setup complete.

Linked: .zshrc .bashrc .aliases .bash_functions .vimrc .p10k.zsh
        ~/.config/direnv/direnvrc

Not automated here - handle these yourself if needed:
  - Nerd Font: install one on your *client* terminal (this is server-side setup)
  - conda/miniconda: install separately (see direnv/envrc.conda for the project hookup)
  - nvm: install via https://github.com/nvm-sh/nvm's own installer if you need Node
  - docker/podman engine: install separately; .aliases already prefers docker,
    falling back to podman, whichever you install
  - root's dotfiles: re-run this script as root if you want the same setup there

Restart your terminal (or run 'exec zsh') to pick everything up.
EOF

    if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
        echo
        echo "The following did NOT succeed - re-run this script after addressing them:"
        local f
        for f in "${FAILED_STEPS[@]}"; do
            echo "  - $f"
        done
    fi
}

main() {
    detect_os
    ensure_local_bin_on_path
    run_step "Installing base packages" ensure_base_packages

    # Hard stop: every step after this reads dotfiles out of $REPO_DIR, so
    # there's no useful way to continue if this itself fails.
    if ! clone_or_update_repo; then
        log "FATAL: could not clone or update the repo at $REPO_DIR - nothing else can proceed without it"
        exit 1
    fi

    run_step "Installing oh-my-zsh" install_oh_my_zsh
    run_step "Installing zsh plugins/theme" install_git_tools
    run_step "Installing direnv" install_direnv
    run_step "Linking dotfiles" symlink_dotfiles
    run_step "Linking direnv config" symlink_direnvrc
    maybe_change_shell
    print_summary

    [ "${#FAILED_STEPS[@]}" -eq 0 ]
}

main "$@"
