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
@addNLConstraint(m, (x1 - 0.5)^2 + (x2 - 0.5)^2 <= 1/π)
@addConstraint(m, x0 - x1 <= 0)
@addConstraint(m, x1 + x2 + x3 <= 2)
#@addNLConstraint(m, 1 <= log(x1/x2))


#d = JuMP.JuMPNLPEvaluator(m, JuMP.prepConstrMatrix(m))
#MathProgBase.initialize(d, [:ExprGraph]);
#MathProgBase.obj_expr(d)
#MathProgBase.constr_expr(d, 1)

solve(m)

# Issue #13
nvar = 10
solver=OsilSolver(solver = "couenne")
m = Model(solver=solver)
@defVar(m, -10 <= x[i=1:nvar] <= 10)
@setNLObjective(m, Min, sum{1/(1+exp(-x[i])), i=1:nvar})
@addConstraint(m, sum{x[i], i=1:nvar} <= .4*nvar)
@test solve(m) == :Optimal
@test isapprox(getValue(x[1]),-10.0)


include(Pkg.dir("JuMP","test","runtests.jl"))
