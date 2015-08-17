#!/usr/bin/env bash

VERSION=false
TICKET=false
INTERACTIVE=false
HOTFIX=true
SRCBRANCH='master'
PUSH=false

SCRIPT=$(basename ${BASH_SOURCE[0]})

usage () {
    echo "Usage $SCRIPT [-fpih] -v version -t ticket"
    echo "     -v <version>: The target version (support/release-<version>)"
    echo "     -t <ticket> : The ticket to cherry-pick (eg PROJ-123)"
    echo "     -f          : Feature, use develop as source branch instead of master"
    echo "     -i          : Interactive. Prompt for each commit, prompt to continue/exit at critical points"
    echo "     -p          : Automatically push updated release branch at the end"
    echo "     -h/?        : Display this help message"
}

list_commits () {
    for c in $(git cherry -v HEAD $SRCBRANCH | grep "$TICKET" | awk '{print $2;}'); do
        echo "Commit $c found in branches: "
        git branch --contains $c
    done
}

cherry_pick () {
    for c in $(git cherry -v HEAD $SRCBRANCH | grep "$TICKET" | awk '{print $2;}'); do
        if [ "$INTERACTIVE" = true ]; then
            read -p "Cherry-pick commit ${c}? [Y/n]: " -n 1 -r
            if [[ $REPLY =~ ^[nN]$ ]]; then
                echo "Skipping..."
            else
                echo ''
                git cherry-pick -x $c
            fi
        else
            git cherry-pick -x $c
        fi
    done
}

if [ $# -gt 0 ]; then
    while getopts :v:tfpih flag ; do
        case $flag in
            v)
                VERSION="support/release-$OPTARG"
                ;;
            t)
                TICKET=$OPTARG
                ;;
            i)
                INTERACTIVE=true
                ;;
            f)
                HOTFIX=false
                SRCBRANCH='develop'
                ;;
            p)
                PUSH=true
                ;;
            h)
                usage
                exit 0
                ;;
            \?)
                usage
                exit 0
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done
    echo $TICKET
    # version + OPTARG, TICKET + OPTARG == 4 minimum!
    if [ $# -lt 4 ] || [ "$TICKET" = false ] || [ "$VERSION" = false ]; then
        echo "$SCRIPT requires at least 2 params: version and ticket"
        usage
        exit 1
    fi
    git checkout $SRCBRANCH && git pull
    git checkout $VERSION
    git pull
    git cherry -v HEAD $SRCBRANCH | grep "$TICKET"
    if [ "$INTERACTIVE" = true ]; then
        read -p 'Continue cherry-picking these commits? [Y/n]: ' -n 1 -r
        [[ $REPLY =~ ^[nN]$ ]] || echo 'exit' && exit 0
        echo ''
    fi
    list_commits
    if [ "$INTERACTIVE" = true ]; then
        read -p 'Continue cherry-picking? [Y/n]: ' -n 1 -r
        [[ $REPLY =~ ^[nN]$ ]] || echo 'Exit' && exit 0
        echo ''
    fi
    cherry_pick
    if [ "$PUSH" = false ] && [ "$INTERACTIVE" = true ]; then
        read -p 'Push changes? [y/N]: ' -n 1 -r
        [[ $REPLY =~ ^[yY]$ ]] || PUSH=true
        echo ''
    fi
    if [ "$PUSH" = true ]; then
        git push
    fi
else
    usage
    exit 1
fi
exit 0
