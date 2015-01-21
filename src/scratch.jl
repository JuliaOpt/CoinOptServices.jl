using JuMP

# type DummyNLPSolver <: MathProgBase.AbstractMathProgSolver
# end
# type DummyNLPModel <: MathProgBase.AbstractMathProgModel
# end
# MathProgBase.model(s::DummyNLPSolver) = DummyNLPModel()
# function MathProgBase.loadnonlinearproblem!(m::DummyNLPModel, numVar, numConstr, x_l, x_u, g_lb, g_ub, sense, d::MathProgBase.AbstractNLPEvaluator)
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


using Compat

jl2osnl_varargs = @compat Dict(
    :+     => "sum",
    :*     => "prod")

jl2osnl_binary = @compat Dict(
    :+     => "plus",
    :.+    => "plus",
    :-     => "minus",
    :.-    => "minus",
    :*     => "times",
    :.*    => "times",
    :/     => "divide",
    :./    => "divide",
    :div   => "quotient",
    :÷     => "quotient",
    #:.÷    => "quotient", # 0.4 only?
    :rem   => "rem",
    :^     => "power",
    :.^    => "power",
    :log   => "log")

jl2osnl_unary = @compat Dict(
    :-     => "negate",
    :√     => "sqrt",
    :ceil  => "ceiling",
    :log   => "ln",
    :log10 => "log10",
    :asin  => "arcsin",
    :asinh => "arcsinh",
    :acos  => "arccos",
    :acosh => "arccosh",
    :atan  => "arctan",
    :atanh => "arctanh",
    :acot  => "arccot",
    :acoth => "arccoth",
    :asec  => "arcsec",
    :asech => "arcsech",
    :acsc  => "arccsc",
    :acsch => "arccsch")

for op in [:abs, :sqrt, :floor, :factorial, :exp, :sign, :erf,
           :sin, :sinh, :cos, :cosh, :tan, :tanh,
           :cot, :coth, :sec, :sech, :csc, :csch]
    jl2osnl_unary[op] = string(op)
end

# ternary :ifelse => "if" ?
# comparison ops

jl2osil_vartypes = @compat Dict(:Cont => "C", :Int => "I", :Bin => "B",
    :SemiCont => "D", :SemiInt => "J", :Fixed => "C")
# assuming lb == ub for all occurrences of :Fixed vars

using LightXML

xdoc = XMLDocument()

