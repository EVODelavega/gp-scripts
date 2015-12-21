#!/usr/bin/env python
def r(a):
    print('A is '+ str(a))
    return a if a == 1 else r(a*3+1 if a%2 else a/2)

print('Basic collatz fun - recursive python function\n')
r(15)
