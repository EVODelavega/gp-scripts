#!/usr/bin/env perl
use strict;
use warnings;

sub r {
    print "$_[0]\n";
    return $_[0] == 1 ? 1 : r($_[0]%2 ? $_[0]*3+1 : $_[0]/2);
}
print "Basic collatz fun - recursive perl function\n" and r 15;
#print "Basic collatz fun - recursive perl function\n" and $_=15;
#$\++,$_=$_&1?$_*3+1:$_/2while print "$_\n" and $_>1}{
