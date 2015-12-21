#!/usr/bin/env bash
r () {
    echo "$1"
    #[[ $1 -gt 1 ]] && [[ $(( $1 % 2 )) = 1 ]] && r $(( $1 * 3 + 1 )) || r $(( $1 / 2 ))
    if [ $1 -gt 1 ]; then
        [[ $(( $1 % 2 )) = 1 ]] && r $(( $1 * 3 + 1 )) || r $(( $1 / 2 ))
    fi
}
echo "Basic collatz fun - recursive bash function"
r 15
