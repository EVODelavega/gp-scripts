#!/usr/bin/env php
<?php
function r($n) {
    echo $n . PHP_EOL;
    return $n == 1 ? $n : r($n%2 ? $n*3+1 : $n/2);
}

echo 'Basic collatz fun - recursive PHP function' . PHP_EOL;
r(15);
