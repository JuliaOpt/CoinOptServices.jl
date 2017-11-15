module CoinOptServices

using MathProgBase, LightXML
importall MathProgBase.SolverInterface

debug = true # (ccall(:jl_is_debugbuild, Cint, ()) == 1)
if debug
    macro assertequal(x, y)
        msg = "Expected $x == $y, got "
        :($(esc(x)) == $(esc(y)) ? nothing : error($msg, repr($(esc(x))), " != ", repr($(esc(y)))))
    end
else
    macro assertequal(x, y)
    end
end

include("translations.jl")

depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
isfile(depsjl) ? include(depsjl) : error("CoinOptServices not properly ",
    "installed. Please run\nPkg.build(\"CoinOptServices\")")
OSSolverService = joinpath(dirname(libOS), "..", "bin", "OSSolverService")
bonmin = joinpath(dirname(libOS), "..", "bin", "bonmin")
couenne = joinpath(dirname(libOS), "..", "bin", "couenne")
osildir = Pkg.dir("CoinOptServices", ".osil")

export OsilSolver, OsilBonminSolver, OsilCouenneSolver, OSOption
immutable OsilSolver <: AbstractMathProgSolver
    solver::String
    osil::String
    osol::String
    osrl::String
    printLevel::Int
    options::Vector{Dict}
end
# note that changing DEFAULT_OUTPUT_LEVEL in OS/src/OSUtils/OSOutput.h
# from ENUM_OUTPUT_LEVEL_error (1) to -1 is required to make printLevel=0
# actually silent, since there are several instances of OSPrint that use
# ENUM_OUTPUT_LEVEL_always (0) *before* command-line flags like -printLevel
# have been read, and OSPrint shows output whenever the output level for a
# call is <= the printLevel
OsilSolver(options::Dict...;
        solver = "",
        osil = joinpath(osildir, "problem.osil"),
        osol = joinpath(osildir, "options.osol"),
        osrl = joinpath(osildir, "results.osrl"),
        printLevel = 1) =
    OsilSolver(solver, osil, osol, osrl, printLevel, collect(options))
OsilBonminSolver(options::Dict...;
        osil = joinpath(osildir, "problem.osil"),
        osol = joinpath(osildir, "options.osol"),
        osrl = joinpath(osildir, "results.osrl"),
        printLevel = 1) =
    OsilSolver("bonmin", osil, osol, osrl, printLevel, collect(options))
OsilCouenneSolver(options::Dict...;
        osil = joinpath(osildir, "problem.osil"),
        osol = joinpath(osildir, "options.osol"),
        osrl = joinpath(osildir, "results.osrl"),
        printLevel = 1) =
    OsilSolver("couenne", osil, osol, osrl, printLevel, collect(options))

# translate keyword arguments into an option Dict
# (can't make this a type since it would need a field named type)
function OSOption(; kwargs...)
    optdict = Dict()
    for (argname, argval) in kwargs
        if haskey(optdict, argname) && argval != optdict[argname]
            error("Duplicate setting of option $argname; was ",
                optdict[argname], ", tried to set to $argval")
        else
            optdict[argname] = argval
        end
    end
    return optdict
end
function OSOption(optname, optval::AbstractString; kwargs...)
    push!(kwargs, (:type, "string"))
    return OSOption(name = optname, value = optval; kwargs...)
end
function OSOption(optname, optval::Integer; kwargs...)
    push!(kwargs, (:type, "integer"))
    return OSOption(name = optname, value = optval; kwargs...)
end
function OSOption(optname, optval::Number; kwargs...)
    push!(kwargs, (:type, "numeric"))
    return OSOption(name = optname, value = optval; kwargs...)
end
OSOption(optname, optval; kwargs...) =
    OSOption(name = optname, value = optval; kwargs...)

type OsilMathProgModel <: AbstractMathProgModel
    solver::String
    osil::String
    osol::String
    osrl::String
    printLevel::Int
    options::Vector{Dict}

    numberOfVariables::Int
    numberOfConstraints::Int
    xl::Vector{Float64}
    xu::Vector{Float64}
    cl::Vector{Float64}
    cu::Vector{Float64}
    qrhs::Vector{Float64}
    objsense::Symbol
    d::AbstractNLPEvaluator

    numLinConstr::Int
    quadconidx::Vector{Int}
    vartypes::Vector{Symbol}
    x0::Vector{Float64}

    status::Symbol
    objval::Float64
    solution::Vector{Float64}
    reducedcosts::Vector{Float64}
    constrduals::Vector{Float64}
    quadconstrduals::Vector{Float64}

    xdoc::XMLDocument # TODO: finalizer
    instanceData::XMLElement
    obj::XMLElement
    variables::XMLElement
    constraints::XMLElement
    quadraticCoefficients::XMLElement
    quadobjterms::Vector{XMLElement}

    OsilMathProgModel(solver, osil, osol, osrl, printLevel, options) =
        new(solver, osil, osol, osrl, printLevel, options)
