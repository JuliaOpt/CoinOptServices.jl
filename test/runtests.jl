using OptimizationServices, JuMP
using Base.Test


# type DummyNLPSolver <: MathProgBase.AbstractMathProgSolver
# end
# type DummyNLPModel <: MathProgBase.AbstractMathProgModel
# end
# MathProgBase.model(s::DummyNLPSolver) = DummyNLPModel()
# function MathProgBase.loadnonlinearproblem!(m::DummyNLPModel, numVar, numberOfConstraints, x_l, x_u, g_lb, g_ub, sense, d::MathProgBase.AbstractNLPEvaluator)
#     MathProgBase.initialize(d, [:ExprGraph])
#     println("objexpr = $(MathProgBase.obj_expr(d))")
#     println("isobjlinear(d,1) = $(MathProgBase.isobjlinear(d))")
#     println("isconstrlinear(d,1) = $(MathProgBase.isconstrlinear(d,1))")
#     println("isconstrlinear(d,2) = $(MathProgBase.isconstrlinear(d,2))")
#     println("isconstrlinear(d,3) = $(MathProgBase.isconstrlinear(d,3))")
#     println("constr_expr(d,1) = $(MathProgBase.constr_expr(d,1))")
#     println("constr_expr(d,2) = $(MathProgBase.constr_expr(d,2))")
#     println("constr_expr(d,3) = $(MathProgBase.constr_expr(d,3))")
# end
# #MathProgBase.setwarmstart!(m::DummyNLPModel,x) = nothing
# #MathProgBase.optimize!(m::DummyNLPModel) = nothing
# #MathProgBase.status(m::DummyNLPModel) = :Optimal
# #MathProgBase.getobjval(m::DummyNLPModel) = NaN
# #MathProgBase.getsolution(m::DummyNLPModel) = [1.0,1.0]
# MathProgBase.setvartype!(m::DummyNLPModel, vartype) = nothing

# JuMP version of bonminEx1_Nonlinear.osil
m = Model()
@defVar(m, 0 <= x0 <= 1, Bin)
@defVar(m, x1 >= 0)
@defVar(m, x2 >= 0)
@defVar(m, 0 <= x3 <= 5, Int)
@setObjective(m, Min, x0 - x1 - x2)
#@setNLObjective(m, Min, x1/x2)
@addNLConstraint(m, (x1 - 0.5)^2 + (x2 - 0.5)^2 <= 0.25)
@addConstraint(m, x0 - x1 <= 0)
@addConstraint(m, x1 + x2 + x3 <= 2)
@addNLConstraint(m, 1 <= log(x1/x2))


#A = JuMP.prepConstrMatrix(m)
#d = JuMP.JuMPNLPEvaluator(m, A)
d = JuMP.JuMPNLPEvaluator(m, JuMP.prepConstrMatrix(m))
MathProgBase.initialize(d, [:ExprGraph]);
MathProgBase.obj_expr(d)
MathProgBase.constr_expr(d, 1)
MathProgBase.constr_expr(d, 2)
MathProgBase.constr_expr(d, 3)
MathProgBase.constr_expr(d, 4)



