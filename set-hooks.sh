#!/usr/bin/env bash

hook_sub_path='.git/hooks'
target='.git/hooks/'
interactive=false
remote_repo='https://github.com/EVODelavega/gp-scripts.git'
cleanup=true
repo_dir='xp-scripts'

scriptName=$(basename "${BASH_SOURCE[0]}")

Usage() {
    echo "Usage $scriptName [-hil][-t target][-r remote]"
    echo
    echo "     -t target: setup hooks in target directory/repo, defaults to local"
    echo "     -r remote: Remote repo to get hooks from"
    echo "     -i       : Interactive, choose which hooks to use"
    echo "     -l       : Leave remote repo after installing hooks, default is to cleanup"
    echo "     -h       : Help - display this message"
    echo
    echo "Examples: in a repo run ./$scriptName -i to interactively install the hooks in the current repo"
    echo "    run ./$scriptName -l -t ../repo -r https://your.url/repo.git to install all hooks in ../repo without cleanup"
}

while getopts hilt:r: opt; do
    case $opt in
        t)
            target=$OPTARG
            if [ "${target: -1}" = "/" ]; then
                hook_sub_path="$hook_sub_path/"
            fi
            target=${target%$hook_sub_path}
            if [ "${target: -1}" = "/" ]; then
                target="${target}${hook_sub_path}"
            else
                target="${target}/${hook_sub_path}"
            fi
            if [ ! -d "$target" ]; then
                echo "$target directory does not exist, check value of $OPTARG"
                exit 1
            fi
            ;;
        i)
            interactive=true
            ;;
        r)
            remote_repo=$OPTARG
            ;;
        h)
            Usage
            exit 0
            ;;
        l)
            cleanup=false
            ;;
        \?)
            echo "Unknown option: -$OPTARG" >&2
            Usage
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            Usage
            exit 1
            ;;
    esac
done

if [[ "$remote_repo" =~ /([^/\.]+)\.git$ ]]; then
    repo_dir="${BASH_REMATCH[1]}"
else
    echo "$remote_repo does not seem to be a valid URL"
    exit 1
fi

echo "attempting to clone $remote_repo in $repo_dir"

git clone "$remote_repo" $repo_dir

for h in $(ls "$repo_dir/hooks"); do
    if $interactive ; then
        echo -n "Set up ${h##"$repo_dir/hooks/"}? [Y/n]: "
        read -n 1 answer
        if [[ $answer =~ ^[nN]$ ]]; then
            echo "Skipping hook"
        else
            cp "${repo_dir}/hooks/$h" "$target"
        fi
    else
        echo "Setting up ${h##"$repo_dir/hooks/"} hook"
        cp "${repo_dir}/hooks/$h" "$target"
    fi
done

if $cleanup ; then
    rm -Rf "$repo_dir"
fi
