#!/usr/bin/env sh

# Reuse one ssh-agent across Bash and Zsh shells.
#
# Behavior:
# - Prefer an already-working SSH_AUTH_SOCK from the parent environment.
# - Otherwise, restore the last known agent from ~/.ssh/agent.env.
# - If no agent is reachable, start a new one and persist its env file.
# - When the agent is reachable but empty, add the default identity set once.
# - On macOS, try restoring keys from Keychain before prompting.

if ! dotfiles_has_command ssh-agent || ! dotfiles_has_command ssh-add; then
  return 0 2> /dev/null || exit 0
fi

DOTFILES_SSH_DIR="${DOTFILES_SSH_DIR:-$HOME/.ssh}"
DOTFILES_SSH_AGENT_ENV="${DOTFILES_SSH_AGENT_ENV:-$DOTFILES_SSH_DIR/agent.env}"

dotfiles_ssh_agent_state() {
  ssh-add -l > /dev/null 2>&1
  return $?
}

dotfiles_ssh_agent_is_usable() {
  [ -n "${SSH_AUTH_SOCK:-}" ] || return 1
  [ -S "$SSH_AUTH_SOCK" ] || return 1

  dotfiles_ssh_agent_state
  dotfiles_ssh_agent_status=$?
  [ "$dotfiles_ssh_agent_status" -eq 0 ] || [ "$dotfiles_ssh_agent_status" -eq 1 ]
}

dotfiles_ssh_agent_load_env() {
  [ -r "$DOTFILES_SSH_AGENT_ENV" ] || return 1

  # shellcheck source=/dev/null
  . "$DOTFILES_SSH_AGENT_ENV" > /dev/null 2>&1 || return 1
  export SSH_AUTH_SOCK
  [ -n "${SSH_AGENT_PID:-}" ] && export SSH_AGENT_PID

  dotfiles_ssh_agent_is_usable
}

dotfiles_ssh_agent_start() {
  mkdir -p "$DOTFILES_SSH_DIR" || return 1

  (umask 077 && ssh-agent -s > "$DOTFILES_SSH_AGENT_ENV") || return 1

  # shellcheck source=/dev/null
  . "$DOTFILES_SSH_AGENT_ENV" > /dev/null 2>&1 || return 1
  export SSH_AUTH_SOCK
  [ -n "${SSH_AGENT_PID:-}" ] && export SSH_AGENT_PID

  dotfiles_ssh_agent_is_usable
}

dotfiles_ssh_has_default_identity() {
  for dotfiles_ssh_identity in \
    "$DOTFILES_SSH_DIR/id_ed25519" \
    "$DOTFILES_SSH_DIR/id_ed25519_sk" \
    "$DOTFILES_SSH_DIR/id_ecdsa" \
    "$DOTFILES_SSH_DIR/id_ecdsa_sk" \
    "$DOTFILES_SSH_DIR/id_rsa" \
    "$DOTFILES_SSH_DIR/id_dsa" \
    "$DOTFILES_SSH_DIR/id_xmss"
  do
    [ -r "$dotfiles_ssh_identity" ] && return 0
  done
  return 1
}

if ! dotfiles_ssh_agent_is_usable; then
  if ! dotfiles_ssh_agent_load_env && ! dotfiles_ssh_agent_start; then
    unset DOTFILES_SSH_DIR DOTFILES_SSH_AGENT_ENV
    return 0 2> /dev/null || exit 0
  fi
fi

dotfiles_ssh_agent_state
dotfiles_ssh_agent_status=$?

if [ "$dotfiles_ssh_agent_status" -eq 1 ] && [ -t 0 ] && dotfiles_ssh_has_default_identity; then
  if dotfiles_is_macos; then
    ssh-add --apple-load-keychain > /dev/null 2>&1 || true
    dotfiles_ssh_agent_state
    dotfiles_ssh_agent_status=$?
  fi

  if [ "$dotfiles_ssh_agent_status" -eq 1 ]; then
    ssh-add
  fi
fi

unset DOTFILES_SSH_DIR DOTFILES_SSH_AGENT_ENV
dotfiles_ssh_agent_status=${dotfiles_ssh_agent_status:-}
dotfiles_ssh_identity=${dotfiles_ssh_identity:-}
unset dotfiles_ssh_agent_status dotfiles_ssh_identity
