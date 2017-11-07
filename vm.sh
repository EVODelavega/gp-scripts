#!/usr/bin/env bash

Usage() {
    cat <<-__EOF_
${0##*/} Opens scripts in PATH from any location (vim -O)
    Example: ${0##*/} ${0##*/}
                opens this script in vim editor
    -o: Change default behaviour (vim -O) to -o
    -b: Change default behaviour to open in buffers (vim file1 file2)
    -h: Display this message
__EOF_
}

flag="O"

vimopen() {
    local wrapped
    local located
    local found
    found=false
    [ $# -lt 1 ] && echo "No script given" && return
    wrapped=""
    for arg in "$@"; do
        if located=$(which "${arg}"); then
            found=true
            wrapped="${wrapped} ${located}"
        else
            echo "${arg} not found!"
        fi
    done
    $found || return
    # We WANT word splitting to occur here
    # shellcheck disable=SC2086
    case ${flag} in
        O)
            vim $wrapped -O
            ;;
        o)
            vim $wrapped -o
            ;;
        *)
            vim $wrapped
    esac
}

while getopts :boh f; do
    case $f in
        h)
            Usage
            exit 0
            ;;
        o)
            flag="o"
            shift
            ;;
        b)
            flag=""
            shift
            ;;
        *)
            echo "Unknown option ${f}-${OPTARG}"
            Usage
            exit 1
            ;;
    esac
done
vimopen "$@"
