#!/usr/bin/env perl
use strict;
use warnings;

sub r {
    my ($n) = @_;
    print "$n\n";
    if ($n == 1) {
        return $n;
    }
    if ($n%2) {
        return r(($n*3)+1);
    }
    return r($n/2);
}
print "Basic collatz fun - recursive perl function\n";
r(15);
