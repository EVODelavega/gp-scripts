#!/usr/bin/env bash

usage () {
    echo 'Change filenames using patterns'
    echo ""
    echo "-p <pattern>: the pattern to find the files"
    echo "-r <replace>: The string with which to replace the pattern"
    echo "-h          : Display this help message"
    echo ""
    echo "Example: "
    echo " ./bulk-rename.sh -p \"foo*\" -r \"BAR\""
    echo " renames all files that start with \"foo\" to start with \"BAR\" instead"
}

PATTERN=*
REPLACE=''
while getopts "p:r:h" arg; do
    case $arg in
        p)
            PATTERN=$OPTARG
            ;;
        r)
            REPLACE=$OPTARG
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Unknown option $arg"
            usage
            exit 1
            ;;
    esac
done
for f in $(ls $PATTERN)
do
    mv $f "$REPLACE${f#${PATTERN::-1}}"
done
exit 0