end
immutable OsilLinearQuadraticModel <: AbstractLinearQuadraticModel
    inner::OsilMathProgModel
end
immutable OsilNonlinearModel <: AbstractNonlinearModel
    inner::OsilMathProgModel
end

OsilMathProgModel(s::OsilSolver) = OsilMathProgModel(s.solver,
    s.osil, s.osol, s.osrl, s.printLevel, s.options)
LinearQuadraticModel(s::OsilSolver) = OsilLinearQuadraticModel(
    OsilMathProgModel(s))
NonlinearModel(s::OsilSolver) = OsilNonlinearModel(
    OsilMathProgModel(s))
ConicModel(s::OsilSolver) = LPQPtoConicBridge(LinearQuadraticModel(s))

include("probmod.jl")

function create_osil_common!(m::OsilMathProgModel, xl, xu, cl, cu, objsense)
    # create osil data that is common between linear and nonlinear problems
    numberOfVariables = length(xl)
    numberOfConstraints = length(cl)
    @assertequal numberOfVariables length(xu)
    @assertequal numberOfConstraints length(cu)
    

    m.numberOfVariables = numberOfVariables
    m.numberOfConstraints = numberOfConstraints
    m.xl = xl
    m.xu = xu
    m.cl = cl
    m.cu = cu
    m.objsense = objsense

    # clear existing problem, if defined
    isdefined(m, :xdoc) && free(m.xdoc)
    m.xdoc = XMLDocument()
    xroot = create_root(m.xdoc, "osil")
    set_attribute(xroot, "xmlns", "os.optimizationservices.org")
    set_attribute(xroot, "xmlns:xsi",
        "http://www.w3.org/2001/XMLSchema-instance")
    set_attribute(xroot, "xsi:schemaLocation",
        "os.optimizationservices.org " *
        "http://www.optimizationservices.org/schemas/2.0/OSiL.xsd")

    instanceHeader = new_child(xroot, "instanceHeader")
    description = new_child(instanceHeader, "description")
    add_text(description, "generated by CoinOptServices.jl on " *
        Libc.strftime("%Y/%m/%d at %H:%M:%S", time()))
    m.instanceData = new_child(xroot, "instanceData")

    m.variables = new_child(m.instanceData, "variables")
    set_attribute(m.variables, "numberOfVariables", numberOfVariables)
    for i = 1:numberOfVariables
        newvar!(m.variables, xl[i], xu[i])
    end

    objectives = new_child(m.instanceData, "objectives")
    # can MathProgBase do multi-objective problems?
    set_attribute(objectives, "numberOfObjectives", "1")
    m.obj = new_child(objectives, "obj")
    set_attribute(m.obj, "maxOrMin", lowercase(string(objsense)))

    m.constraints = new_child(m.instanceData, "constraints")
    set_attribute(m.constraints, "numberOfConstraints", numberOfConstraints)
    for i = 1:numberOfConstraints
        newcon!(m.constraints, cl[i], cu[i])
    end
    m.qrhs = Float64[] # move these once MathProgBase.loadquadproblem! exists
    m.quadconidx = Int[]

    return m
end

function MathProgBase.loadproblem!(outer::OsilLinearQuadraticModel,
        A, xl, xu, f, cl, cu, objsense)
    m = outer.inner
    # populate osil data that is specific to linear problems
    @assertequal(size(A, 1), length(cl))
    @assertequal(size(A, 2), length(xl))
    @assertequal(size(A, 2), length(f))

    create_osil_common!(m, xl, xu, cl, cu, objsense)
    MathProgBase.setobj!(m, f)

    # transpose linear constraint matrix so it is easier
    # to add linear rows in addquadconstr!
    if issparse(A)
        At = A'
    else
        At = sparse(A)'
    end
    rowptr = At.colptr
    colval = At.rowval
    nzval = At.nzval
    if length(nzval) > 0
        (linConstrCoefs, rowstarts, colIdx, values) =
            create_empty_linconstr!(m)
        set_attribute(linConstrCoefs, "numberOfValues", length(nzval))
        @assertequal(rowptr[1], 1)
        for i = 2:length(rowptr)
            add_text(new_child(rowstarts, "el"), string(rowptr[i] - 1)) # OSiL is 0-based
        end
        for i = 1:length(colval)
            addnonzero!(colIdx, values, colval[i] - 1, nzval[i]) # OSiL is 0-based
        end
    end
    m.numLinConstr = length(cl)

    return m
