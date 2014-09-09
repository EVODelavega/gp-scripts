#! /usr/bin/env bash
usage() {
    echo "Use: ${0:2:${#0}} -f filename [-p prefix] [-l lines] [-h header]"
    echo ""
    echo "     -f: Filename to process, Required argument!"
    echo "     -p: string to prepend to chunk names"
    echo "     -l: Number of lines in each chunk"
    echo "     -h: Header to prepend to each chunk"
    echo ""
}
if [[ $# -eq 0 ]]; then
    usage
    exit 1;
fi
DIRECTORY=.
HEADER=''
numre='^[0-9]+$'
file=''
pref="c"
lines=1000
while getopts ":f:p:l:h:" opt; do
    case "${opt}" in
        f)
            file=$OPTARG
            ;;
        p)
            pref=$OPTARG
            ;;
        l)
            if [[ $OPTARG =~ $numre ]] ; then
                lines=$OPTARG
            else
                echo "Invalid value for $opt: $OPTARG";
                usage
                exit 1;
            fi
            ;;
        h)
            HEADER=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1;
            ;;
    esac
done
split --lines=$lines $file -d $pref
if [[ ${#HEADER} -gt 0 ]] ; then
    for chunk in $DIRECTORY/$pref*; do
        (echo $HEADER; cat $chunk) | sponge $chunk
    done
fi
