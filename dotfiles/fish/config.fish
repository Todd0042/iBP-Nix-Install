## Source from conf.d before our fish config
if test -f ~/.config/fish/done.fish
    source ~/.config/fish/done.fish
end

## Set values
function fish_greeting
    if set -q IN_NIX_SHELL
        echo (set_color 5e81ac)"❄  Nix Development Shell Active"(set_color normal)
    else
        type -q fastfetch; and fastfetch -c ~/.config/fish/10.jsonc
    end
end

# Format man pages
set -x MANROFFOPT "-c"
if type -q bat
    set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 5000
set -U __done_notification_urgency_level low

## Environment setup
if test -f ~/.fish_profile
    source ~/.fish_profile
end

fish_add_path ~/.local/bin

## History Bindings (!! and !$)
function __history_previous_command
    switch (commandline -t)
    case "!"
        commandline -t $history[1]; commandline -f repaint
    case "*"
        commandline -i !
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
    case "!"
        commandline -t ""
        commandline -f history-token-search-backward
    case "*"
        commandline -i '$'
    end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
    bind -Minsert ! __history_previous_command
    bind -Minsert '$' __history_previous_command_arguments
else
    bind ! __history_previous_command
    bind '$' __history_previous_command_arguments
end

## General Functions
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | trim-right /)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

abbr -a nixflake "cd /home/todd/Documents/GitHub/iBP-Nix-Swap/ &&"
abbr -a swap "sudo /home/todd/Documents/GitHub/iBP-Nix-Swap/scripts/swap.sh"
abbr -a rebuild "sudo nixos-rebuild switch --flake /home/todd/Documents/GitHub/iBP-Nix-Swap#"
abbr -a snapshot "/home/todd/Documents/GitHub/iBP-Nix-Swap/scripts/snapshot-home.sh"
abbr -a cleanNix "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +5 && sudo nix-collect-garbage -d"


# Modern LS (eza)
if type -q eza
    alias ls='eza -al --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias ll='eza -l --color=always --group-directories-first --icons'
    alias lt='eza -aT --color=always --group-directories-first --icons'
else
    alias ls='ls -alh --color=auto'
end

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias jctl="journalctl -p 3 -xb"
alias please='sudo'
alias nsearch='nix search nixpkgs'
alias ndev='nix develop'
