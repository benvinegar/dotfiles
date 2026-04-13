# Load Oh My Zsh using the repo-managed custom themes/plugins.
# Source this from ~/.zshrc, not from bash.

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.config/dotfiles/oh-my-zsh-custom}"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions)

[ -r "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# Prefer fzf's history widget over the stock incremental Ctrl-R binding.
# This must run after Oh My Zsh/plugin init because later startup code can
# restore the default history-incremental-search-backward binding.
if command -v bindkey > /dev/null 2>&1 && command -v fzf-history-widget > /dev/null 2>&1; then
  bindkey '^R' fzf-history-widget
fi
