package main

import "fmt"

func main() {
    fmt.Println("Basic collatz fun - recursive go function")
    r(15);
}

func r(n int) int {
    fmt.Println(n);
    if n <= 1 {
        return 1;
    }
    if n%2 == 0 {
        return r(n/2);
    }
    return r(n*3+1);
}
