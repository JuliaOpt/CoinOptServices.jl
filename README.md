# OptimizationServices.jl

[![Build Status](https://travis-ci.org/tkelman/OptimizationServices.jl.svg?branch=master)](https://travis-ci.org/tkelman/OptimizationServices.jl)

This [Julia](https://github.com/JuliaLang/julia) package is an interface
between [MathProgBase.jl](https://github.com/JuliaOpt/MathProgBase.jl) and
[COIN-OR](http://www.coin-or.org) [Optimization Services (OS)](https://projects.coin-or.org/OS),
translating between the [Julia-expression-tree MathProgBase format](http://mathprogbasejl.readthedocs.org/en/latest/nlp.html#obj_expr)
for nonlinear objective and constraint functions and the
[Optimization Services instance Language (OSiL)](http://www.coin-or.org/OS/OSiL.html)
XML-based optimization problem interchange format.

By writing ``.osil`` files and using the ``OSSolverService`` command-line
driver, this package allows Julia optimization modeling languages such as
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
used for nonlinear programming in JuMP. TODO: benchmarking!

Writing of ``.osil`` files is implemented using the
[LightXML.jl](https://github.com/JuliaLang/LightXML.jl) Julia bindings to
[libxml2](http://xmlsoft.org) to construct XML files from element trees.
Reading of ``.osil`` files will be done later, to provide a (de-)serialization
format for storage, archival, and interchange of optimization problems between
various modeling languages.

## Installation

You can install the package by running:

    julia> Pkg.add("OptimizationServices")

On Linux or OSX, this will compile the Optimization Services library and its
dependencies if they are not found in ``DL_LOAD_PATH``. Note that
Optimization Services is a large C++ library with many dependencies, and it
is not currently packaged for any released Linux distributions. Submit a
pull request to support using the library from a system package manager if
this changes. It is recommended to set ``ENV["MAKEFLAGS"] = "-j4"`` before
installing the package so compilation does not take as long.

The current BinDeps setup assumes Ipopt.jl and Cbc.jl have already been
successfully installed in order to reuse the binaries for those solvers.
You will need to have a Fortran compiler such as ``gfortran`` installed
in order to compile Ipopt. On OSX, install [Homebrew](http://brew.sh/)
and run ``brew install gcc``. On Linux, use your system package manager
to install ``gfortran``.

This package builds the remaining COIN-OR libraries OptimizationServices,
CppAD, Bonmin, Couenne, and a few other solvers (DyLP, Vol, SYMPHONY, Bcp)
that do not yet have Julia bindings.

If you are using the generic Linux binaries of Julia, note that there is an
[issue with libgfortran](https://github.com/JuliaLang/julia/pull/8442#issuecomment-69449027).
You may need to delete the bundled ``lib/julia/libgfortran.so.3`` for Ipopt.jl
and this package to work correctly.

On Windows, binaries are downloaded via [WinRPM.jl](https://github.com/JuliaLang/WinRPM.jl).
Currently these are packaged in [my personal project](https://build.opensuse.org/project/show/home:kelman:mingw-coinor)
on the openSUSE build service, but I plan on submitting them to the official
default repository. I will probably wait for the next round of upstream
COIN-OR releases before doing this.

Precompiled binaries for OSX will eventually be provided via
[Homebrew.jl](https://github.com/JuliaLang/Homebrew.jl), check
[here](https://github.com/staticfloat/homebrew-juliadeps/pull/36) for
the latest progress.

## Usage

OptimizationServices is usable as a solver in JuMP as follows.

    julia> using JuMP, OptimizationServices
    julia> m = Model(solver = OsilSolver())

Then model and solve your optimization problem as usual. See
[JuMP's documentation](http://jump.readthedocs.org/en/latest/) for more
details. The ``OsilSolver()`` constructor takes several optional keyword
arguments. You can specify ``OsilSolver(solver = "couenne")`` to request
a particular sub-solver, ``OsilSolver(osil = "/path/to/file.osil")`` or
similarly ``osol`` or ``osrl`` keyword arguments to request non-default
paths for writing the OSiL instance file, OSoL options file, or OSrL
results file. The default location for writing these files is under
``Pkg.dir("OptimizationServices", ".osil")``. Any other keyword arguments
provided to the ``OsilSolver`` constructor are interpreted as solver options
and saved in the OSoL options file.

OptimizationServices should also work with any other MathProgBase-compliant
linear or nonlinear optimization modeling tools, though this has not been
tested. There are features in OSiL for representing conic optimization
problems, but these are not currently exposed or connected to the
MathProgBase conic interface.


