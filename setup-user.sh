#!/usr/bin/env bash

## For an existing user -> replace /bin/bath with output of which bash
## Or keep this script as-is and remove interactive check from .bashrc
###!/bin/bash -i


rc_file="${HOME}/.bashrc"
load_custom=false
create_config=false
script_name=$(basename "${BASH_SOURCE[0]}")
# IMPORTANT:
#
# this will load the bashrc file, only if the interactive-check is removed, though
# alternatively, replace hashbang with output of "which bash" (probably /bin/bash)
# and use #!/bin/bash -i instead
. ~/.bashrc

Usage() {
    echo "Usage $script_name [-b rc_file [ -l]][-c][-h] Setup user environment"
    echo
    echo "     -b rc_file: The RC file to write to. Defaults to ${HOME}/.bashrc"
    echo "     -l        : Load RC file (if you specified one)"
    echo "     -h        : Display this help message"
    echo "     -c        : create config files (vimrc + tmux)"
    exit "$1"
}

if [ $# -ge 1 ]; then
    while getopts :rlch flag; do
        case $flag in
            r)
                if [ -f "$OPTARG" ]; then
                    rc_file="$OPTARG"
                else
                    echo "$OPTARG is not a file using default $rc_file"
                fi
                ;;
            l)
                load_custom=true
                ;;
            c)
                create_config=true
                ;;
            h)
                Usage 0
                ;;
            *)
                echo "Unknown option $OPTARG"
                Usage 1
                ;;
        esac
    done
fi

$create_config && cp conf/.vimrc ~/ && cp conf/.tmux.conf ~/

# load custom file
if [ "$load_custom" = true ]; then
    . "$rc_file"
fi

## check gopath env var, create directory if not exists
if [ -z "$GOPATH" ]; then
    if [ ! -d "${HOME}/golang" ]; then
        echo "Setting up go (create golang dir and set GOPATH, add it to PATH"
        mkdir "${HOME}/golang"
        echo "export GOPATH='${HOME}/golang'" >> $rc_file
        echo 'export PATH=$PATH:"$GOPATH/bin"' >> $rc_file
    fi
else
    if [ ! -d "$GOPATH" ]; then
        echo "Creating GOPATH dir"
        mkdir "$GOPATH"
    fi
    # make sure to add the bin path to the PATH env var
    if [[ "$PATH" =~ (^|:)"${HOME}/bin"(:|$) ]]; then
        echo "Adding GOPATH to main PATH"
        echo 'export PATH=$PATH:"$GOPATH/bin"' >> $rc_file
    fi
fi

# create github dir
if [ ! -d "${HOME}/github" ]; then
    echo "Creating github dir"
    mkdir "${HOME}/github"
fi

add_git_ps1() {
    echo "Adding __git_ps1 to PS1"
    type __git_ps1 | grep -q "function$"
    # check if __git_ps1 exists, and is a function
    if [ $? -ne 0 ]; then
        echo "__git_ps1 not defined, getting git-completion file"
        #if not, download the file and source it in bashrc
        curl -OL https://github.com/git/git/raw/master/contrib/completion/git-completion.bash -l "${HOME}/.git-completion.bash"
        echo ". ${HOME}/.git-completion.bash" >> $rc_file
    fi
    #add PS1 definition to rc file
    #This changes the prompt to (red)SYS:(green)user@machine:(blue)path (branch)$ 
    echo "Setting PS1"
    echo 'PS1='"'"'${debian_chroot:+($debian_chroot)}\[\e[0;31m\]SYS:\[\e[m\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w`__git_ps1`\[\033[00m\]\$ '"'" >> $rc_file
}
# check if PS1 contains a __git_ps1 call, if not add it
# will also check if __get_ps1 is a function, if not .git-autocomplete.bash will be added
[ $(echo "$PS1" | grep '__git_ps1') ] || add_git_ps1

#check current branch alias
alias currentbranch > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating currentbranch alias"
    echo 'alias currentbranch='"'"'git branch | grep '"'"'"'"'*'"'"'"'"' | awk '"'"'"'"'"'"'"'"'{print $NF;}'"'"'"'"'"'"' >> $rc_file
fi

# check for kill-by-name export
if [ -z KillProc ]; then
    echo "Adding KillProc"
    echo 'KillProc() {
    if [ $# -lt 1 ]; then
        echo "No prog name provided"
    else
        if [ $# -lt 2 ]; then
            count=$(ps -A | grep -c "$1")
        else
            $count="$2"
        fi
        kill_count="$count"
        for pid in $(ps -A | grep "$1" | awk '"'"'{print $1;}'"'"'); do
            kill -9 "$pid"
            (( count-- ))
            if [ $count -le 0 ]; then
                break
            fi
        done
        (( kill_count -= count ))
        echo "$kill_count processes matching '"'"'$1'"'"' killed"
    fi
}
export -f KillProc' >> $rc_file
fi

echo 'Done'
exit 0
