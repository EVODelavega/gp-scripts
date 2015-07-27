#!/usr/bin/env bash

SCRIPT=$(basename ${BASH_SOURCE[0]})

verbose=false
idxfile="packidx.log"
forcepush=false
filterflag="--index-filter"
#get current branch
currentbranch=$(git branch | grep '*' | awk '{print $2}')

Help () {
    echo "Usage $SCRIPT [-svfh][-i value]:"
    echo "     -i [packidx.log]: specify an existing file, containing sorted git verify-pack -v output"
    echo "                       Default is to create or prompt to reuse an existing packidx.log file"
    echo "     -v              : verbose output"
    echo "     -s              : slow, use tree-filter instead of index-filter when removing objects"
    echo "     -f              : Force push. Whenever an object is removed from a branch, perform a force-push"
    echo "     -h              : Help. Display this message"
}

AfterFilter () {
    if [ "$verbose" = true ] ; then
        echo 'cleaning up .git/refs/original and .git/logs, then gc the git DB'
    fi
    rm -Rf .git/refs/original
    rm -Rf .git/logs/
    git gc
    if [ "$verbose" = true ] ; then
        echo 'object-count stats after filter'
        git count-objects -v
    fi
    git prune --expire now
    if [ "$verbose" = true ] ; then
        echo 'object-count stats after prune'
        git count-objects -v
    fi
    echo ''
    if [ "$forcepush" = true ] ; then
        git push --force
    else
        read -p 'push the rewritten head? [Y/n]: ' -n 1 -r
        [[ $REPLY =~ ^[nN]$ ]] || git push --force
    fi
}

if [ $# -gt 0 ] ; then
    while getopts :isvfh flag ; do
        case $flag in
            i)
                idxfile=$OPTARG
                ;;
            f)
                forcepush=true
                ;;
            v)
                verbose=true
                ;;
            s)
                filterflag="--tree-filter"
                ;;
            h)
                Help
                exit 0
                ;;
            \?)
                Help
                exit 1
                ;;
        esac
    done
fi

if [ ! -f $idxfile ]; then
    REPLY=y
else
    read -p "create $idxfile file? [y/N]: " -n 1 -r
fi
if [[ $REPLY =~ ^[yY]$ ]]
then
    echo "Creating $idxfile on branch $currentbranch"
    git gc
    packfile=$(ls .git/objects/pack/*.idx)
    git verify-pack -v "$packfile" | sort -k 3 -n > packidx.log
fi

for objectref in $(tac packidx.log | grep blob | cut -d " " -f1); do
    if [ "$verbose" = true ] ; then
        echo 'object-count stats'
        git count-objects -v
    fi
    if [ "$verbose" = true ] ; then
        echo "get filename for object $objectref"
    fi
    filename=$(git rev-list --objects --all | grep $objectref | sed -n -e "s/^$objectref //p")
    read -p "process all commits modifying $filename? [y/N] " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        if [ "$verbose" = true ] ; then
            echo "get all commits modifying $filename"
            git log --oneline --branches -- "$filename"
        fi
        # output is for user info only, use commit refs here:
        commits=() #array of commits
        commitlength=0
        for commit in $(git log --oneline --branches -- "$filename" | awk '{print $1;}'); do
            commits[commitlength]=$commit
            commitlength=$((commitlength+1))
        done
        if (( commitlength == 0 )) ; then
            echo "No commits found for $filename, must be a dangling object"
        else
            commitlength=$((commitlength-1)) #last commit
            for (( i=commitlength; i>0; i--)); do
            #while [ $commitlength -ge 0 ] ; do
                for branch in $(git branch --contains ${commits[$i]} | cut -c 3-) ; do
                    #which branch is rewritten is considered vital info, verbose or not
                    #echo this line
                    echo "rewriting $branch for commit ${commits[$i]}"
                    if [[ ! "$branch" =~ "$currentbranch" ]] ; then
                        git checkout $branch
                    fi
                    git filter-branch --force $filterflag "git rm --ignore-unmatch --cached $filename" --prune-empty -- "${commits[$i]}"^..
                    AfterFilter
                    if [ "$verbose" = true ] ; then
                        echo "$branch rewritten"
                    fi
                    if [[ ! "$branch" =~ "$currentbranch" ]] ; then
                        #return to current branch
                        git checkout $currentbranch
                    fi
                done
                echo $i
            done
            #checkout the initial branch
            git checkout "$currentbranch"
        fi
    fi
    read -p 'continue? [Y/n]: ' -n 1 -r
    if [[ $REPLY =~ ^[nN]$ ]]
    then
        break
    fi
done
echo '' #insert blank line
read -p "remove $idxfile? [y/N]: " -n 1 -r
if [[ $REPLY =~ ^[yY]$ ]]; then
    rm $idxfile
fi
echo '' #new line


exit 0
