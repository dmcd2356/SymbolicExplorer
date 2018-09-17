# SymbolicExplorer

This is a simple implementation of using a fuzzing technique to iteratively run the DSE with symbolic constraints, solve the constraints, flip the last path taken to get a new path and re-run the DSE until no solution is found.
This uses the z3 solver for finding the paths taken in each run and reads the instruction count at the conclusion of the run to determine the cost.

SymbolicExplorer is Java program that iteratively runs the instrumented Category_7 program, extracts the cost model of the run (the number of instructions executed) and runs the z3 solver to determine if the symbolics are solvable.
If so, it gets the previous constraints used and flips the direction of the last one to generate a new path prior to resetting the program and running again.

It is assumed that both the danalyzer DSE and the Z3 Solver is installed.

== Program Under Test ==

The program being tested is Category 7 of the ISSTAC Canonicals, which consists of a class, Foo, that uses an integer input N to create an array of size N^2 and the Bar method that iterates over the number of entries in the array and sleeps for 1 sec on each entry. The main() method takes a single user input value and limits the value to <= 99 and assigns it to n (parameter 1 of main), then passes it to Foo and calls Foo.Bar. Time is what we are using as our cost model for the program, so we want to determine what user input would yield the longest running time of the program.

To solve this, we define the "n" the parameter in main (parameter 1) as a symbolic value and run the program with an initial user input value of 1, and look for the z3 solver to use the constraints to find a solution that will give us a new branch that we can try on the next attempt. We apply this method repeatedly until there are no solutions left. The main program constrains the user input to <= 99 prior to assigning the value to the parameter "n", so this constraint is not automatically picked up. Therefore, to prevent taking invalid cases, we add a constraint that the value must be <= 9 (if we did 99, the testing time would be ludicrously large) as well as that it must be > 0 to eliminate negative results.

== Test Configuration ==

A danfig file (configuration file for the danalyzer tool) is used to configure the DSE to define the the parameters to make symbolic as well as any additional constraints to place on them. The single symbolic parameter 1 of main is defined in the symbolics list (note that you must use the full name of the method, which includes the full class name and signature and is preceeded by the parameter number for that method and a comma separator.

The user-defined constraints reference the parameter to which they apply by an index of the entry in the symbolic list, starting with an index value of 0. Since in this case there is only 1 entry, the first value of the constraints is "0". The rest of the constraints are the comparison type (EQ, NE, GT, GE, LT, LE), followed by the data type (Integer, Long, Float, Double), and then the comparison value (must be a hard-coded value and not another parameter value).

== Running the Test ==

The run.sh script makes sure that the danhelper agent and SymbolicExplorer have been built, then instruments Canonical_7 using danalyzer and runs SymbolicExplorer.

To run the test, simply type:   ./run.sh

== Results ==

This demonstrates the ability to combine the DSE with a fuzzer to use bit flipping of symbolic constraints to solve for new solutions.
In this case, the initial input selection was 1, which yielded an instruction count of 59 and a solution of 8 on the 1st round, an instruction count of 752 with a solution of 9 on the 2nd run, which yielded an instruction count of 939 and not solvable on the final round.
So the final solution was 9, which is the largest value we allowed in our constraints.

== Notes ==

This requires the following DSE method calls to be publicly accessible as an external API:

- danalyzer.executor.ExecWrapper.getZ3Constraints(tid)

  This returns the Z3 constraints for the specified thread.
  
- danalyzer.executor.ExecWrapper.getZ3Context(tid)

  This returns the Z3 context for the specified thread.

- danalyzer.executor.ExecWrapper.getSymbolicExpression(tid, symbolicParam)

  This returns the Z3 symbolic expression for the specified symbolic parameter and the specified thread.

- danalyzer.executor.ExecWrapper.reset()

  This resets the DSE stack to allow running the program again and still have it retain the user specified symbolic values and constraints.

- danalyzer.gui.DebugUtil.getInstructionCount()

  This gets the current instruction count as determined by the DSE. It allows SymbolicExplorer to calculate a cost for the program run so it can determine if it is heading in the correct direction.
