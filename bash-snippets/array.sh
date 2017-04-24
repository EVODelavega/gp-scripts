#!/usr/bin/env bash

## Use of arrays, bash 4 specific

## Standard arrays

simple=("foobar" "bar" "foo")
length="${#simple[@]}"

## iterate over arrays

for elem in "${simple[@]}"; do
    echo "${elem}"
done

## print all elements:

echo "All ${length} elements: ${simple[*]}"

## iterate over keys

for k in "${!simple[@]}"; do
    echo "[${k}] => ${simple[$k]}"
done

## Gotcha: returns length of first element (ie foobar -> 6)!

echo "${#simple}"


### ASSOC ARRAYS (Hash tables) - Bash 4 and up

## declare (and initialize) - Note order is *not* preserved!!!

declare -A assoc=( ["key"]="value" ["foo"]="a full sentence" ["another"]="key-value pair" )

## iterate over elements:

for elem in "${assoc[@]}"; do
    echo "${elem}"
done

## k-v iterate is not possible, but iterate over keys:

for k in "${!assoc[@]}"; do
    echo "[${k}] => ${assoc[$k]}"
done

echo "Length: ${#assoc[@]}"

## Gotcha: There are a couple evident, and less evident ones!

## Only prints values!
echo "${assoc[*]}"

## prints keys!
echo "${!assoc[*]}"

## Length works the same as an array (${#arr_name[@]}), but length of first elements
## Doesn't work, probably because there is no real _"first element"_

echo "length first elem: ${#assoc} - DOES NOT WORK (should be ${#assoc[key]})"
