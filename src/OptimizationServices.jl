module OptimizationServices

using Compat

export elem2pair, @assertform

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


if true # switch this to disable assertions
    macro assertform(x, y)
        msg = "$x expected to be $y, was "
        :($x == $y ? nothing : error($msg * repr($x)))
    end
else
    macro assertform(x, y)
    end
end

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
    return (elemarg3args[2]::Int, elemargs[2]::Float64)
end



end # module
