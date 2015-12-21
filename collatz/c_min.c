#include <stdio.h>
#include <stdlib.h>

long r( long n )
{
    printf("%ld\n", n);
    return n <= 1 ? 1 : r(n%2 ? n*3+1 : n/2);
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