end

function MathProgBase.loadproblem!(outer::OsilNonlinearModel,
        numberOfVariables, numberOfConstraints, xl, xu, cl, cu, objsense,
        d::MathProgBase.AbstractNLPEvaluator)
    m = outer.inner
    # populate osil data that is specific to nonlinear problems
    @assert numberOfVariables == length(xl)
    @assert numberOfConstraints == length(cl)

    create_osil_common!(m, xl, xu, cl, cu, objsense)
    m.d = d
    MathProgBase.initialize(d, [:ExprGraph])

    # TODO: compare BitArray vs. Array{Bool} here
    indicator = falses(numberOfVariables)
    densevals = zeros(numberOfVariables)

    objexpr = MathProgBase.obj_expr(d)
    nlobj = false
    if MathProgBase.isobjlinear(d)
        @assertequal(objexpr.head, :call)
        objexprargs = objexpr.args
        @assertequal(objexprargs[1], :+)
        constant = 0.0
        for i = 2:length(objexprargs)
            constant += addLinElem!(indicator, densevals, objexprargs[i])
        end
        (constant == 0.0) || set_attribute(m.obj, "constant", constant)
        numberOfObjCoef = 0
        i = findnext(indicator, 1)
        while i != 0
            numberOfObjCoef += 1
            newobjcoef!(m.obj, i - 1, densevals[i]) # OSiL is 0-based
            densevals[i] = 0.0 # reset for later use in linear constraints
            i = findnext(indicator, i + 1)
        end
        fill!(indicator, false) # for Array{Bool}, set to false one element at a time?
        set_attribute(m.obj, "numberOfObjCoef", numberOfObjCoef)
    else
        nlobj = true
        set_attribute(m.obj, "numberOfObjCoef", "0")
        # nonlinear objective goes in nonlinearExpressions, <nl idx="-1">
    end

    # assume linear constraints are all at start
    row = 1
    nextrowlinear = MathProgBase.isconstrlinear(d, row)
    if nextrowlinear
        # has at least 1 linear constraint
        (linConstrCoefs, rowstarts, colIdx, values) =
            create_empty_linconstr!(m)
        numberOfValues = 0
    end
    while nextrowlinear
        constrexpr = MathProgBase.constr_expr(d, row)

        if VERSION < v"0.5.0-dev+3231"
            @assertequal(constrexpr.head, :comparison)
            constrlinpart = constrexpr.args[end - 2]
        else
            @assertequal(constrexpr.head, :call)
            constrlinpart = constrexpr.args[2]
        end

        #(lhs, rhs) = constr2bounds(constrexpr.args...)
        @assertequal(constrlinpart.head, :call)
        constrlinargs = constrlinpart.args
        @assertequal(constrlinargs[1], :+)
        for i = 2:length(constrlinargs)
            addLinElem!(indicator, densevals, constrlinargs[i]) == 0.0 ||
                error("Unexpected constant term in linear constraint")
        end
        idx = findnext(indicator, 1)
        while idx != 0
            numberOfValues += 1
            addnonzero!(colIdx, values, idx - 1, densevals[idx]) # OSiL is 0-based
            densevals[idx] = 0.0 # reset for next row
            idx = findnext(indicator, idx + 1)
        end
        fill!(indicator, false) # for Array{Bool}, set to false one element at a time?
        add_text(new_child(rowstarts, "el"), string(numberOfValues))
        row += 1
        nextrowlinear = MathProgBase.isconstrlinear(d, row)
    end
    m.numLinConstr = row - 1
    if m.numLinConstr > 0
        # fill in remaining row starts for nonlinear constraints
        for row = m.numLinConstr + 1 : numberOfConstraints
            add_text(new_child(rowstarts, "el"), string(numberOfValues))
        end
        set_attribute(linConstrCoefs, "numberOfValues", numberOfValues)
    end

    numberOfNonlinearExpressions = numberOfConstraints - m.numLinConstr +
        (nlobj ? 1 : 0)
    if numberOfNonlinearExpressions > 0
        # has nonlinear objective or at least 1 nonlinear constraint
        nonlinearExpressions = new_child(m.instanceData,
            "nonlinearExpressions")
        set_attribute(nonlinearExpressions, "numberOfNonlinearExpressions",
            numberOfNonlinearExpressions)
        if nlobj
            nl = new_child(nonlinearExpressions, "nl")
            set_attribute(nl, "idx", "-1")
            expr2osnl!(nl, MathProgBase.obj_expr(d))
        end
        for row = m.numLinConstr + 1 : numberOfConstraints
            nl = new_child(nonlinearExpressions, "nl")
            set_attribute(nl, "idx", row - 1) # OSiL is 0-based
            constrexpr = MathProgBase.constr_expr(d, row)
            #(lhs, rhs) = constr2bounds(constrexpr.args...)
            if VERSION >= v"0.5.0-dev+3231" && constrexpr.head == :call
                @assert(constrexpr.args[1] in [:<=, :(==), :>=])
                constrpart = constrexpr.args[2]
            else
                @assertequal(constrexpr.head, :comparison)
                constrpart = constrexpr.args[end - 2]
            end
            expr2osnl!(nl, constrpart)
        end
    end

    return m
