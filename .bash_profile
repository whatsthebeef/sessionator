## Ahoy ##################################################### BASH CONFIG ##########################################

##### Keys
export DEV=${HOME}/dev
export AWS_DEFAULT_REGION=us-east-1

##### Initializations (must run before PATH so their paths are available)

BASH_SILENCE_DEPRECATION_WARNING=1
export BASH_SILENCE_DEPRECATION_WARNING

eval "$(/opt/homebrew/bin/brew shellenv)"

export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

##### Path

PATH=${HOMEBREW_PREFIX}/opt/gnu-sed/libexec/gnubin:${PATH}
PATH=/usr/local/bin:${PATH}
PATH=${HOME}/.local/bin:${PATH}
PATH=${PATH}:${HOME}/.rvm/bin # Add RVM to PATH for scripting
PATH=${ANDROID_HOME}/platform-tools:${PATH}
PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
PATH=/opt/homebrew/bin:$PATH
PATH="$PATH:${HOME}/.nvm/versions/node/v18.19.1/bin"
PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
PATH="/opt/homebrew/opt/libpq/bin:$PATH"
PATH="$HOME/.config/scripts:$PATH"

export PATH

##### Env Variables

export PL_ENV=dev

export DL=${HOME}/Downloads
export VIMHOME=${HOME}/.configs/nvim

export SHELL_SESSION_HISTORY=0

export MYVIFMRC=${HOME}/.vifmrc

export EDITOR=nvim

export MYSHELL=$(ps $$ | awk 'NR>1 {print $5}')

##### Config

# cd ~/dev/pocketlab-notebook

# avoid duplicates..
export HISTCONTROL=ignoredups:erasedups

# append history entries.. (true so it is ignored)
shopt -s histappend || true

# After each command, save and reload history
PROMPT_COMMAND="history -a; history -c; history -r"

# don't set resource limits
ulimit -n unlimited

# Vim in bash
if [[ $MYSHELL =~ bash ]];
then
  set -o vi
elif [[ $MYSHELL =~ zsh ]];
then
  bindkey -v
else
  set -o vi
fi

##### Aliases

alias vim='nvim'
alias vimdiff='nvim -d'

### Config files
alias cb="vim ${HOME}/.bash_profile"
alias ct="vim ${HOME}/.tmux.conf"
alias cv="vim ${HOME}/.config/nvim/init.lua"
alias cvf="vim ${HOME}/.vifmrc"
alias chs="vim ${HOME}/.hammerspoon/init.lua"

alias cbr="source ${HOME}/.bash_profile"
alias ctr="tmux source-file ${HOME}/.tmux.conf"
alias cvfr="source ${HOME}/.vifmrc"

alias rmcon="ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=10 roger@mushroom"

pdev() { sstor --project=pocketlab-notebook ${@:+-i "$@"} --server='cd ./services/app && yarn serve'; }
bdev() { sstor --project=bluebonnetgpt ${@:+-i "$@"}; }
sdev() { sstor --project=sessionator ${@:+-i "$@"}; }
tdev() { sstor --project=tenmen ${@:+-i "$@"}; }

alias python="python3"

##### Styles

if [[ $MYSHELL =~ bash ]]; then
  PS1="\[\033[01;32m\]\u\[\033[01;34m\]::\[\033[01;31m\]\h \[\033[00;34m\]{ \[\033[01;34m\]\w \[\033[00;34m\]}\[\033[01;32m\]-> \[\033[00m\]"
fi

# http://linuxgazette.net/137/anonymous.html
cursor_style_default=0 # hardware cursor (blinking)
cursor_style_invisible=1 # hardware cursor (blinking)
cursor_style_underscore=2 # hardware cursor (blinking)
cursor_style_lower_third=3 # hardware cursor (blinking)
cursor_style_lower_half=4 # hardware cursor (blinking)
cursor_style_two_thirds=5 # hardware cursor (blinking)
cursor_style_full_block_blinking=6 # hardware cursor (blinking)
cursor_style_full_block=16 # software cursor (non-blinking)

cursor_background_black=0 # same color 0-15 and 128-infinity
cursor_background_blue=16 # same color 16-31
cursor_background_green=32 # same color 32-47
cursor_background_cyan=48 # same color 48-63
cursor_background_red=64 # same color 64-79
cursor_background_magenta=80 # same color 80-95
cursor_background_yellow=96 # same color 96-111
cursor_background_white=112 # same color 112-127

cursor_styles="\e[?${cursor_style_full_block};${cursor_foreground_black};${cursor_background_green};c" # only seems to work in tty

##### Rails

alias mypgsql="/opt/homebrew/opt/postgresql@14/bin/postgres -D /opt/homebrew/var/postgresql@14 -U postgres"

##### Node

# nodejs
# nvm use 18.19

##### Git (symlinked from repo by install.sh)

# Added by Antigravity
export PATH="/Users/john/.antigravity/antigravity/bin:$PATH"
