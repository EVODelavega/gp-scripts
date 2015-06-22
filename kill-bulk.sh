#!/usr/bin/env bash
####################################
##                                ##
##    A simple script to kill     ##
##    processes like chromium     ##
##    when they're giving you     ##
##         grief again            ##
##                                ##
##   Usage: ./kill-bulk chromium  ##
##                                ##
####################################
if [[ $# -ne 1 ]]; then
    echo "No processes to kill"
    exit 1
fi

for arg; do
    echo "Killing all $arg processes"
    for pid in $(ps -A | grep $1 | awk '{print $1}'); do
        echo kill -9 "$pid"
    done
done

exit 0
