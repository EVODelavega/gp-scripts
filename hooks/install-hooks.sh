#!/usr/bin/env bash

##### Install the hooks you want globally ####

template_dir="${HOME}/.git_template"
commit_msg=false
pre_commit=false
pre_rebase=false
add_export=false

Usage() {
    echo "${0##\*/} sets up git hooks globally (by adding them to the template dir)"
    echo "Run ${0##\*/} [-d template-dir [ -a [-mrech]]]"
    echo "      -d dir: The location of the template-dir (default ${template_dir})"
    echo "      -a    : install all hooks"
    echo "      -m    : Install commit-msg hook"
    echo "      -c    : Install pre-commit hook"
    echo "      -r    : Install pre-rebase hook"
    echo "      -h    : Display help message"
    echo "      -e    : Add GIT_TEMPLATE_DIR to rc file (checks .bashrc, then .profile)"
    exit "$1"
}

getEnvFile() {
    if [ -f "${HOME}/.bashrc" ]; then
        echo "${HOME}/.bashrc"
    else
        if [ -f "${HOME}/.profile" ]; then
            echo "${HOME}/.profile"
        else
            echo "Error: could not find bashrc or profile file"
        fi
    fi
}

if [ $# -lt 1 ]; then
    echo "Not enough arguments"
    Usage 1
fi

script_dir="$( cd "$( dirname "${0##\*/}" )" && pwd )/"

while getopts :damrech flag; do
    case $flag in
        d)
            template_dir="$OPTARG"
            if [ ${template_dir:0:1} != "/" ]; then
                echo "${template_dir} looks like a relative path, using ${HOME} as base"
                template_dir="${HOME}/${template_dir}"
            fi
            ;;
        a)
            commit_msg=true
            pre_commit=true
            pre_rebase=true
            ;;
        m)
            commit_msg=true
            ;;
        c)
            pre_commit=true
            ;;
        r)
            pre_rebase=true
            ;;
        e)
            add_export=true
            ;;
        h)
            Usage 0
            ;;
        \?)
            Usage 0
            ;;
        *)
            echo "Unkown option ${flag} ${OPTARG}"
            Usage 1
            ;;
    esac
done

if [ ! -d "${template_dir}" ]; then
    mkdir "${template_dir}"
    mkdir "${template_dir}/hooks"
else
    if [ ! -d "${template_dir}/hooks" ]; then
        mkdir "${template_dir}/hooks"
    fi
fi

if [ "$commit_msg" = true ]; then
    cp "${script_dir}commit-msg" "${template_dir}/hooks"
fi
if [ "$pre_commit" = true ]; then
    cp "${script_dir}pre-commit" "${template_dir}/hooks"
fi
if [ "$pre_rebase" = true ]; then
    cp "${script_dir}pre-rebase" "${template_dir}/hooks"
fi

git config --global init.templatedir "'${template_dir}'"

if [ "$add_export" = true ]; then
    profile_file=$(getEnvFile)
    if [ ${profile_file:0:3} = "Err" ]; then
        echo "${profile_file}, exporting variable for this session only"
        export GIT_TEMPLATE_DIR="${template_dir}"
        exit 1
    fi
    echo "export GIT_TEMPLATE_DIR='${template_dir}'" >> "${profile_file}"
    export GIT_TEMPLATE_DIR="${template_dir}"
fi
