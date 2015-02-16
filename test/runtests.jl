using CoinOptServices, JuMP
using Base.Test

# JuMP version of bonminEx1_Nonlinear.osil
m = Model(solver = OsilSolver())
@defVar(m, 0 <= x0 <= 1, Bin)
@defVar(m, x1 >= 0)
@defVar(m, x2 >= 0)
@defVar(m, 0 <= x3 <= 5, Int)
@setObjective(m, Min, x0 - x1 - x2)
#@setNLObjective(m, Min, x1/x2)
@addNLConstraint(m, (x1 - 0.5)^2 + (x2 - 0.5)^2 <= 0.25)
@addConstraint(m, x0 - x1 <= 0)
@addConstraint(m, x1 + x2 + x3 <= 2)
#@addNLConstraint(m, 1 <= log(x1/x2))


#d = JuMP.JuMPNLPEvaluator(m, JuMP.prepConstrMatrix(m))
#MathProgBase.initialize(d, [:ExprGraph]);
#MathProgBase.obj_expr(d)
#MathProgBase.constr_expr(d, 1)

solve(m)


include(Pkg.dir("JuMP","test","runtests.jl"))
