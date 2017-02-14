#!/bin/bash

hashes_dir="file-hashes"
whitelist_default="repo/whitelist.yml"
common_roles_job="__common_ansible_roles:"
common_roles=()

compare_current_hashes() {
    local whitelist_file
    whitelist_file="${1:-$whitelist_default}"

    [ ! -e "${whitelist_file}" ] && echo "No whitelist file found: ${whitelist_file}" && exit 1

    ## Make sure the common_roles array is populated
    build_common_list "${whitelist_file}"
    # shellcheck disable=SC2013
    for item in $(grep -E "^[[:alnum:]-]+:" "${whitelist_file}"); do
        echo "${item} Checking files}"
        iter_yaml_list "${item}" "${whitelist_file}"
    done

    rm -rf file-hashes && mv "${hashes_dir}-${BUILD_NUMBER}" "${hashes_dir}"
}

build_common_list() {
    local fname
    fname="${1:-$whitelist_default}"
    # shellcheck disable=SC2013
    for p in $(sed -n "/^${common_roles_job}/,/^\$/p" "$fname" | grep -E '^ +-' | awk '{print $NF;}' | sort); do
        common_roles+=("${p}")
    done
}

is_job_ansible() {
    local fname
    local job
    fname="${2:-$whitelist_default}"
    job="${1}"
    [ -z "${job}" ] && echo "No job given" && exit 5
    sed -n "/^${job}/,/^\$/p" "${fname}" | grep -E '^ +-' | awk '{print $NF;}' | grep -q 'ansible'
    return $?
}

iter_yaml_list() {
    local fname
    local item
    local hash_file

    fname="${2:-$whitelist_default}"
    item="${1}"

    [ ! -e "${fname}" ] && echo "File not found ${fname}" && exit 1
    [ "${#item}" -eq 0 ] && echo "No item to iterate" && exit 2
    ## Skip "meta" job (not needed, grep in compare_current_hashes doesn't match the format)
    ## [ "${item}" = "${common_roles_job}" ] && return 0

    hash_file="${item%:}-${BUILD_NUMBER}"

    ## Magic -> sed grabs all lines starting with <job-name>:
    ## until the end of the yaml array of paths
    ## Grep filters out the array elements, and awk strips the leading dash
    ## These are passed on to git ls-files -s through xargs
    ##           Format: mode sha1 0 file path
    ## The file sha1 hashes are extracted (awk {print $2;}) and written to the hash_file
    printf "" > "${hash_file}"
    # shellcheck disable=SC2013,SC2103
    for p in $(sed -n "/^${item}/,/^\$/p" "${fname}" | grep -E ' +-' | awk '{print $NF;}' | sort); do
        # shellcheck disable=SC2103
        cd repo
        git ls-files -s "${p}" | awk '{print $2;}' >> "../${hash_file}"
        cd -
    done
    ## Common roles are appended on-the-fly, to avoid duplication in whitelist.yml file
    # shellcheck disable=SC2103
    if is_job_ansible "${item}" "${fname}" ; then
        cd repo
        for cr in "${common_roles[@]}"; do
            git ls-files s "${cr}" >> "../${hash_file}"
        done
        cd -
    fi

    if [ ! -e "${hashes_dir}-${BUILD_NUMBER}/${hash_file%-*}" ]; then
        echo "No previous hashes for ${item%:} found, storing current snapshot"
        cp "${hash_file}" "${hashes_dir}-${BUILD_NUMBER}/${item%:}"
    fi

    diff "${hash_file}" "${hashes_dir}-${BUILD_NUMBER}/${item%:}"
    if [ $? -ne 0 ]; then
        echo "Files relating to ${item%:} changed, triggering build"
        trigger_build "${item%:}"
        ## Updated, copy new state over
        cp "${hash_file}" "${hashes_dir}-${BUILD_NUMBER}/${item%:}"
    else
        echo "${item} No changes detected"
    fi

    echo "Cleaning up ${hash_file}"
    rm -f "${hash_file}"
}

trigger_build() {
    local job_name
    job_name="${1}"
    curl "http://${JOBSLINGER_USER}:${JOBSLINGER_PASS}@localhost:8080/job/${job_name}/buildWithParameters?token=${WEBHOOK_TOKEN}&BRANCH_NAME=${BRANCH_NAME}&cause=Build+triggered+by+${BUILD_ID}+Original+executor+${EXECUTOR_NUMBER}"
}

[ ! -e "${hashes_dir}" ] && mkdir "${hashes_dir}"

[ -e "${hashes_dir}-${BUILD_NUMBER}" ] || cp -r "${hashes_dir}" "${hashes_dir}-${BUILD_NUMBER}"

compare_current_hashes "${whitelist_default}"
