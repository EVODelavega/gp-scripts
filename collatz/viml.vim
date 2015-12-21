" run in vim using command mode (:) source path/to/this/file/viml.vim 
function Rc (n)
    echo a:n
    if a:n == 1
        return
    elseif a:n%2 == 1
        return Rc(a:n*3 + 1)
    endif
    return Rc(a:n/2)
endfunction
echo "Basic collatz fun - recursive vimL function"
call Rc(15)
