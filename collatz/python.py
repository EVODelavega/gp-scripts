def r(a):
    print('A is '+ str(a))
    if a == 1:
            return a
    if a%2 == 0:
            return r(int(a/2))
    else:
            return r((a*3)+1)

print('Basic collatz fun - recursive python function\n')
r(15)
