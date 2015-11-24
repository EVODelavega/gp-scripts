#include <stdio.h>
#include <stdlib.h>

static
long r( long n )
{
    printf("%ld\n", n);
    if (n <= 1)
        return n;
    if (n%2)
        return r((n*3)+1);
    return r(n/2);
}

int main (int argc, char **argv)
{
    long n = 15;
    if (argc > 1)
        n = strtol(argv[1], NULL, 10);
    puts("Basic collatz fun - recursive C function");
    r(n);
    return 0;
}
