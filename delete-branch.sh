#!/usr/bin/env bash
#########################
##                     ##
##  Simple script for  ##
##  deleting branches  ##
##  (remote and local) ##
##                     ##
## Takes just one arg  ##
## -> old branch name  ##
#########################

# make sure an argument was passed
[[ $# -gt 0 ]] || exit 1

#get the first argument (branch to delete)
delete_branch="$1"
#work out what branch we're on
current_branch=$(git branch | grep '*' | awk '{print $NF;}')

#make sure we're not deleting the current branch
if [ "$delete_branch" == "$current_branch" ]; then
    echo "Cannot delete the branch you're on..."
    exit 1
fi

#if the branch exists locally, delete it
if $(git branch | grep -q "$delete_branch"); then
    git branch -D "$delete_branch"
fi

#remove the branch from origin (we don't care if this fails)
git push origin :"$delete_branch"

