#!/usr/bin/env bash

scriptName=$(basename ${BASH_SOURCE[0]})

function Help {
    echo "usage: ${scriptName}:"
    echo "      -h           : Display this help message"
    echo "      -b [current] : choose the default branch to start from (default current)"
    echo "      -r [origin]  : Choose the remote to use (default origin). Useful when you have multiple remotes"
    echo "      -m [full]    : Mode -> full, sync or fix (default full)"
    echo "        MODES:"
    echo "              full : delete all local branches, and create new remote"
    echo "                    tracking branches. Useful to clean up old branches"
    echo "              fix  : will attempt to set the upstream for all branches"
    echo "                    to their remote counterparts"
    echo "              sync : Same as full, but without deleting the existing branches"
    echo "              quick: Just set the tracking to a different remote, quick mode will probably change names soon"
}

function Full {
    echo "start from $mainbranch branch"
    git checkout $mainbranch
    echo "removing all branches, except for branch $mainbranch"
    for b in $(git branch | cut -c 3-) ; do
        if [ ! "$b" = "$mainbranch" ] ; then
            git branch -D ${b};
        fi
    done
    echo 'pull latest version'
    git pull --all $remote
    if [ $? -ne 0 ]; then
        git fetch --all
    fi
    echo 'creating tracking branches for all remote branches'
    for b in $(git ls-remote --heads $remote  | sed 's?.*refs/heads/??'); do
        # pass through detached head to avoid conflicts when switching branches
        git checkout "$remote/$b"
        # now create the branch, it should be up to date already
        git checkout -b $b && git branch --set-upstream-to="$remote/$b"
    done
    echo "switching back to $mainbranch"
    git checkout $mainbranch
    if [ $? -ne 0 ]; then
        echo "Failed to continue, you probably have some merging to do"
        exit 1
    fi
    echo 'done'
}

function Sync {
    git checkout $mainbranch
    git fetch --all
    for b in $(git ls-remote --heads $remote  | sed 's?.*refs/heads/??'); do git checkout -b ${b} && git branch --set-upstream-to="$remote/$b"; done
    echo "switching back to $mainbranch"
    git checkout $mainbranch
}

function FixTracking {
    git checkout $mainbranch
    echo "fetching all remote branches from $remote"
    git fetch --all
    for b in $(git branch | cut -c 3-) ; do
        git checkout $b && git --set-upstream-to="$remote/$b";
    done
    # for b in $(git branch | cut -c 3-) ; do git checkout $b && git --set-upstream-to=$(echo $b | sed -e 's/^/origin\//'); done
    git checkout $mainbranch
}

function SwitchTracking {
    for b in $(git branch); do
        git checkout $b
        if [ $? -eq 0 ]; then
            git branch --set-upstream-to="$remote/$b"
        else
            echo "Could not switch to branch $b"
            read -p 'Skip, or quit [S/q]: ' -n 1 -r
            if [[ ! $REPLY =~ ^[qQ]$ ]]; then
                exit 0
            fi
        fi
        git checkout $b
    done
}

mainbranch=$(git branch | grep '*' | awk '{print $2}')
remote=origin
action='full'

while getopts :m:r:b:h flag; do
    case $flag in
        b)
            mainbranch=$OPTARG
            echo "using $mainbranch as default branch"
            ;;
        r)
            remote=$OPTARG
            echo "using remote $remote"
            ;;
        m)
            action=${OPTARG,,} #convert to lower
            if [ "$action" = "full" ] || [ "$action" = "fix" ] || [ "$action" = "sync" ] || [ "$action" = "quick" ] ; then
                echo "Mode $action"
            else
                Help
                exit 1
            fi
            ;;
        h)
            Help
            exit 0
            ;;
        \?)
            Help
            exit 2
            ;;
    esac
done
if [[ $action =~ ^f ]] ; then
    if [ "$action" = "fix" ] ; then
        FixTracking
    else
        Full
    fi
else
    if [[ $action =~ ^q ]]; then
        SwitchTracking
    else
        Sync
    fi
fi
exit 0
