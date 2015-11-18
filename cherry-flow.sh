#!/usr/bin/env bash

VERSION=false
TICKET=false
INTERACTIVE=false
HOTFIX=true
SRCBRANCH='master'
PUSH=false

version_base="support/release-"
grep_pattern=""

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
    for c in $(git cherry -v HEAD $SRCBRANCH | grep -P $grep_pattern | awk '{print $2;}'); do
        echo "Commit $c found in branches: "
        git branch --contains $c
    done
}

cherry_pick () {
    for c in $(git cherry -v HEAD $SRCBRANCH | grep -P $grep_pattern | awk '{print $2;}'); do
        if [ "$INTERACTIVE" = true ]; then
            read -p "Cherry-pick commit ${c}? [Y/n/s (show)]: " -n 1 -r
            if [[ $REPLY =~ ^[sS]$ ]]; then
                echo "Showing commit $c"
                git show "$c"
                read -p "Cherry-pick commit ${c}? [Y/n]: " -n 1 -r
            fi
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

get_ticket_pattern () {
    echo '^\+\s+[0-9a-f]{40}\s+'"$TICKET"
}

check_continue_reply () {
    if [[ $REPLY =~ ^[nN]$ ]]; then
        echo "Exit"
        exit 0
    fi
    echo ''
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

    grep_pattern=$(get_ticket_pattern)
    echo "cherry-picking commits for $TICKET onto $VERSION branch"
    # version + OPTARG, TICKET + OPTARG == 4 minimum!
    if [ $# -lt 4 ] || [ "$TICKET" = false ] || [ "$VERSION" = false ]; then
        echo "$SCRIPT requires at least 2 params: version and ticket"
        usage
        exit 1
    fi
    # Check if current branch has unstaged changes -> checkout, quit or stash (default -> stash)
    if [[ $(git status --porcelain | grep -P '^ M') ]]; then
        echo "Detected unstaged changes on current branch"
        if [ "$INTERACTIVE" = true ]; then
            read -p 'Stash changes, checkout changes or quit? [S/c/q]: ' -n 1 -r
            if [[ $REPLY =~ ^[qQ]$ ]]; then
                echo "Exit"
                exit 0
            fi
            if [[ $REPLY =~ ^[cC]$ ]]; then
                echo ''
                for f in $(git status --porcelain | grep -P '^ M' | awk '{print $NF;}'); do
                    echo "Checking out $f"
                    git checkout "$f"
                done
            else
                echo 'Stashing work'
                git stash
            fi
        else
            echo 'Stashing work'
            git stash
        fi
    fi
    # check for staged changes: quit or commit (default -> commit)
    if [[ $(git status --porcelain | grep -P '^M') ]]; then
        echo 'Detected staged changes on current branch'
        if [ "$INTERACTIVE" = true ]; then
            read -p "Create commit and continue? [Y/n]: " -n 1 -r
            check_continue_reply
        fi
        echo "Creating temporary commit"
        git commit -m "Committing staged changes before cherry-picking $TICKET onto $VERSION branch"
    fi
    # using git pull --ff here, in case merge.ff = false in gitconfig
    git checkout $SRCBRANCH && git pull --ff
    git checkout $VERSION
    git pull --ff
    git cherry -v HEAD $SRCBRANCH | grep -P $grep_pattern
    # list commits included in the pick
    if [ "$INTERACTIVE" = true ]; then
        read -p 'Continue cherry-picking these commits? [Y/n]: ' -n 1 -r
        check_continue_reply
        read -p 'Show branches containing these commits? [Y/n]: ' -n 1 -r
        resp=${REPLY:-y}
        if [[ $resp =~ ^[yY]$ ]]; then
            list_commits
            # We should actually prompt to continue here
            # ATM, we're prompting even if user skipped --contains stuff
        else
            echo '' #new line after read
        fi
    else
        # non-interactive: always list branches
        list_commits
    fi
    # Prompt anyway (cf list_commits above) - keep it here, call it an "extra safety feature"
    # mainly laziness, but just in case user has a sticky enter key -> ask twice
    if [ "$INTERACTIVE" = true ]; then
        read -p 'Continue cherry-picking? [Y/n]: ' -n 1 -r
        check_continue_reply
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
    echo "Done"
else
    usage
    exit 1
fi
exit 0
