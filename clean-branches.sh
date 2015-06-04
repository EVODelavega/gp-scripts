#!/usr/bin/env bash
echo 'removing all branches, except for the master branch'
for b in $(git branch) ; do git branch -D ${b##master}; done
echo 'creating tracking branches for all remote branches'
for b in $(git branch -r | grep -v -- '->'); do git checkout -b ${b##origin/} && git branch --set-upstream-to=${b}; done
echo 'switching back to master branch'
git checkout master
echo 'done'
exit 0
