#!/usr/bin/env bash

##################################################
##                                              ##
##  Simple script to keep branches organized    ##
##                                              ##
##   lists local and remote branches            ##
##       marks branches that exist              ##
##        * locally only in orange              ##
##        * remote only in blue                 ##
##        * both locally and remotely in yellow ##
##                                              ##
##     automates some cleanup/syncing tasks     ##
##        run with -h flag for details          ##
##                                              ##
##   Use:                                       ##
##  Create local bin dir (eg $HOME/bin)         ##
##  add export PATH="${PATH}:${HOME}/bin" to    ##
##  your .profile/.bashrc file                  ##
##  Make script executable (chmod +x)           ##
##  Run lsrb -h in any git repo                 ##
##                                              ##
##  NOTE: -h flag will not work ouside git repo ##
##                                              ##
##################################################

colour_red='\033[1;31m'
colour_lgreen='\033[0;32m'
colour_green='\033[1;32m'
colour_orange='\033[0;33m'
colour_blue='\033[1;34m'
colour_yellow='\033[1;33m'
colour_end='\033[0m'

Usage() {
    cat <<-__EOF_
${0##*/} Lists remote branches (works anywhere in git repo):
    -r: Remove local branches (interactively)
    -R: Same as -r, without the interaction (only for the brave and/or stupid)
    -s: Sync local branches (uses git pull --ff, stops on error)
    -p: Push new branches (interactively)
    -h: Display help message

Branches are colour-coded:
__EOF_
    echo -e " ${colour_yellow}Yellow${colour_end} are branches that exist locally"
    echo -e " ${colour_blue}Blue${colour_end} are remote only"
    echo -e " ${colour_orange}Orange${colour_end} branches are local only"
    cat <<-__EOD_
 current branch is marked with arrow

__EOD_
}

error_exit() {
    echo -e "${colour_yellow}ERR: ${colour_end}${colour_red}${2:-error}${colour_end}"
    exit "${1:-1}"
}

branch_exists() {
    local e
    for e in "${@:2}"; do
        [[ "$e" == "$1" ]] && return 0
    done
    return 1
}

push_new_branches() {
    for lb in "${removable[@]}"; do
        read -p "Push ${lb} to origin/${lb}? [y/N] " -r -n 1 resp
        [[ $resp =~ ^[yY]$ ]] && git push --set-upstream origin "${lb}"
        echo
    done
}

handle_unstaged_changes() {
    echo -e "${colour_orange}Dirty working tree${colour_end}"
    read -n "Stash changes and continue? [y/N] " -r -n 1 resp
    echo
    [[ $resp =~ ^[yY]$ ]] || exit
    git stash
    pop_stash=true
}

pop_stash=false
action=""

while getopts :rRsph f; do
    case $f in
        h)
            Usage
            exit
            ;;
        r|R|s|p)
            action="${f}"
            ;;
        *)
            echo -e "${colour_red}Unknown option ${OPTARG}${colour_end}"
            Usage
            exit 10
            ;;
    esac
done

[ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1 || error_exit 1 "Not in git repo"

# shellcheck disable=SC2063
current_branch=$(git branch | grep '*' | awk '{print $NF;}')
local_branches=()
remote_branches=()
for lb in $(git branch | awk '{print $NF;}'); do
    local_branches+=("${lb}")
done
for rr in $(git ls-remote 2>/dev/null | grep refs/heads | awk '{print $NF;}'); do
    rr="${rr##refs\/heads/}"
    if branch_exists "${rr}" "${local_branches[@]}"; then
        echo -n -e "${colour_yellow}"
    else
        echo -n -e "${colour_blue}"
    fi
    [ "${rr}" == "$current_branch" ] && echo -n -e "→ "
    echo "${rr}"
    echo -e -n "${colour_end}"
    remote_branches+=("${rr}")
done
echo
removable=()
for b in "${local_branches[@]}"; do
    if ! branch_exists "${b}" "${remote_branches[@]}"; then
        removable+=("${b}")
        [ "${b}" == "${current_branch}" ] && b="→ ${b}"
        echo -e "${colour_orange}${b}${colour_end}"
    fi
done

case $action in
    r)
        [ "${#removable[@]}" -eq 0 ] && echo -e "${colour_lgreen}No branches to remove${colour_end}" && exit
        for rb in "${removable[@]}"; do
            read -p "Delete branch ${rb}? [y/N]: " -r -n 1 resp
            [[ $resp =~ ^[yY]$ ]] && git branch -D "${rb}"
            echo
        done
        ;;
    R)
        [ "${#removable[@]}" -eq 0 ] && echo -e "${colour_lgreen}No branches to remove${colour_end}" && exit
        echo -e "${colour_red}CAREFUL...${colour_end}"
        read -p "All local branches that don't exist on remote will be deleted. Continue? [y/N] " -r -n 1 resp
        echo
        if [[ $resp =~ ^[yY]$ ]]; then
            for lb in "${removable[@]}"; do
                git branch -D "${lb}"
            done
        fi
        ;;
    s)
        # check for unstaged changes (aka dirty working tree)
        git diff-files --quiet || handle_unstaged_changes
        untracked=$(git ls-files --others --exclude-standard | wc -l)
        [ "${untracked}" -gt 0 ] && echo -e "${colour_yellow}Untracked files found, this may cause conflicts...${colour_end}"
        for b in "${remote_branches[@]}"; do
            git checkout "${b}" || exit_error 4 "An error occurred while syncing branches..."
            git pull --ff || exit_error 4 "An error occurred while syncing branches..."
        done
        echo "${colour_green}Branches synced${colour_end}"
        git checkout "${current_branch}"
        $pop_stash && git stash pop
        ;;
    p)
        push_new_branches
        ;;
esac
