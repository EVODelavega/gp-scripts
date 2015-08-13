<?php
function r($n)
{
    echo $n . PHP_EOL;
    if ($n == 1)
        return $n;
    if ($n%2)
        return r(($n*3)+1);
    return r($n/2);
}
echo 'Basic collatz fun - recursive php function' . PHP_EOL;
r(15);
