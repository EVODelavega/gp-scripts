(display "Basic collatz fun - recursive scheme function")
(newline)
(define (r n)
    (display n)
    (newline)
    (cond
        ((= 1 n) 1)
        ((= 1 (modulo n 2)) (r (+ (* n 3) 1)))
        (else (r (/ n 2)))))

(r 15)