end

function write_osol_file(osol, x0, options)
    xdoc = XMLDocument()
    xroot = create_root(xdoc, "osol")
    set_attribute(xroot, "xmlns", "os.optimizationservices.org")
    set_attribute(xroot, "xmlns:xsi",
        "http://www.w3.org/2001/XMLSchema-instance")
    set_attribute(xroot, "xsi:schemaLocation",
        "os.optimizationservices.org " *
        "http://www.optimizationservices.org/schemas/2.0/OSoL.xsd")

    optimization = new_child(xroot, "optimization")
    if length(x0) > 0
        variables = new_child(optimization, "variables")
        initialVariableValues = new_child(variables, "initialVariableValues")
        set_attribute(initialVariableValues, "numberOfVar", length(x0))
    end
    for (idx, val) in enumerate(x0)
        vari = new_child(initialVariableValues, "var")
        set_attribute(vari, "idx", idx - 1) # OSiL is 0-based
        set_attribute(vari, "value", val)
    end

    if length(options) > 0
        solverOptions = new_child(optimization, "solverOptions")
        set_attribute(solverOptions, "numberOfSolverOptions", length(options))
        for optdict in options
            solverOption = new_child(solverOptions, "solverOption")
            for (argname, argval) in optdict
                if symbol(argname) in (:name, :value, :solver,
                        :category, :type, :description, :numberOfItems)
                    # TODO: child <item>'s of <solverOption>'s?
                    set_attribute(solverOption, string(argname), argval)
                else
                    error("Unknown solverOption attribute $argname")
                end
            end
        end
    end

    ret = save_file(xdoc, osol)
    free(xdoc)
    return ret
end

