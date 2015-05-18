# CoinOptServices.jl

Linux, OSX: [![Build Status](https://travis-ci.org/JuliaOpt/CoinOptServices.jl.svg?branch=master)](https://travis-ci.org/JuliaOpt/CoinOptServices.jl)

Windows: [![Build Status](https://ci.appveyor.com/api/projects/status/github/JuliaOpt/CoinOptServices.jl?branch=master&svg=true)](https://ci.appveyor.com/project/tkelman/coinoptservices-jl/branch/master)

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
CoinOptServices.jl approach of going through an OSiL file on disk.
Initial comparisons show that Ipopt.jl is also substantially faster than
CoinOptServices.jl. For nonlinear problems ``OSSolverService`` performs
automatic differentiation in C++ using [CppAD](https://projects.coin-or.org/CppAD),
which has different performance characteristics than the pure-Julia
[ReverseDiffSparse.jl](https://github.com/mlubin/ReverseDiffSparse.jl) package
used for nonlinear programming in JuMP. TODO: determine why CppAD is slower than expected

Writing of ``.osil`` files is implemented using the
[LightXML.jl](https://github.com/JuliaLang/LightXML.jl) Julia bindings to
[libxml2](http://xmlsoft.org) to construct XML files from element trees.
Reading of ``.osil`` files will be done later, to provide a (de-)serialization
format for storage, archival, and interchange of optimization problems between
various modeling languages.

## Installation

You can install the package by running:

    julia> Pkg.add("CoinOptServices")

On OS X, this will automatically download precompiled binaries
via [Homebrew.jl](https://github.com/JuliaLang/Homebrew.jl).

On Windows, this will automatically download precompiled binaries
via [WinRPM.jl](https://github.com/JuliaLang/WinRPM.jl).
Currently these are packaged in [@tkelman](https://github.com/tkelman)'s
[personal project](https://build.opensuse.org/project/show/home:kelman:mingw-coinor)
on the openSUSE build service, but these will be submitted to the official
default repository eventually.

On Linux, this will compile the COIN OS library and its dependencies from
source if they are not found in ``DL_LOAD_PATH``. Note that OS is a large
C++ library with many dependencies, and it is not currently packaged for
any released Linux distributions. Submit a pull request to support using
the library from a system package manager if this changes. It is
recommended to set ``ENV["MAKEFLAGS"] = "-j4"`` before installing the
package so compilation does not take as long.

The current BinDeps setup assumes Ipopt.jl and Cbc.jl have already been
successfully installed in order to reuse the binaries for those solvers.
You will need to have a Fortran compiler such as ``gfortran`` installed
in order to compile Ipopt. On Linux, use your system package manager to
install ``gfortran``. You will also need to have ``pkg-config`` installed.

This package builds the remaining COIN-OR libraries OS, CppAD, Bonmin,
Couenne, and a few other solvers (DyLP, Vol, SYMPHONY, Bcp)
that do not yet have Julia bindings.

## Usage

CoinOptServices is usable as a solver in JuMP as follows.

    julia> using JuMP, CoinOptServices
    julia> m = Model(solver = OsilSolver())

Then model and solve your optimization problem as usual. See
[JuMP's documentation](http://jump.readthedocs.org/en/latest/) for more
details. The ``OsilSolver()`` constructor takes several optional keyword
arguments. You can specify ``OsilSolver(solver = "couenne")`` to request
a particular sub-solver, ``OsilSolver(osil = "/path/to/file.osil")`` or
similarly ``osol`` or ``osrl`` keyword arguments to request non-default
paths for writing the OSiL instance file, OSoL options file, or OSrL
results file. The default location for writing these files is under
``Pkg.dir("CoinOptServices", ".osil")``. The ``printLevel`` keyword argument
can be set to an integer from 0 to 5, and corresponds to the ``-printLevel``
command line flag for ``OSSolverService``. This only controls the print
level of the OS driver, not the solvers themselves.

Note that if you want to solve multiple problems simultaneously, you
need to set the ``osil``, ``osol``, and ``osrl`` keyword arguments to
independent file names for each problem. See
[issue #1](https://github.com/JuliaOpt/CoinOptServices.jl/issues/1) for details.

All additional inputs to ``OsilSolver`` are treated as solver-specific
options. These options should be input as Julia ``Dict`` objects, with
keys corresponding to OSoL ``<solverOption>`` properties ``"name"``,
``"value"``, ``"solver"``, ``"category"``, ``"type"``, or ``"description"``.
A convenience function ``OSOption(optname, optval, kwargs...)`` is provided
to automatically set ``"type"`` based on the Julia type of ``optval``.

CoinOptServices should also work with any other MathProgBase-compliant
linear or nonlinear optimization modeling tools, though this has not been
tested. There are features in OSiL for representing conic optimization
problems, but these are not currently exposed or connected to the
MathProgBase conic interface.
