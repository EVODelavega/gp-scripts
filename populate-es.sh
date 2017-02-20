#!/usr/bin/env bash

data_file="input.json"
ids=()
idx="es_idx_name"
estype="es_type_name"
es_host="localhost:9200"
id_key="_id"
confirm=false

usage() {
    local ex_code
    ex_code="${1:-0}"
    cat <<-__EOF_
${0##*/} [-i idx] [-t type] [-f file] [-H host ] [-k id key] [-c] [-h]
Add documents in file to ES
flags:

         -i index: ES index name
         -t type : ES document type
         -f file : json input file (defaults to input.json)
         -H host : ES host (defaults to localhost:9200)
         -k key  : document id key in json file (defaults to _id)
         -c      : Ask for confirmation (default false)
         -h      : display this message

Example JSON format:
[
    {
        "_id": "123",
        "field1": "foobar",
        "nested": {
            "inner": "string field",
            "another": 123,
        }
    },
    {
        "_id": "456",
        "field1": "second document",
        "nested" {
            "inner": "...",
            "another": 0
        }
    },
    {}
]

Note: The trailing empty object is necessairy, as is quoting the id (although we're working on this)
__EOF_

    exit "${ex_code}"
}

jq_installed() {
    command -v jq >/dev/null 2>&1 && return
    echo >&2 "jq not found, ${0##*/} depends on jq to parse the json file"
    exit 2
}

get_ids() {
    for id in $(jq -r ".[] | .${id_key}" "${data_file}"); do
        ids+=("${id}")
    done
}

get_payload_for_id() {
    local id
    local payload
    id="${1}"
    [ -z "${id}" ] && echo "No id given" && exit 1
    payload=$(sed -n "/\"${id_key}\": \"${id}\"/,/},/p" "${data_file}")
    [ ! -z "${payload}" ] && echo "{${payload%,}"
}

prompt_curl() {
    local id
    local payload
    local resp
    id="${1}"
    payload="${2}"
    read -p "Insert document ID ${id}? [Y/n/s] " -r -n 1 resp
    resp="${resp:-y}"
    if [[ "${resp}" =~ ^[sS]$ ]]; then
        echo "Showing document: "
        echo "${payload}"
        local ret
        ret=$(prompt_curl "${id}" "${payload}" )
        return "${ret}"
    fi
    if [[ "${resp}" =~ ^[nN]$ ]]; then
        return 1
    fi
    return 0
}

do_curl() {
    local payload
    for id in "${ids[@]}"; do
        payload=$(get_payload_for_id "${id}")
        if $confirm && ! prompt_curl "${id}" "${payload}"; then
            echo "skipping ${id}"
            continue
        fi
        curl -XPUT "${es_host}/${idx}/${estype}/${id}?pretty" \
            -H 'Content-Type: application/json' \
            -d "${payload}"
    done
}

## Check prerequisites first
jq_installed

if [ "$#" -gt 0 ]; then
    while getopts :i:t:f:H:k:ch opt; do
        case $opt in
            i)
                idx="${OPTARG}"
                ;;
            t)
                estype="${OPTARG}"
                ;;
            f)
                data_file="${OPTARG}"
                ;;
            H)
                es_host="${OPTARG}"
                ;;
            k)
                id_key="${OPTARG}"
                ;;
            c)
                confirm=true
                ;;
            h)
                usage 0
                ;;
            *)
                echo >&2 "Unknown option ${OPTARG}"
                usage 1
                ;;
        esac
    done
fi

echo "Extracting ID's from file"
get_ids
echo "Found ID's:"
for id in "${ids[@]}"; do
    echo "${id}"
done
echo "Adding documents to ES"
do_curl
echo "Done"
