# SymbolicExplorer

This is a simple implementation of using a fuzzing technique to iteratively run the DSE with symbolic constraints, solve the constraints, flip the last path taken to get a new path and re-run the DSE until no solution is found.
This uses the z3 solver for finding the paths taken in each run and reads the instruction count at the conclusion of the run to determine the cost.
The program being tested is Category 7 of the ISSTAC Canonicals, which consists of a class, Foo, that uses an integer input N to create an array of size N^2 and the Bar method that iterates over the number of entries in the array and sleeps for 1 sec on each entry.
The main() method takes a single user input value and limits the value to <= 99 and assigns it to n (parameter 1 of main), then passes it to Foo and calls Foo.Bar.
We define a danfig file to make "n" the symbolic value (parameter 1 of main), but because the value is assigned to n after it constrains the value, we also add a constraint that the value must be <= 9 (if we did 99, the testing time would be ludicrously large).

The run.sh script makes sure that the danhelper agent and SymbolicExplorer have been built, then instruments Canonical_7 using danalyzer and runs SymbolicExplorer.

SymbolicExplorer is another Java program that iteratively runs the instrumented Category_7 program, extracts the cost model of the run (the number of instructions executed) and runs the z3 solver to determine if the symbolics are solvable.
If so, it gets the previous constraints used and flips the direction of the last one to generate a new path prior to resetting the program and running again.

This demonstrates the ability to combine the DSE with a fuzzer to use bit flipping of symbolic constraints to solve for new solutions.
In this case, the initial input selection was 1, which yielded an instruction count of 53 and a solution of 8 on the 1st round, an instruction count of 683 with a solution of 9 on the 2nd run, which yielded an instruction count of 853 and not solvable on the final round.
So the final solution was 9, which is the largest value we allowed in our constraints.
