#!/usr/bin/env bash

current_branch=$(git branch | grep '*' | awk '{print $NF}')
script_name=$(basename ${BASH_SOURCE[0]})
remote="origin"
push=true
interactive=false
multiple=false
specified_branch=false

Usage() {
    echo "$script_name -b name [-lmihr remote]"
    echo
    echo "    -b name  : Name of branc to delete. Will be used in grep pattern, so part of the name will do"
    echo "    -r remote: Remote to push deletes to - defaults to origin"
    echo "    -l       : Local only - Do not push deletion to remote"
    echo "    -m       : Multiple branches - If b argument is a pattern, use -m to delete multiple branches"
    echo "    -i       : Interactive, recommended when deleting multiple branches"
    echo "    -h       : Display this help message"
    exit "$1"
}

remote_exists() {
    local rc=$(git remote | grep -c "$remote")
    if [ $rc -ne 1 ]; then
        echo "Remote $remote does not exist"
        exit 1
    fi
}

delete_branch() {
    local br="$1"
    if [ "$br" == "$current_branch" ]; then
        echo "$br is the current branch - checkout another branch, to delete it"
    fi
    git branch -D "$br"
    if [ "$push" = true ]; then
        git push "$remote" :"$br"
    fi
}


#Uses argument as pattern, then deletes all matches (1 or more)
delete_matches() {
    for b in $(git branch | grep "$branch" | awk '{print $NF;}'); do
        if [ "$interactive" = true ]; then
            read -p "Delete branch $b? [Y/n]: " -n 1 -r
            choice=${RESPONSE:-Y}
            echo
            if [[ $choice =~ ^[nN]$ ]]; then
                echo "Skipping ${b}..."
            else
                delete_branch $b
            fi
        else
            delete_branch $b
        fi
    done
}

if [ $# -lt 1 ]; then
    echo "No arguments provided"
    Usage 1
fi


while getopts :b:rlimh flag ; do
    case $flag in
        b)
            branch="$OPTARG"
            ;;
        r)
            remote="$OPTARG"
            ;;
        l)
            push=false
            ;;
        i)
            interactive=true
            ;;
        m)
            multiple=true
            ;;
        h)
            Usage 0
            ;;
        \?)
            Usage 0
            ;;
        *)
            echo "Unknown option $flag $OPTARG "
            Usage 1
            ;;
    esac
done

if [ -z "$branch" ]; then
    echo "No branch specified: -b flag is required"
    Usage 1
fi

branch_count=$(git branch | grep -c "$branch")

if [ $branch_count -lt 1 ]; then
    echo "Branch $branch not found"
    exit 0
fi

remote_exists

if [ $branch_count -gt 1 ]; then
    if [ "$multiple" = false ]; then
        echo "$branch matches more than one branch, use -m and -i flags to delete interactively"
        exit 1
    fi
    if [ "$interactive" = false ]; then
        echo "You are about to delete multiple branches, non interactively... Branches are:"
        git branch | grep "$branch"
    fi
fi

#whether it's one or more branches, the basic logic is the same...
delete_matches