function read_osrl_file!(m::OsilMathProgModel, osrl)
    xdoc = parse_file(osrl, C_NULL, 64) # 64 == XML_PARSE_NOWARNING
    xroot = root(xdoc)
    # do something with general/generalStatus ?
    optimization = find_element(xroot, "optimization")
    @assertequal(parse(Int, attribute(optimization, "numberOfVariables")),
        m.numberOfVariables)
    @assertequal(parse(Int, attribute(optimization, "numberOfConstraints")),
        m.numberOfConstraints)
    numberOfSolutions = attribute(optimization, "numberOfSolutions")
    if numberOfSolutions != "1"
        warn("numberOfSolutions expected to be 1, was $numberOfSolutions")
    end
    solution = find_element(optimization, "solution")

    status = find_element(solution, "status")
    statustype = attribute(status, "type")
    if statustype == nothing
        # OSIpoptSolver needs some fixes for iteration limit exit status
        warn("Solution status in $(m.osrl) has no type attribute. Status ",
            "content is: ", content(status))
        m.status = :Error
    else
        if haskey(osrl2jl_status, statustype)
            m.status = osrl2jl_status[statustype]
        else
            error("Unknown solution status type $statustype")
        end
        statusdescription = attribute(status, "description")
        if statusdescription != nothing
            # OSBonminSolver and OSCouenneSolver set some funny exit statuses
            if statustype == "other" && startswith(statusdescription, "LIMIT")
                m.status = :UserLimit
            elseif statustype == "error" && (statusdescription ==
                    "The problem is infeasible")
                m.status = :Infeasible
            elseif statustype == "error" && (statusdescription ==
                    "The problem is unbounded" ||
                    startswith(statusdescription, "CONTINUOUS_UNBOUNDED"))
                m.status = :Unbounded
            end
        end
    end

    variables = find_element(solution, "variables")
    if variables == nothing
        m.solution = fill(NaN, m.numberOfVariables)
        (m.status == :Optimal) && warn("status was $statustype but no ",
            "variables were present in $osrl")
    else
        varvalues = find_element(variables, "values")
        @assertequal(parse(Int, attribute(varvalues, "numberOfVar")),
            m.numberOfVariables)
        m.solution = xml2vec(varvalues, m.numberOfVariables)

        # reduced costs
        counter = 0
        reduced_costs_found = false
        for child in child_elements(variables)
            if name(child) == "other"
                counter += 1
                if attribute(child, "name") == "reduced_costs"
                    @assertequal(parse(Int, attribute(child, "numberOfVar")),
                        m.numberOfVariables)
                    if reduced_costs_found
                        warn("Overwriting existing reduced costs")
                    end
                    reduced_costs_found = true
                    m.reducedcosts = xml2vec(child, m.numberOfVariables)
                end
            end
        end
        if !reduced_costs_found
            m.reducedcosts = fill(NaN, m.numberOfVariables)
        end
        numberOfOther = attribute(variables, "numberOfOtherVariableResults")
        if numberOfOther == nothing
            @assertequal(counter, 0)
        else
            @assertequal(counter, parse(Int, numberOfOther))
        end
    end

    objectives = find_element(solution, "objectives")
    if objectives == nothing
        m.objval = NaN
        (m.status == :Optimal) && warn("status was $statustype but no ",
            "objectives were present in $osrl")
    else
        objvalues = find_element(objectives, "values")
        numberOfObj = attribute(objvalues, "numberOfObj")
        if numberOfObj != "1"
            warn("numberOfObj expected to be 1, was $numberOfObj")
        end
        m.objval = parse(Float64, content(find_element(objvalues, "obj")))
    end

    # constraint duals
    constraints = find_element(solution, "constraints")
    if constraints == nothing
        m.constrduals = fill(NaN, m.numberOfConstraints)
    else
        dualValues = find_element(constraints, "dualValues")
        @assertequal(parse(Int, attribute(dualValues, "numberOfCon")),
            m.numberOfConstraints)
        if length(m.quadconidx) == 0
            m.constrduals = xml2vec(dualValues, m.numberOfConstraints)
        else
            # MathProgBase wants quadratic constraint duals separately
            # from linear / nonlinear constraint duals
            (m.constrduals, m.quadconstrduals) = splitlinquad(m,
                xml2vec(dualValues, m.numberOfConstraints))
        end
    end

    # TODO: more status details/messages?
    free(xdoc)
    return m.status
end

function MathProgBase.optimize!(m::OsilMathProgModel)
    if m.objsense == :Max && isdefined(m, :d) && isdefined(m, :vartypes) &&
            any(x -> !(x == :Cont || x == :Fixed), m.vartypes)
        warn("Maximization problems can be buggy with ",
            "OSSolverService and MINLP solvers, see ",
            "https://projects.coin-or.org/OS/ticket/52. Formulate your ",
            "problem as a minimization for more reliable results.")
    end
    save_file(m.xdoc, m.osil)
    if isempty(m.solver)
        solvercmd = `` # use default
    else
        solvercmd = `-solver $(m.solver)`
        for opt in filter(x -> !haskey(x, :solver), m.options)
            opt[:solver] = m.solver
        end
    end
    if isdefined(m, :x0)
        xl, x0, xu = m.xl, m.x0, m.xu
        have_warned = false
        for i = 1:m.numberOfVariables
            if !have_warned && !(xl[i] <= x0[i] <= xu[i])
                warn("Modifying initial conditions to satisfy bounds")
                have_warned = true
            end
            x0[i] = clamp(x0[i], xl[i], xu[i])
        end
        write_osol_file(m.osol, x0, m.options)
    else
        write_osol_file(m.osol, Float64[], m.options)
    end
    # clear existing content from m.osrl, if any
    close(open(m.osrl, "w"))
    run(`$OSSolverService -osil $(m.osil) -osol $(m.osol) -osrl $(m.osrl)
        $solvercmd -printLevel $(m.printLevel)`)
    if filesize(m.osrl) == 0
        warn(m.osrl, " is empty")
        m.status = :Error
    else
        read_osrl_file!(m, m.osrl)
    end
    return m.status
end

end # module
