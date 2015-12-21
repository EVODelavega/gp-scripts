package main

import "fmt"

type N int

func (v *N) step() *N {
	iv := int(*v)
	if iv <= 1 {
		iv = 1
	} else if iv%2 == 1 {
		iv = iv*3 + 1
	} else {
		iv /= 2
	}
	*v = N(iv)
	return v
}

func (v *N) r() int {
	fmt.Println(int(*v))
	if int(*v) > 1 {
		v.step().r()
	}
	return 1
}

func main() {
	fmt.Println("Basic collatz fun - recursive go function")
	n := N(15)
	n.r()
}
