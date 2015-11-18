#!/usr/bin/env bash

VERSION=false
TICKET=false
INTERACTIVE=false
HOTFIX=true
SRCBRANCH='master'
PUSH=false

version_base="support/release-"

SCRIPT=$(basename ${BASH_SOURCE[0]})

usage () {
    echo "Usage $SCRIPT [-fpih] -v version -t ticket"
    echo "     -v <version>: The target version ($version_base<version>)"
    echo "     -t <ticket> : The ticket to cherry-pick (eg PROJ-123)"
    echo "     -f          : Feature, use develop as source branch instead of master"
    echo "     -i          : Interactive. Prompt for each commit, prompt to continue/exit at critical points"
    echo "     -p          : Automatically push updated release branch at the end"
    echo "     -h/?        : Display this help message"
    echo
    echo "Example: ./$SCRIPT -v 10 -t FOO-1234 -i"
    echo "             (interactively cherry-pick FOO-1234 related commits from master into support/release-10 branch)"
    echo "         ./$SCRIPT -v 10 -t BAR-1234 -f -p"
    echo "             (cherry-pick BAR-1234 related tickets into release-10 branch from develop, then push release-10 branch)"
}

list_commits () {
    for c in $(git cherry -v HEAD $SRCBRANCH | grep -P '^\+\s+[0-9a-f]{40}\s+'"$TICKET" | awk '{print $2;}'); do
        echo "Commit $c found in branches: "
        git branch --contains $c
    done
}

cherry_pick () {
    for c in $(git cherry -v HEAD $SRCBRANCH | grep -P '^\+\s+[0-9a-f]{40}\s+'"$TICKET" | awk '{print $2;}'); do
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
    while getopts :v:t:fpih flag ; do
        case $flag in
            v)
                VERSION="${version_base}${OPTARG}"
                ;;
            t)
                TICKET="$OPTARG"
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

    echo "cherry-picking commits for $TICKET onto $VERSION branch"
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
    # list commits included in the pick
    if [ "$INTERACTIVE" = true ]; then
        read -p 'Continue cherry-picking these commits? [Y/n]: ' -n 1 -r
        if [[ $REPLY =~ ^[nN]$ ]]; then
            echo "exit"
            exit 0
        fi
        echo ''
    fi
    # list branches containing the commits
    list_commits
    if [ "$INTERACTIVE" = true ]; then
        read -p 'Continue cherry-picking? [Y/n]: ' -n 1 -r
        if [[ $REPLY =~ ^[nN]$ ]]; then
            echo "Exit"
            exit 0
        fi
        echo ''
    fi
    cherry_pick
    if [ "$PUSH" = false ] && [ "$INTERACTIVE" = true ]; then
        read -p 'Push changes? [Y/n]: ' -n 1 -r
        [[ $REPLY =~ ^[nN]$ ]] || PUSH=true
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
