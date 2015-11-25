#!/usr/bin/env bash
##
# Attempt to avoid having to type
# for c in $(git rev-list --all); do git ls-tree --name-only -r $c | grep some_bin_file; done
# or worse...
# output might be useful in git filter-branch stuff
##
rev_list='--all'

clean_working_tree () {
    if [[ $(git status --porcelain | grep -P '^ M') ]]; then
        echo "stashing unstaged changes"
        git stash
    fi
    if [[ $(git status --porcelain | grep -P '^M') ]]; then
        echo "Creating temp commit for staged changes"
        git commit -m "Committing staged changes before finding file $file"
    fi
}

Usage () {
    echo " List commits containing a specific file"
    echo " -f <filename>: the file you're looking for"
    echo " -r <refs>    : the ref range to look in (eg abc123^..HEAD), defaults to --all"
    echo " -h           : Display this message"
}

if [ $# -lt 1 ]; then
    Usage
    exit 1
fi

while getopts :f:rh flag ; do
    case $flag in
        f)
            file="$OPTARG"
            ;;
        r)
            rev_list="$OPTARG"
            ;;
        h)
            Usage
            exit 0
            ;;
        \?)
            Usage
            exit 0
            ;;
        *)
            echo "Unknown option $flag $OPTARG"
            Usage
            exit 1
            ;;
    esac
done
if [ -z "$file" ]; then
    echo "the -f argument is required"
    Usage
    exit 1
fi
current_branch=$(git branch | grep '*' | awk '{print $NF;}')
# ensure the working tree is clean (commit staged, stash unstaged)
clean_working_tree
for c in $(git rev-list "$rev_list"); do
    git ls-tree --name-only -r "$c" | grep -q "$file"
    if [ $? -eq 0 ]; then
        echo "Saw $file in $c"
    fi
    # [[ $(git ls-tree --name-only -r "$c" | grep -q "$file") ]] && echo "Saw $file in $r"
done