xroot = create_root(xdoc, "osil")
set_attribute(xroot, "xmlns", "os.optimizationservices.org")
set_attribute(xroot, "xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
set_attribute(xroot, "xsi:schemaLocation", "os.optimizationservices.org " *
    "http://www.optimizationservices.org/schemas/2.0/OSiL.xsd")

instanceHeader = new_child(xroot, "instanceHeader")
add_text(new_child(instanceHeader, "description"),
    "generated by OptimizationServices.jl on " *
    strftime("%Y/%m/%d at %H:%M:%S", time()))

instanceData = new_child(xroot, "instanceData")

variables = new_child(instanceData, "variables")
numVars  = d.m.numCols
varNames = d.m.colNames
varCat   = d.m.colCat
varLower = d.m.colLower
varUpper = d.m.colUpper
set_attribute(variables, "numberOfVariables", "$numVars")
for i = 1:numVars
    vari = new_child(variables, "var")
    set_attribute(vari, "name", varNames[i])
    set_attribute(vari, "type", jl2osil_vartypes[varCat[i]])
    set_attribute(vari, "lb", varLower[i]) # lb defaults to 0 if not specified!
    if isfinite(varUpper[i])
        set_attribute(vari, "ub", varUpper[i])
    end
end
numConstr = length(d.m.linconstr) + length(d.m.quadconstr) + length(d.m.nlpdata.nlconstr)
# JuMP's getNumConstraints returns only the number of linear constraints!

if true # switch this to disable assertions
    macro assertform(x, y)
        msg = "$x expected to be $y, was "
        :($x == $y ? nothing : error($msg * repr($x)))
    end
else
    macro assertform(x, y)
    end
end

#=
function linexpr2sparsevec(ex)
    # convert a linear expression with possibly unordered and/or duplicated
    # indices into a sparse vector representation with sorted, strictly
    # increasing indices by combining duplicates
    # returns (idx::Vector{Int}, vals::Vector{Float64}, constant::Float64)
    @assertform ex.head :call
    exargs = ex.args
    @assertform exargs[1] :+
    nelem = length(exargs) - 1
    idxorig = Array(Int, nelem)
    valorig = Array(Float64, nelem)
    for i = 1:nelem
        (idxorig[i], valorig[i]) = elem2pair(exargs[i+1])
    end
    idx = Array(Int, nelem) # preallocate
    val = Array(Float64, nelem) # preallocate
    constant = 0.0
    ndupes = 0
    permvec = sortperm(idxorig)

end
=#

function elem2pair(elem::Expr)
    # convert Expr of the form :(val * x[idx]) to (idx, val) pair
    @assertform elem.head :call
    elemargs = elem.args
    @assertform elemargs[1] :*
    @assertform length(elemargs) 3
    elemarg3 = elemargs[3]
    @assertform elemarg3.head :ref
    elemarg3args = elemarg3.args
    @assertform elemarg3args[1] :x
    @assertform length(elemarg3args) 2
    return (elemarg3args[2], elemargs[2])
end

function addObjCoef!(obj, elem::Expr)
    # add an objective coefficient from elem to obj
    (idx, val) = elem2pair(elem)
    @assertform typeof(idx) Int
    @assertform typeof(val) Float64
    coef = new_child(obj, "coef")
    set_attribute(coef, "idx", idx-1) # OSiL is 0-based
    add_text(coef, string(val))
end

objectives = new_child(instanceData, "objectives")
set_attribute(objectives, "numberOfObjectives", "1") # can MathProgBase do multi-objective problems?
obj = new_child(objectives, "obj")
set_attribute(obj, "maxOrMin", lowercase(string(d.m.objSense)))
# need to create an OsilMathProgModel type with state, set sense during loadnonlinearproblem!
# then implement MathProgBase.getsense for reading it
objexpr = MathProgBase.obj_expr(d)
if MathProgBase.isobjlinear(d)
    @assertform objexpr.head :call
    objexprargs = objexpr.args
    @assertform objexprargs[1] :+
    for i = 2:length(objexprargs)-1
        # TODO: check if we need to do anything about duplicates or sorting!
        addObjCoef!(obj, objexprargs[i])
    end
    numconstants = 0
    elem = objexprargs[end]
    if isa(elem, Expr)
        addObjCoef!(obj, expr)
    else
        # constant - assume there's at most one, and it's always at the end
        if elem != 0.0
            set_attribute(obj, "constant", elem)
            numconstants = 1
        end
    end
    set_attribute(obj, "numberOfObjCoef", length(objexprargs)-numconstants-1)
else
    set_attribute(obj, "numberOfObjCoef", "0")
    # nonlinear objective goes in nonlinearExpressions, <nl idx="-1">
end

function constr2bounds(ex::Expr, sense::Symbol, rhs::Float64)
    # return (lb, ub) for a 3-term constraint expression
    if sense == :(<=)
        return (-Inf, rhs)
    elseif sense == :(>=)
        return (rhs, Inf)
    elseif sense == :(==)
        return (rhs, rhs)
    else
        error("Unknown constraint sense $sense")
    end
end
function constr2bounds(lhs::Float64, lsense::Symbol, ex::Expr, rsense::Symbol, rhs::Float64)
    # return (lb, ub) for a 5-term range constraint expression
    if lsense == :(<=) && rsense == :(<=)
        return (lhs, rhs)
    else
        error("Unknown constraint sense $lhs $lsense $ex $rsense $rhs")
    end
end

# create constraints section with bounds during loadnonlinearproblem!
# assume no constant attributes on constraints





# writeproblem for nonlinear?


free(xdoc)

