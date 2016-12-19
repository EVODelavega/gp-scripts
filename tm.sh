#!/usr/bin/env bash

     ###################################################
     ##                                               ##
     ## simple tmux shortcut script (work in progres) ##
     ##      Currently only handles simple tasks      ##
     ##                                               ##
     ##       * Creating/attaching sessions           ##
     ##       * Killing detatched sessions            ##
     ##       * Interactively kill sessions           ##
     ##                                               ##
     ## Next features to be supported:                ##
     ##       * Scripted sessions (new sessions)      ##
     ##                                               ##
     ###################################################

tmux_sessions=()
tmux_states=()
last=0

Usage() {
    echo "${0##*/} [-kardh]: makes life easier WRT managing tmux sessions"
    echo
    echo "     -k: Kill sessions interactively"
    echo "     -a: Attach existing session, or create new session and attach [DEFAULT ACTION]"
    echo "     -r: Rename an existing session"
    echo "     -d: Kill detached sessions"
    echo "     -h: Display this help message"
}

check_chosen() {
    local e
    for e in "${@:2}"; do
        [[ "${e}" == "$1" ]] && return 0
    done
    echo "Invalid option ${1}"
    Usage
    exit 1
}

get_sessions() {
    local IFS
    IFS=$'\n'
    for s in $(tmux ls); do
        tmux_states+=("${s}")
        break_choice "${s}"
    done
    last="${#tmux_sessions[@]}"
    if [ "${action}" == "a" ]; then
        mux_sessions+=("${last}")
        mux_states+=("${last}: Create new session")
    else
        (( last-- ))
    fi
}

break_choice() {
    local IFS
    local l
    IFS=$' '
    read -r -a l <<< "$1"
    tmux_sessions+=("${l[0]%?}")
}

display_choices() {
    local idx
    local choices
    for idx in "${!tmux_states[@]}"; do
        echo "$idx -> ${tmux_states[idx]}"
    done
}

choose_session() {
    display_choices
    read -p "Choose a session/action (q or higher value than default to exit) [${last}]: " -r
    chosen="${REPLY:-$last}"

    # quit
    [[ $REPLY =~ [qQ] ]] && exit

    if [ "${chosen}" -gt "$last" ]; then
        echo "Invalid input"
        Usage
        exit 1
    fi

    echo "Chosen ${chosen} -> ${tmux_states[chosen]}"
}

create_session() {
    read -p "Session name (default empty): " -r
    [[ -z "${REPLY// }" ]] && tmux || tmux new -s "${REPLY}"
    exit
}

rename_session() {
    local new_name
    read -p "New name for session: " -r new_name
    [[ -z "${new_name// }" ]] && exit_error "${new_name} is not a valid name" 2 || \
        tmux rename-session -t "${1}" "${new_name}"
    exit
}

kill_detached() {
    # kill detached sessions
    for ds in $(tmux ls | grep -v '(attached)' | awk '{print $1;}'); do
        tmux kill-session -t "${ds%?}" || echo "Error closing session ${ds%?}" >&2
    done
    exit 0
}

kill_interactive() {
    local idx
    local ans
    echo "Basic N/y to kill (N being default)"
    echo "m: More info (full tmux ls output for that session)"
    echo "q: quit"
    for idx in "${!tmux_states[@]}"; do
        read -p "Kill session ${tmux_sessions[idx]}? [N/y/m/q]: " -n 1 -r
        ans="${REPLY:-N}"
        # More info
        if [[ "${ans}" =~ ^[mM]$ ]]; then
            echo
            read -p "Kill ${tmux_sessions[idx]} -> ${tmux_states[idx]} [N/y/q]: " -n 1 -r
            ans="${REPLY:-N}"
        fi
        [[ "${ans}" =~ ^[qQ]$ ]] && echo "Quit" && exit 0
        [[ "${ans}" =~ ^[yY]$ ]] && tmux kill-session -t "${tmux_sessions[idx]}"
    done
}

no_sessions() {
    local sessions_active
    tmux ls > /dev/null
    sessions_active=$?
    if [ "$action" == "a" ]; then
        [ "${sessions_active}" -eq 0 ] || create_session
    fi
    [ "${sessions_active}" -eq 0 ] || exit_error "No sessions to manage" 1
}

# Exit with error message
exit_error() {
    echo "${1}" >&2
    exit "${2}"
}


action="a"

while getopts hkard flag; do
    case $flag in
        k)
            # interactively kill tmux session
            action="k"
            ;;
        a)
            # default -> attach session (new or existing)
            action="a"
            ;;
        d)
            # kill detached sessions
            for ds in $(tmux ls | grep -v '(attached)' | awk '{print $1;}'); do
                tmux kill-session -t "${ds%?}" || echo "Error closing session ${ds%?}"
            done
            exit 0
            action="d"
            ;;
        r)
            # Rename existing session
            action="r"
            ;;
        h)
            Usage
            exit 0
            ;;
    esac
done

# check whether or not sessions are active, and handle action if possible
no_sessions

get_sessions

case "${action}" in
    a)
        choose_session
        [[ "${chosen}" == "${last}" ]] && create_session
        tmux a -t "${tmux_session[chosen]}"
        ;;
    d)
        kill_detached
        ;;
    r)
        choose_session
        rename_session "${tmux_session[chosen]}"
        ;;
    k)
        kill_interactive
        ;;
esac

