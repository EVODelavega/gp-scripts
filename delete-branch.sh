#!/usr/bin/env bash

[[ $# -gt 0 ]] || exit 1

delete_branch="$1"
current_branch=$(git branch | grep '*' | awk '{print $NF;}')

if [ "$delete_branch" == "$current_branch" ]; then
    echo "Cannot delete the branch you're on..."
    exit 1
fi

if $(git branch | grep -q "$delete_branch"); then
    git branch -D "$delete_branch"
fi

git push origin :"$delete_branch"

