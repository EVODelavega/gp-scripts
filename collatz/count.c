#include <stdio.h>
#include <stdlib.h>

struct step_count {
    unsigned long start;
    unsigned long max;
    size_t steps;
};

static
unsigned long r(unsigned long n, struct step_count* cnt)
{
    printf("%lu\n", n);
    //do not count last step, we're counting the initial call
    //causing 63,728,127 to count 950 steps instead of expected 949
    if (n <= 1)
        return n;
    ++cnt->steps;
    if (cnt->max < n) {
        cnt->max = n;
    }
    if (n%2)
        return r(n*3+1, cnt);
    return r(n/2, cnt);
}

static
int validate_input(long n)
{
    if (n <= 0)
    {
        puts("input is expected to be > 0");
        return -1;
    }
    if (n == 1)
        puts("Silly: 1 == 1, but ah well...");
    return 0;
}

int main (int argc, char **argv)
{
    long n = 15;
    if (argc > 1)
    {
        n = strtol(argv[1], NULL, 10);
        if (validate_input(n))
            return EXIT_FAILURE;
    }
    struct step_count cnt = {n, n, 0};
    puts("Basic collatz fun - recursive C function");
    r(n, &cnt);
    printf(
            "Started with %lu. Reached end after %zu steps\nHighest value was %lu\n",
            cnt.start,
            cnt.steps,
            cnt.max
    );
    return 0;
}
