/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package explorer;

import com.microsoft.z3.BoolExpr;
import com.microsoft.z3.Context;
import com.microsoft.z3.Expr;
import com.microsoft.z3.Solver;
import com.microsoft.z3.Status;
import com.microsoft.z3.BitVecNum;
import java.math.BigInteger;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// the program to explore
import e1e4.Category7_vulnerable;

public class Explorer {

  // the symbolic parameter to track
  private String symbolicParam = "e1e4/Category7_vulnerable.main([Ljava/lang/String;)V_1";

  private Solver z3Solver;
  public Context z3Context;
  private List<BoolExpr> z3Constraints;
  private Map<String, Integer> runningTimes = new HashMap<>();
  
  public Explorer() {
  }

  public int getCostModel() {
    return danalyzer.gui.DebugUtil.getInstructionCount();
  }

  public String fuzzer_bitFlip() {
    String result = "";    

    // get constraints from the Executor in the running program
    z3Constraints = danalyzer.executor.Executor.getConstraints();
    if (z3Constraints.size() < 1) {
      System.out.println("fuzzer_bitFlip: No constraints found!");
      return result;
    }

    // create new list of constraints and copy all but the last constraint from previous run
    z3Context = danalyzer.executor.Executor.getZ3Context();
    z3Solver = z3Context.mkSolver();
    for (int i = 0; i < z3Constraints.size() - 1; i++) {
      z3Solver.add(z3Constraints.get(i));
    }

    // flip last constraint of the previos run and add it
    BoolExpr lastExpr = z3Constraints.get(z3Constraints.size() - 1);
    z3Solver.add(z3Context.mkNot(lastExpr));

    // run z3 solver to check for solution
    while (true) {
      System.out.println(z3Solver.toString());
      Status status = z3Solver.check();

      if (status == Status.SATISFIABLE) {
        // solvable - get next solution
        Expr expr = danalyzer.executor.Executor.getSymbolicExpression(symbolicParam);
        result = z3Solver.getModel().eval(expr, false).toString();
        result = "" + new BigInteger(result).longValue();
        System.out.println(z3Solver.getModel().toString());

        // check if we've done this before
        if (runningTimes.containsKey(result)) {
          z3Solver.add(z3Context.mkNot(z3Context.mkEq(expr, z3Solver.getModel().eval(expr, false))));
          continue;
        }
        System.out.println("Constraints satisfiable. Result: " + result);
        break;
      } else if (status == Status.UNSATISFIABLE) {
        System.out.println("Constraints not satisfiable.");
        result = "";
        break;
      } else {
        System.out.println("Constraints solving unknown.");
        result = "";
        break;
      }
    }
    
    danalyzer.executor.Executor.reset();
    return result;
  }
  
  public void explore() {    
    String currInput = "1";
    int instrCount = 0;
    
    while (!currInput.equals("")) {
      System.out.println("------------------ Running test with input = " + currInput);
      try {
        // run program with current input value
        e1e4.Category7_vulnerable.main(new String[]{currInput});

        // get the cost for the last run and map it to the input used to derrive it
        instrCount = getCostModel();
        runningTimes.put(currInput, instrCount);
        System.out.println("input: " + currInput + ", instruction count: " + instrCount);

        // get next input value from solver
        currInput = fuzzer_bitFlip();
      } catch (InterruptedException e) {
        System.err.println("Interrupted: " + e.getStackTrace());
      }
    }
  }
  
  public static void main(String[] args) {
    Explorer explorer = new Explorer();
    explorer.explore();
  }
}
