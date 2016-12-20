fn main() {
    println!("Basic collatz fun - recursive go function");
    r(15);
}

fn r(n: i32) -> i32 {
    println!("{}", n);
    if n == 1 {
        return 1;
    } else {
        let n2 = if n%2 == 0 { n/2 } else { n*3 + 1 };
        return r(n2);
    }
}
