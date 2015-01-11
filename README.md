# OptimizationServices.jl

[![Build Status](https://travis-ci.org/tkelman/OptimizationServices.jl.svg?branch=master)](https://travis-ci.org/tkelman/OptimizationServices.jl)

This [Julia](https://github.com/JuliaLang/julia) package is intended to be an
interface between [MathProgBase.jl](https://github.com/JuliaOpt/MathProgBase.jl)
and [COIN-OR](http://www.coin-or.org) [Optimization Services (OS)](https://projects.coin-or.org/OS),
translating between the [Julia-expression-tree MathProgBase format](http://mathprogbasejl.readthedocs.org/en/latest/nlp.html#obj_expr)
for nonlinear objective and constraint functions and the
[Optimization Services instance Language (OSiL)](http://www.coin-or.org/OS/OSiL.html)
XML-based optimization problem interchange format.

By writing ``.osil`` files and using the ``OSSolverService`` command-line
driver, this package will allow Julia optimization modeling languages such as
[JuMP](https://github.com/JuliaOpt/JuMP.jl) to access any solver supported by
``OSSolverService``. This includes the COIN-OR solvers [Clp](https://projects.coin-or.org/Clp)
(linear programming), [Cbc](https://projects.coin-or.org/Cbc) (mixed-integer
linear programming), [Ipopt](https://projects.coin-or.org/Ipopt) (nonlinear
programming), [Bonmin](https://projects.coin-or.org/Bonmin) (evaluation-based
mixed-integer nonlinear programming), [Couenne](https://projects.coin-or.org/Couenne)
(expression-tree-based mixed-integer nonlinear programming), and several others.

Note that [Clp](https://github.com/JuliaOpt/Clp.jl), [Cbc](https://github.com/JuliaOpt/Cbc.jl),
and [Ipopt](https://github.com/JuliaOpt/Ipopt.jl) already have Julia packages
that interface directly with their respective in-memory C API's. Particularly
for Clp.jl and Cbc.jl, the existing packages should be faster than the
OptimizationServices.jl approach of going through an OSiL file on disk.
Ipopt.jl is probably faster as well, however using ``OSSolverService`` will
perform automatic differentiation in C++ using [CppAD](https://projects.coin-or.org/CppAD),
which may have different performance characteristics than the pure-Julia
[ReverseDiffSparse.jl](https://github.com/mlubin/ReverseDiffSparse.jl) package
used for nonlinear programming in JuMP.jl. TODO: benchmarking!

Writing of ``.osil`` files will be implemented first, using the
[LightXML.jl](https://github.com/JuliaLang/LightXML.jl) Julia bindings to
[libxml2](http://xmlsoft.org) to construct XML files from element trees.
Reading of ``.osil`` files will be done later, to provide a (de-)serialization
format for storage, archival, and interchange of optimization problems between
various modeling languages.

## Installation

This package is not yet registered, and I'll be starting with the hard work
of managing binary dependencies across different platforms first. None of the
code has been written in `src` yet. But if you want to see how far I've gotten
and/or contribute, you can install the package by running:

    julia> Pkg.clone("https://github.com/tkelman/OptimizationServices.jl")
    julia> Pkg.build("OptimizationServices")

The current BinDeps setup has OptimizationServices, CppAD, Bonmin, Couenne,
and a few other solvers (DyLP, Vol, SYMPHONY, Bcp) that do not yet have Julia
bindings build from source on Linux or OSX, assuming Ipopt.jl and Cbc.jl have
already been successfully installed and reusing the binaries for those solvers.
If you are using the generic Linux binaries of Julia, note that there is an
[issue with libgfortran](https://github.com/JuliaLang/julia/pull/8442#issuecomment-69449027).
You may need to delete the bundled ``lib/julia/libgfortran.so.3`` for Ipopt.jl
and this package to work correctly. On Windows the plan is for this package to
download a Win32 binary of [CoinAll](https://projects.coin-or.org/CoinBinary)
initially, likely switching to [WinRPM.jl](https://github.com/JuliaLang/WinRPM.jl)
later.
