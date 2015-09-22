#!/usr/bin/env bash

current_branch=$(git branch | grep '*' | awk '{print $2}')
merge_branch="$current_branch"
merge_master=false
merge_develop=false
delete_branch=true
push_delete=true

script=$(basename "${BASH_SOURCE[0]}")

Usage() {
    echo "Usage $script [-mdhkl][-c merge_branch]:"
    echo "      -c: merge branch (Defaults to current branch)"
    echo "      -m: merge the merge-branch into master"
    echo "      -d: merge the merge-branch into develop"
    echo "      -k: Keep the merge-branch after merging (Default is to delete the branch)"
    echo "      -l: Delete the remote branch locally only (default is to delete the branch remotely)"
    echo "      -h: Display this message"
    echo
    echo "Examples: ./$script -d -m -c hotfix/some_hotfix_branch"
    echo "         This will merge a hotfix into both the master and develop branch"
    echo "         The hotfix branch will then be removed from the local and origin repos"
    echo
    echo "         ./$script -d -l"
    echo "         The current branch will be merged into the develop branch"
    echo "         the merged branch will only be deleted locally"
}

MergeBranchError() {
    echo "Merge branch $merge_branch does not exist. Branches found:"
    for b in $(git branch | awk '{print $NF;}'); do
        if [ "$b" != "master" ] && [ "$b" != "develop" ]; then
            echo " $b"
        fi
    done
    exit 1
}

while getopts mdhc: o ; do
     case $o in
         m)
              merge_master=true
              [[ $(git branch | grep -q master) ]] || merge_master=false
              if [ "$merge_master" = false ]; then
                  echo "no master branch found"
              fi
              ;;
         d)
              merge_develop=true
              [[ $(git branch | grep -q develop) ]] || merge_develop=false
              if [ "$merge_develop" = false ]; then
                  echo "no develop branch found"
              fi
              ;;
         c)
              merge_branch=$OPTARG
              [[ $(git branch | grep -q "$merge_branch") ]] || MergeBranchError
              ;;
         k)
             delete_branch=false
             ;;
         l)
             push_delete=false
             ;;
         h)
              Usage
              exit 0
              ;;
         \?)
              echo "Invalid option: -$o $OPTARG"
              Usage
              exit 1
              ;;
    esac
done

echo "Merging branch $merge_branch"

#master
if [ "$merge_master" = true ]; then
    git checkout master && git pull
    git merge "$merge_branch" --no-edit
    if [ $? -ne 0 ] ; then
        echo "Resolve merge conflicts first"
        exit 0
    fi
    #git push
fi

#develop
if [ "$merge_develop" = true ]; then
    git checkout develop && git pull
    git merge "$merge_branch" --no-edit
    if [ $? -ne 0 ]; then
        echo "Fix merge conflict first, then run git push"
        exit 0
    fi
    #git push
fi

if [ "$merge_branch" == "master" ]; then
    echo "Script will not delete master branch"
    delete_branch=false
fi

if [ "$delete_branch" = true ]; then
    git branch -D "$merge_branch"
    if [ "$merge_branch" == "develop" ]; then
        echo "Script will not delete develop branch remotely"
        push_delete=false
    fi
    if [ "$push_delete" = true ]; then
        git push origin ":$merge_branch"
    fi
fi

echo "$current_branch != $merge_branch ?"

if [ "$merge_branch" != "$current_branch" ]; then
    git checkout "$current_branch"
fi

