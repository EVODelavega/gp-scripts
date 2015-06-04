#!/usr/bin/env bash
read -p 'create packidx.log file? [y/N]: ' -n 1 -r
if [[ $REPLY =~ ^[yY]$ ]]
then
    git gc
    packfile=$(ls .git/objects/pack/*.idx)
    git verify-pack -v "$packfile" | sort -k 3 -n > packidx.log
fi
filterflag="--index-filter"
read -p 'hard-core rm (slow) instead of default (quicker) index-only filter? [y/N]: ' -n 1 -r
if [[ $REPLY =~ ^[yY]$ ]]
then
    filterflag="--tree-filter"
fi
for objectref in $(tac packidx.log | grep blob | cut -d " " -f1); do
    echo 'object-count stats'
    git count-objects -v
    echo "get filename for object $objectref"
    filename=$(git rev-list --objects --all | grep $objectref | sed -n -e "s/^$objectref //p")
    read -p "process all commits modifying $filename? [y/N] " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "get all commits modifying $filename"
        git log --oneline --branches -- "$filename"
        firstcommit=$(git log --oneline --branches -- "$filename" | sed -e '$!d' | cut -d " " -f1)
        echo "rewriting commits using $firstcommit"
        git filter-branch --force $filterflag "git rm --ignore-unmatch --cached $filename" --prune-empty -- "$firstcommit"^..
        echo 'cleaning up .git/refs/original and .git/logs, then gc the git DB'
        rm -Rf .git/refs/original
        rm -Rf .git/logs/
        git gc
        git count-objects -v
        echo 'remove object, using prune'
        git prune --expire now
        echo 'final output stats'
        git count-objects -v
    fi
    read -p 'continue? [Y/n]: ' -n 1 -r
    if [[ $REPLY =~ ^[nN]$ ]]
    then
        exit 0
    fi
done
