#!/usr/bin/env bash

###########################################################################
#### For people being forced to use git-flow, but don't really want to ####
####    This script checks branch names, and merges them accordingly   ####
####       Branches with "feature/" prefix are merged into develop     ####
####        Hotfix branches are merged into master, then develop       ####
###########################################################################

script_name=$(basename "${BASH_SOURCE[0]}")
current_branch=$(git branch | grep '*' | awk '{print $NF;}')
interactive=false
push=false
keep=false
remote="origin"
merge_branch="$current_branch"

Usage() {
    echo "$script_name [[-b merge_branch -r origin -i -p -k] -h]"
    echo
    echo "  -b merge_branch: If not the current branch, the branch you want to merge"
    echo "  -r remote      : The remote to push to (defaults to origin)"
    echo '  -i             : Interactive'
    echo '  -p             : Automatically push changes'
    echo '  -k             : Keep merged branch'
    echo '  -h             : Display this help message'
    exit $1
}

## Get merge type
get_merge_type() {
    # Check if branch exists
    git branch | grep -q "$merge_branch"
    if [ $? -ne 0 ]; then
        echo 'e'
    else
        if [[ $merge_branch =~ ^feature ]]; then
            echo 'f'
        else
            if [[ $merge_branch =~ hotfix ]]; then
                echo 'h'
            else
                echo 'e'
            fi
        fi
    fi
}

#function to check current head
clean_working_tree() {
    if [[ $(git status --porcelain | grep -P '^ M') ]]; then
        if [ "$interactive" = true ]; then
            read -p "Unstaged changes detected, continue (and stash changes or quit)? [C/q]: " -n 1 -r
            choice=${RESPONSE:-C}
            echo
            if [[ $choice =~ ^[qQ]$ ]]; then
                echo "exit"
                exit 0
            fi
        fi
        echo "stashing unstaged changes"
        git stash
    fi
    if [[ $(git status --porcelain | grep -P '^M') ]]; then
        if [ "$interactive" = true ]; then
            read -p "Detected staged, uncommited changes. Commit them? [N/y]: " -n 1 -r
            choice=${RESPONSE:-N}
            echo
            if [[ $choice =~ ^[yY]$ ]]; then
                echo "Creating commit"
                git commit -m 'Automatically generated commit'
            else
                echo "exit"
                exit 0
            fi
        else
            echo "Staged changes detected... exit"
            exit 1
        fi
    fi
    echo "Working tree clean"
}

#merge into branch (passed by argument, eg: do_merge 'master')
do_merge() {
    local to_branch="$1"
    git checkout "$to_branch" && git pull "$remote" "$to_branch" --ff
    git merge "$merge_branch"
    check_merge_success
    if [ "$push" = true ]; then
        git push "$remote" "$to_branch"
    fi
    echo "Updated $to_branch on remote $origin"
}

# Check if git merge did not result in conflicts
check_merge_success() {
    if [[ $(git diff --name-only --diff-filter=U) ]]; then
        echo "Merge conflicts detected"
        if [ "$interactive" = true ]; then
            read -p "Abort merge? [Y/n]: " -n 1 -r
            choice=${RESPONSE:-Y}
            echo
            if [[ ! $choice =~ ^[nN]$ ]]; then
                git merge --abort
            fi
            exit 1
        fi
        git merge --abort
        exit 1
    fi
}

if [ $# -ge 1 ]; then
    while getopts :bpikrh flag ; do
        case $flag in
            b)
                merge_branch="$OPTARG"
                ;;
            i)
                interactive=true
                ;;
            p)
                push=true
                ;;
            k)
                keep=true
                ;;
            r)
                remote="$OPTARG"
                ;;
            h)
                Usage 0
                ;;
            \?)
                Usage 0
                ;;
            *)
                echo "Unknown option $flag $OPTARG"
                Usage 1
                ;;
        esac
    done
fi

merge_type=$(get_merge_type)
if [[ $merge_type =~ e ]]; then
    echo "Invalid merge branch (make sure branch exists, and is either hotfix or feature)"
    Usage 1
fi

## merge branch is set, begin merging
if [[ $merge_type =~ h ]]; then
    do_merge "master"
fi
do_merge "develop"
if [ "$keep" = false ]; then
    git branch -D "$merge_branch"
    if [ "$push" = true ]; then
        git push "$remote" :"$merge_branch"
    fi
fi
echo "Done"
exit 0
