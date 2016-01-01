using System;

namespace c
{
	class Collatz
	{
		public static void Main (string[] args)
		{
			Console.WriteLine ("Basic collatz fun - Recursive mono/C# function");
			r (15);
		}

		private static int r(int n)
		{
			Console.WriteLine (n);
			if (n <= 1)
				return n;
			if ((n & 1) == 1)
				return r (n * 3 + 1);
			return r (n / 2);
		}
	}
}
