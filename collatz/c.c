#include <stdio.h>

static
int r( int n )
{
    printf("%d\n", n);
    if (n <= 1)
        return n;
    if (n%2)
        return r((n*3)+1);
    return r(n/2);
}

int main ( void )
{
    puts("Basic collatz fun - recursive C function");
    r(15);
    return 0;
}
