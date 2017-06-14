#!/usr/bin/env bash

colour_red='\033[1;31m'
colour_end='\033[0m'

dry_run=false
branch=""
remote=""
detached=false

get_currentbranch() {
    git symbolic-ref --short HEAD
}

Usage() {
    cat <<-__EOF_
${0##*/} [-b name ] [-r remote] [-hd] Remove a branch both locally and remotely
    -b name  : Optionally pass in branch name, if no branch name given, choose a local branch
    -r remote: Optionally specify a remote on which to delete the branch [default blank/origin]
    -d       : dry-run. Instead of actually running the commands, just output the commands
    -h       : display this message

__EOF_
}

choose_branch() {
    local branches
    local selected
    local PS3
    PS3='Please enter your choice (q to quit): '
    branches=( $(git branch | awk '{print $NF;}') )
    select selected in "${branches[@]}"; do
        case $selected in
            "")
                exit 0
                ;;
            *)
                ensure_not_current "${selected}"
                break
                ;;
        esac
    done
    branch="${selected}"
}

ensure_not_current() {
    local b
    local cb
    b="${1:-$branch}"
    cb=$(get_currentbranch)
    if [ "${b}" == "${cb}" ]; then
        echo -e "${colour_red}TRYING TO DELETE CURRENT BRANCH, GOING TO DETACHED HEAD${colour_end}"
        $dry_run &&\
            echo "git checkout \"\$(git log --decorate | grep '(HEAD' | awk '{print \$2;}')\"" &&\
            return
        git checkout "$(git log --decorate | grep '(HEAD' | awk '{print $2;}')"
        detached=true
    fi
}

del_branch() {
    local b
    local resp
    local r
    b="${1}"
    r="${2}"
    if ! git branch -D "${b}"; then
        read -p "Branch ${b} not deleted locally, attempt remote delete? [y/N]: " -r -n 1 resp
        resp="${resp:-N}"
        [[ $resp =~ ^[nN]$ ]] && return
    fi
    git push "${r}" :"${branch}"
}

while getopts dhr:b: f; do
    case $f in
        h)
            Usage
            exit
            ;;
        d)
            dry_run=true
            ;;
        b)
            branch="${OPTARG}"
            ;;
        r)
            remote="${OPTARG}"
            ;;
        *)
            echo "Unknown option ${f}${OPTARG}"
            Usage
            exit 1
            ;;
    esac
done

if [ -z "${branch}" ]; then
    choose_branch
else
    ensure_not_current "${branch}"
fi

## Dry-run, output commands
$dry_run && echo "git branch -D ${branch} && git push ${remote} :${branch}" && exit

del_branch "${branch}" "${remote}"
$detached && echo -e "${colour_red}NOTE: YOU ARE IN DETACHED HEAD, MAKE SURE TO CHECK-OUT A BRANCH${colour_end}"
