#!/usr/bin/env ruby
def r( n )
    puts(n)
    if n <= 1
        return 1
    elsif n%2 == 1
        return r((n*3)+1)
    end
    return r(n/2)
end
puts('Basic collatz fun - recursive ruby function')
r(15)
