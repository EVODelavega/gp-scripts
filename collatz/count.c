#include <stdio.h>
#include <stdlib.h>

struct step_count {
    long start;
    long max;
    size_t steps;
};

static
long r(long n, struct step_count* cnt)
{
    printf("%ld\n", n);
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

int main (int argc, char **argv)
{
    long n = 15;
    if (argc > 1)
        n = strtol(argv[1], NULL, 10);
    struct step_count cnt = {n, n, 0};
    puts("Basic collatz fun - recursive C function");
    r(n, &cnt);
    printf(
            "Started with %ld. Reached end after %zu steps\nHighest value was %ld\n",
            cnt.start,
            cnt.steps,
            cnt.max
    );
    return 0;
}
