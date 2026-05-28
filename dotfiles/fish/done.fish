# Multi-DE done.fish for NixOS 
# Compatible with Hyprland, Sway, GNOME, KDE, and X11

if not status is-interactive
    exit
end

# --- Focus Detection Logic ---

function __done_get_focused_window_id
    if test -n "$HYPRLAND_INSTANCE_SIGNATURE"
        # Hyprland
        hyprctl activewindow -j 2>/dev/null | jq '.pid' 2>/dev/null
    else if test -n "$SWAYSOCK"
        # Sway
        swaymsg -t get_tree 2>/dev/null | jq '.. | objects | select(.focused == true) | .id' 2>/dev/null
    else if test "$XDG_SESSION_DESKTOP" = "gnome"
        # GNOME (via DBus)
        if type -q gdbus
            gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval 'global.display.focus_window.get_id()' 2>/dev/null
        end
    else if type -q xprop; and test -n "$DISPLAY"
        # X11 (KDE Plasma X11, Xfce, i3)
        xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW 2>/dev/null | cut -f 2
    else
        # Fallback for COSMIC or others not yet explicitly supported
        echo "unknown"
    end
end

function __done_is_process_window_focused
    set -l current_focus (__done_get_focused_window_id)
    
    # If focus detection fails or returns unknown, notify anyway to be safe
    if test -z "$current_focus"; or test "$current_focus" = "unknown"
        return 1
    end

    if test "$__done_initial_window_id" = "$current_focus"
        return 0
    end
    
    return 1
end

# --- Utility Functions ---

function __done_humanize_duration -a milliseconds
    set -l seconds (math --scale=0 "$milliseconds/1000" % 60)
    set -l minutes (math --scale=0 "$milliseconds/60000" % 60)
    set -l hours (math --scale=0 "$milliseconds/3600000")

    if test $hours -gt 0; printf '%sh ' $hours; end
    if test $minutes -gt 0; printf '%sm ' $minutes; end
    if test $seconds -gt 0; printf '%ss' $seconds; end
end

# --- Core Execution ---

set -g __done_initial_window_id ''
set -q __done_min_cmd_duration; or set -g __done_min_cmd_duration 5000
set -q __done_exclude; or set -g __done_exclude '^git (?!push|pull|fetch)'

function __done_started --on-event fish_preexec
    set -g __done_initial_window_id (__done_get_focused_window_id)
end

function __done_ended --on-event fish_postexec
    set -l exit_status $status
    set -q cmd_duration; or set -l cmd_duration $CMD_DURATION

    if test "$cmd_duration" -gt "$__done_min_cmd_duration"
        if not __done_is_process_window_focused
            
            for pattern in $__done_exclude
                if string match -qr $pattern $argv[1]; return; end
            end

            set -l humanized_duration (__done_humanize_duration "$cmd_duration")
            set -l title "Done in $humanized_duration"
            set -l wd (string replace --regex "^$HOME" "~" (pwd))
            set -l message "$wd > $argv[1]"
            set -l urgency normal

            if test $exit_status -ne 0
                set title "Failed ($exit_status) after $humanized_duration"
                set urgency critical
            end

            # Standard Linux notification system
            if type -q notify-send
                notify-send --urgency=$urgency \
                    --icon=utilities-terminal \
                    --app-name=fish \
                    --hint=int:transient:1 \
                    "$title" \
                    "$message"
            else
                echo -e "\a"
            end
        end
    end
end
