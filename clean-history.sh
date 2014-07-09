#!/usr/bin/env bash
if [[ "$#" -lt "2" ]]; then
    echo "Not enough arguments: saw $#, expects at least 2"
    exit 1
fi
if [[ "$#" -eq 3 ]]; then
    echo "Replacing all $1 with $2 in range $3 through HEAD"
    git filter-branch --tree-filter "perl -pi -e 's/$1/$2/g' *.php" $3..HEAD
elif [[ "$#" -eq 2 ]]; then
    echo "Replacing all $1 with $2"
    git filter-branch --tree-filter "perl -pi -e 's/$1/$2/g' *.php" HEAD
fi
exit $?
