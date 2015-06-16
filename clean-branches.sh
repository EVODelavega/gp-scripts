#!/usr/bin/env bash

scriptName=$(basename ${BASH_SOURCE[0]})

function Help {
    echo "usage: ${scriptName}:"
    echo "      -h          : Display this help message"
    echo "      -b [master] : choose the default branch to start from (default master)"
    echo "      -r [origin] : Choose the remote to use (default origin). Useful when you have multiple remotes"
    echo "      -m [full]   : Mode -> full, sync or fix (default full)"
    echo "        MODES:"
    echo "              full: delete all local branches, and create new remote"
    echo "                    tracking branches. Useful to clean up old branches"
    echo "              fix : will attempt to set the upstream for all branches"
    echo "                    to their remote counterparts"
    echo "              sync: Same as full, but without deleting the existing branches"
}

function Full {
    echo 'start from master branch'
    git checkout $mainbranch
    echo "removing all branches, except for branch $mainbranch"
    for b in $(git branch) ; do if [ ! "$b" = "$mainbranch" ] ; then git branch -D ${b}; fi done
    echo 'pull latest version'
    git pull --all $remote
    echo 'creating tracking branches for all remote branches'
    for b in $(git ls-remote --heads $remote  | sed 's?.*refs/heads/??'); do git checkout ${b} && git branch --set-upstream-to="$remote/$b"; done
    echo "switching back to $mainbranch"
    git checkout $mainbranch
    echo 'done'
}

function Sync {
    git checkout $mainbranch
    git fetch --all $remote
    for b in $(git ls-remote --heads $remote  | sed 's?.*refs/heads/??'); do git checkout ${b} && git branch --set-upstream-to="$remote/$b"; done
    echo "switching back to $mainbranch"
    git checkout $mainbranch
}

function FixTracking {
    git checkout $mainbranch
    echo "fetching all remote branches from $remote"
    git fetch $remote --all
    for b in $(git branch) ; do git checkout $b && git --set-upstream-to="$remote/$b"; done
    # for b in $(git branch) ; do git checkout $b && git --set-upstream-to=$(echo $b | sed -e 's/^/origin\//'); done
    git checkout $mainbranch
}

mainbranch=master
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
            if [ "$action" = "full" ] || [ "$action" = "fix" ] || [ "$action" = "sync" ] ; then
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
    Sync
fi
exit 0
