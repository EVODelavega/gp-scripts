#!/usr/bin/env bash
## Older versions of shellcheck, use: shellcheck -e SC2016 tm.sh
###################################################
##                                               ##
## simple tmux shortcut script (work in progres) ##
##      Currently only handles simple tasks      ##
##                                               ##
##       * Attaching/creating sessions           ##
##       * Killing detatched sessions            ##
##       * Interactively kill sessions           ##
##       * Create named session quickly          ##
##       * Basic scripted sessions (startup)     ##
##                                               ##
## Next features to be supported:                ##
##       * Scripted sessions (continuation)      ##
##                                               ##
###################################################

tmux_sessions=()
tmux_states=()
last=0
script_dir="${HOME}/.tm"

Usage() {
    cat <<-_EOF__
${0##*/} [-kardhib] [-u script file] [-n [name]] [-s start-script]: makes life easier WRT managing tmux sessions

     -k: Kill sessions interactively
     -a: Attach existing session, or create new session and attach [DEFAULT ACTION]
     -u: copy/update a script in .tm directory
     -r: Rename an existing session
     -d: Kill detached sessions
     -n: Create new session with given name
     -s: Name of session-start script (located in ${script_dir}, session name available as \$TM_SESSION
     -i: Install, create script dir and adds an example script
     -b: start session in detached state [currently only used when specifying startup script]
     -h: Display this help message

  name : Pass name in conjunction with -n flag to create named session
_EOF__
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
    for idx in "${!tmux_states[@]}"; do
        echo "$idx -> ${tmux_states[idx]}"
    done
}

choose_session() {
    display_choices
    read -p "Choose a session/action (q or higher value than default to exit) [${last}]: " -r
    chosen="${REPLY:-$last}"

    # quit
    [[ $REPLY =~ ^[qQ]$ ]] && exit

    if [ "${chosen}" -gt "$last" ]; then
        echo "Invalid input"
        Usage
        exit 1
    fi

    echo "Chosen ${chosen} -> ${tmux_states[chosen]}"
}

create_session() {
    local name
    local pdir
    read -p "Session name (default current directory): " -r
    pdir=$(pwd)
    name="${REPLY// }"
    if [[ -z "${name}" ]]; then
        name="${pdir##*/}"
    fi
    if [ ! -z "${start_script}" ]; then
        tmux new -s "${name}" -d
        TM_SESSION="${name}" . "${start_script}"
        $attach && tmux a -t "${name}"
        exit
    fi
    tmux new -s "${name}"
    exit
}

rename_session() {
    local new_name
    read -p "New name for session: " -r new_name
    [[ -z "${new_name// }" ]] && exit_error "${new_name} is not a valid name" 2
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
        echo
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

do_install() {
    local default_script
    default_script="${script_dir}/default"
    [ ! -d "${script_dir}" ] && mkdir "${script_dir}"
    [ -f "${default_script}" ] && exit_error "script ${default_script} already exists" 5
    echo "#!/usr/bin/env bash" > "${default_script}"
    {
        cat << _EOD__

## example of send-keys, split-windown, and resize-pane
tmux send-keys -t "\${TM_SESSION}" 'pwd' C-m
tmux split-window -t "\${TM_SESSION}" -h
tmux resize-pane -t "\${TM_SESSION}" -R 30
_EOD__
    } >> "${default_script}"
}

update_script() {
    local script_name
    local target_script
    script_name="${1##*/}"
    target_script="${script_dir}/${script_name%.*}"
    if [ -f "${target_script}" ]; then
        read -p "Replace existing ${script_name%.*} script? [Y/n/d(iff)/r(ename)/q(uit)]: " -r -n 1 resp
        echo
        case $resp in
            y|Y)
                echo "Replacing script"
                ;;
            n|N)
                return
                ;;
            d|D)
                echo "diff: "
                diff "${1}" "${target_script}" | more
                update_script "${1}"
                return
                ;;
            r|R)
                while [ -f "${target_script}" ]; do
                    read -p "Enter new name: " -r name
                    target_script="${script_dir}/${name}"
                    [ -f "${target_script}" ] && echo "Script ${name} already exists"
                done
                ;;
            q|Q)
                return
                ;;
            *)
                echo "Unkown option ${resp}"
                update_script "${1}"
                ;;
        esac
    fi
    cp "${1}" "${target_script}"
    chmod +x "${target_script}"
}

action="a"
name="" # optional argument
start_script=""
attach=true

while getopts hiu:kardnbs: flag; do
    case $flag in
        k)
            # interactively kill tmux session
            action="k"
            ;;
        a)
            # default -> attach session (new or existing)
            action="a"
            ;;
        u)
            update_script "${OPTARG}"
            exit
            ;;
        d)
            # kill detached sessions
            action="d"
            ;;
        r)
            # Rename existing session
            action="r"
            ;;
        n)
            # Create new named session (pseudo alias of tm -a)
            action="n"
            ;;
        s)
            start_script="${script_dir}/${OPTARG}"
            [ ! -f "${start_script}" ] && Usage && exit_error "Script ${OPTARG} not found in ${start_script}" 3
            ;;
        i)
            do_install
            exit
            ;;
        b)
            attach=false
            ;;
        h)
            Usage
            exit 0
            ;;
    esac
done

# check whether or not sessions are active, and handle action if possible
[ "${action}" == "n" ] || no_sessions

get_sessions

case "${action}" in
    a)
        choose_session
        [[ "${chosen}" == "${last}" ]] && create_session
        tmux a -t "${tmux_sessions[chosen]}"
        ;;
    d)
        kill_detached
        ;;
    r)
        choose_session
        rename_session "${tmux_sessions[chosen]}"
        ;;
    k)
        kill_interactive
        ;;
    n)
        shift $((OPTIND - 1))
        [[ "$#" -ge 1 ]] && name="${1// }"
        if [[ -z "${name}" ]]; then
            name=$(pwd)
            name="${name##*/}"
        fi
        if [ ! -z "${start_script}" ]; then
            tmux new -s "${name}" -d
            TM_SESSION="${name}" . "${start_script}"
            $attach && tmux a -t "${name}"
            exit
        fi
         tmux new -s "${name}"
        exit
esac

