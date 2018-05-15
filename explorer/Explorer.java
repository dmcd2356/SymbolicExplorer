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
import static danalyzer.executor.Executor.z3Context;
import static danalyzer.gui.DebugUtil.debugPrintSolve;
import e1e4.Category7_vulnerable;
import java.math.BigInteger;
//import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Explorer {
  
  private Solver z3Solver;
  public Context z3Context;
  private List<BoolExpr> z3Constraints;
  private Map<String, Integer> runningTimes = new HashMap<>();
  
  public Explorer() {
  }

  public String findNewInput() {
    String result = "";    

    // get constraints from the Executor in the running program
    z3Constraints = danalyzer.executor.Executor.getConstraints();
    if (z3Constraints.size() < 1) {
      System.out.println("findNewInput: No constraints found!");
      return result;
    }

    // create new list of constraints and copy all but the last constraint from previous run
    z3Context = danalyzer.executor.Executor.z3Context;
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
        Expr expr = danalyzer.executor.Executor.exprMap.get("e1e4/Category7_vulnerable.main([Ljava/lang/String;)V_1");
        result = z3Solver.getModel().eval(expr, false).toString();
        result = "" + new BigInteger(result).longValue();
        System.out.println(z3Solver.getModel().toString());

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
      System.out.println("------------------ Running Category7 with input = " + currInput);
      try {        
        e1e4.Category7_vulnerable.main(new String[]{currInput});
        instrCount = danalyzer.gui.DebugUtil.getInstructionCount();
        runningTimes.put(currInput, instrCount);
        System.out.println("input: " + currInput + ", instruction count: " + instrCount);
        currInput = findNewInput();
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
