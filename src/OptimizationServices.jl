module OptimizationServices

include("translations.jl")

using MathProgBase
importall MathProgBase.SolverInterface

export OsilSolver
immutable OsilSolver <: AbstractMathProgSolver
    options
end
OsilSolver(; kwargs...) = OsilSolver(kwargs)

export addLinElem!, expr2osnl!, @assertform

if true # switch this to disable assertions
    macro assertform(x, y)
        msg = "$x expected to be $y, was "
        :($x == $y ? nothing : error($msg * repr($x)))
    end
else
    macro assertform(x, y)
    end
end

function addLinElem!(indicator, densevals, elem::Expr)
    # convert Expr of the form :(val * x[idx]) to (idx, val)
    # then set indicator[idx] = true; densevals[idx] += val
    @assertform elem.head :call
    elemargs = elem.args
    @assertform elemargs[1] :*
    @assertform length(elemargs) 3
    elemarg3 = elemargs[3]
    @assertform elemarg3.head :ref
    elemarg3args = elemarg3.args
    @assertform elemarg3args[1] :x
    @assertform length(elemarg3args) 2
    idx::Int = elemarg3args[2]
    indicator[idx] = true
    densevals[idx] += elemargs[2]
    return 0.0
end
function addLinElem!(indicator, densevals, elem)
    # for elem not an Expr, assume it's a constant term and return it
    return elem
end

#=
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
=#

function expr2osnl!(parent, ex::Expr)
    # convert nonlinear expression from Expr to OSnL,
    # adding any new child xml elements to parent
    head = ex.head
    args = ex.args
    numargs = length(args)
    if head == :call
        if numargs < 2
            error("Do not know how to handle :call expression $ex with fewer than 2 args")
        elseif numargs == 2
            child = new_child(parent, jl2osnl_unary[args[1]])
            expr2osnl!(child, args[2])
        elseif numargs == 3
            # TODO: check for special cases:
            # square, coef * variable
            child = new_child(parent, jl2osnl_binary[args[1]])
            expr2osnl!(child, args[2])
            expr2osnl!(child, args[3])
        else
            child = new_child(parent, jl2osnl_varargs[args[1]])
            for i = 2:numargs
                expr2osnl!(child, args[i])
            end
        end
    elseif head == :ref
        @assertform args[1] :x
        @assertform numargs 2
        idx::Int = args[2]
        child = new_child(parent, "variable")
        set_attribute(child, "idx", idx - 1) # OSiL is 0-based
    else
        error("Do not know how to handle expression $ex with head $head")
    end
    return child
end
function expr2osnl!(parent, ex)
    # for anything not an Expr, assume it's a constant number
    child = new_child(parent, "number")
    set_attribute(child, "value", ex)
    return child
end

end # module
