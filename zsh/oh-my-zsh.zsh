# Load Oh My Zsh using the repo-managed custom themes/plugins.
# Source this from ~/.zshrc, not from bash.

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.config/dotfiles/oh-my-zsh-custom}"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions)

[ -r "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"
