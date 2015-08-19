//compile: javac java.java
//run: java -cp $(pwd) Collatz
class Collatz
{
    public static void main(String[] args)
    {
        System.out.println("Basic collatz fun - recursive Java function");
        r(15);
    }

    private static int r(int n)
    {
        System.out.printf("%d%n", n);
        if (n <= 1)
            return 1;
        if (n%2 == 0)
            return r(n/2);
        return r((n*3)+1);
    }
}
