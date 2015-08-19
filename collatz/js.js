var r = function(n)
{
    console.log(n);
    if (n <= 1)
        return 1;
    if (n%2)
        return r((n*3)+1);
    return r(n/2);
};
console.log('Basic collatz fun - recursive JavaScript function');
r(15);
