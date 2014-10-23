#!/usr/bin/env bash
submodpath() {
    SUB_PATH=${1}
    for subdir in $(ls "$MOD_ROOT/$SUB_PATH")
    do
        config="$MOD_ROOT/$SUB_PATH/$subdir/config"
        if [ -f $config ] ; then
            echo "Found submodule $SUB_PATH/$subdir"
            SUBMODULES+=("$SUB_PATH/$subdir")
        else
            submodpath "$SUB_PATH/$subdir"
        fi
    done
}
if [ ! -d .git ] ; then
    echo "No .git directory found"
    exit 1
fi

git stash && git pull && git submodule update --init

if [ ! -d .git/modules ] ; then
    echo "No modules found"
    exit 0
fi

MOD_ROOT=".git/modules"
TO_ADD=()
SUBMODULES=()

for submod in $(ls $MOD_ROOT)
do
    TO_ADD+=($submod)
    submodpath "$submod"
done

for module in "${SUBMODULES[@]}"
do
    echo "removing submodule $module"
    git rm --cached "$module"
    if [ -f "$module/.git" ] ; then
        rm "$module/.git"
    else
        echo "No .git ref-file found"
    fi
done

if [ -f .gitmodules ] ; then
    echo "Remove .gitmodules file"
    rm .gitmodules
fi

echo "Adding submodules to main repo"
for add_path in "${TO_ADD[@]}"
do
    echo "Add submodule(s) in path $add_path"
    git add --all "$add_path"
done
echo "Done... now commit && push!"
exit 0
