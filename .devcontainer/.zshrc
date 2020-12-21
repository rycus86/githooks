
if [[ ! -d ~/.zplug ]];then
    sudo apt-get install -y gawk # https://github.com/zplug/zplug/issues/359#issuecomment-349534715
    git clone https://github.com/zplug/zplug ~/.zplug
fi

source ~/.zplug/init.zsh
zplug "plugins/git", from:oh-my-zsh
zplug "plugins/command-not-found", from:oh-my-zsh
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-history-substring-search"
zplug "romkatv/powerlevel10k", as:theme, depth:1

if ! zplug check --verbose; then
    export TERM=xterm-256color
    zplug install
fi

zplug load --verbose

# Keybindings for substring search plugin. Maps up and down arrows.
bindkey -M main '^[OA' history-substring-search-up
bindkey -M main '^[OB' history-substring-search-down
bindkey -M main '^[[A' history-substring-search-up
bindkey -M main '^[[B' history-substring-search-up

# Ctrl+ Left/right
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# History
HISTFILE="$GITHOOKS_REPO/.devcontainer/.zsh_history"
SAVEHIST=100000
HISTSIZE=100000

# To customize prompt, run 'p10k configure' or edit ~/.p10k.zsh.
[[ ! -f "$GITHOOKS_REPO/.devcontainer/.p10k.zsh" ]] || source "$GITHOOKS_REPO/.devcontainer/.p10k.zsh"