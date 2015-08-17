#!/usr/bin/env bash
r () {
    local n="$1"
    echo "$n"
    if [ "$n" -le 1 ]; then
        return 1
    fi
    if [[ $(( n % 2 )) == 0 ]]; then
        r $(( n / 2 ))
    else
        r $(( n * 3 + 1 ))
    fi
}
echo "Basic collatz fun - recursive bash function"
r 15
