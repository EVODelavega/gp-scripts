r <- function(i) {
    print(i)
    if (i==1) {
        return(i)
    } else {
        if (i%%2 == 1) {
            return(r((i*3)+1))
        }
        return(r(i/2))
    }
}
print('Basic collatz fun - recursive R function')
r(15)
