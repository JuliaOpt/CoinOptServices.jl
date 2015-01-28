#export jl2osnl_varargs, jl2osnl_binary, jl2osnl_unary, jl2osil_vartypes,
#    addLinElem!, expr2osnl!

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
    :abs2  => "square",
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
function constr2bounds(lhs::Float64, lsense::Symbol, ex::Expr,
        rsense::Symbol, rhs::Float64)
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
            error("Do not know how to handle :call expression $ex " *
                "with fewer than 2 args")
        elseif numargs == 2
            if haskey(jl2osnl_unary, args[1])
                child = new_child(parent, jl2osnl_unary[args[1]])
                expr2osnl!(child, args[2])
            else
                error("Do not know how to convert unary $(args[1]) to osnl")
            end
        elseif numargs == 3
            # TODO: check for special cases:
            # square, coef * variable
            if haskey(jl2osnl_binary, args[1])
                child = new_child(parent, jl2osnl_binary[args[1]])
                expr2osnl!(child, args[2])
                expr2osnl!(child, args[3])
            else
                error("Do not know how to convert binary $(args[1]) to osnl")
            end
        else
            if haskey(jl2osnl_varargs, args[1])
                child = new_child(parent, jl2osnl_varargs[args[1]])
                for i = 2:numargs
                    expr2osnl!(child, args[i])
                end
            else
                error("Do not know how to convert varargs $(args[1]) to osnl")
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


# TODO: other direction for reading osil => jump model



