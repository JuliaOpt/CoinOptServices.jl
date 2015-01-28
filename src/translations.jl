using Compat

export jl2osnl_varargs, jl2osnl_binary, jl2osnl_unary, jl2osil_vartypes

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


# TODO: other direction for reading osil => jump model
