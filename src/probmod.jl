# getters
MathProgBase.status(m::OsilMathProgModel) = m.status
MathProgBase.numvar(m::OsilMathProgModel) = m.numberOfVariables
MathProgBase.numconstr(m::OsilMathProgModel) = m.numberOfConstraints
MathProgBase.numlinconstr(m::OsilMathProgModel) = m.numLinConstr
MathProgBase.numquadconstr(m::OsilMathProgModel) = length(m.quadconidx)
MathProgBase.getobjval(m::OsilMathProgModel) = m.objval
MathProgBase.getsolution(m::OsilMathProgModel) = m.solution
MathProgBase.getreducedcosts(m::OsilMathProgModel) = m.reducedcosts
MathProgBase.getconstrduals(m::OsilMathProgModel) = m.constrduals
MathProgBase.getquadconstrduals(m::OsilMathProgModel) = m.quadconstrduals
MathProgBase.getsense(m::OsilMathProgModel) = m.objsense
MathProgBase.getvartype(m::OsilMathProgModel) = m.vartypes
MathProgBase.getvarLB(m::OsilMathProgModel) = m.xl
MathProgBase.getvarUB(m::OsilMathProgModel) = m.xu
MathProgBase.getconstrLB(m::OsilMathProgModel) = m.cl
MathProgBase.getconstrUB(m::OsilMathProgModel) = m.cu
MathProgBase.getquadconstrRHS(m::OsilMathProgModel) = m.qrhs
MathProgBase.getobj(m::OsilMathProgModel) =
    xml2vec(m.obj, m.numberOfVariables, 0.0)

# helper functions
function newvar!(variables::XMLElement, lb, ub)
    # create a new child <var> with given lb, ub
    var = new_child(variables, "var")
    set_attribute(var, "lb", lb) # lb defaults to 0 if not specified!
    isfinite(ub) && set_attribute(var, "ub", ub)
    return var
end

function newcon!(constraints::XMLElement, lb, ub)
    # create a new child <con> with given lb, ub
    con = new_child(constraints, "con")
    isfinite(lb) && set_attribute(con, "lb", lb)
    isfinite(ub) && set_attribute(con, "ub", ub)
    return con
end

function newobjcoef!(obj::XMLElement, idx, val)
    coef = new_child(obj, "coef")
    set_attribute(coef, "idx", idx)
    add_text(coef, string(val))
    return coef
end

function create_empty_linconstr!(m::OsilMathProgModel)
    linConstrCoefs = new_child(m.instanceData, "linearConstraintCoefficients")
    rowstarts = new_child(linConstrCoefs, "start")
    add_text(new_child(rowstarts, "el"), "0")
    colIdx = new_child(linConstrCoefs, "colIdx")
    values = new_child(linConstrCoefs, "value")
    if isdefined(m, :quadraticCoefficients)
        # need to rearrange so quadraticCoefficients come after linear
        unlink(m.quadraticCoefficients)
        add_child(m.instanceData, m.quadraticCoefficients)
    end
    return (linConstrCoefs, rowstarts, colIdx, values)
end

function addnonzero!(colIdx, values, idx, val)
    # add a nonzero element to colIdx and values, with 0-based idx
    add_text(new_child(colIdx, "el"), string(idx))
    add_text(new_child(values, "el"), string(val))
    return val
end

function initialize_quadcoefs!(m::OsilMathProgModel)
    # return numberOfQuadraticTerms if quadraticCoefficients has been
    # created, otherwise create quadraticCoefficients and return 0
    if isdefined(m, :quadraticCoefficients)
        return parse(Int, attribute(m.quadraticCoefficients,
            "numberOfQuadraticTerms"))
    else
        m.quadraticCoefficients = new_child(m.instanceData,
            "quadraticCoefficients")
        return 0
    end
end

function newquadterm!(parent::XMLElement, conidx, rowidx, colidx, val)
    term = new_child(parent, "qTerm")
    set_attribute(term, "idx", conidx) # -1 for objective terms
    set_attribute(term, "idxOne", rowidx - 1) # OSiL is 0-based
    set_attribute(term, "idxTwo", colidx - 1) # OSiL is 0-based
    set_attribute(term, "coef", val)
    return term
end

function splitlinquad(m::OsilMathProgModel, v::Vector{Float64})
    # split linear and quadratic parts from a constraint vector
    # assuming quadratic constraints and expression-tree nonlinear
    # constraints are never both present
    numquadconstr = length(m.quadconidx)
    linpart = Array(Float64, m.numberOfConstraints - numquadconstr)
    quadpart = Array(Float64, numquadconstr)
    prevquadidx = 0
    for (q, nextquadidx) in enumerate(m.quadconidx)
        linconrange = (prevquadidx + 1 : nextquadidx - 1)
        linpart[linconrange - q + 1] = v[linconrange]
        quadpart[q] = v[nextquadidx]
        prevquadidx = nextquadidx
    end
    linconrange = (prevquadidx + 1 : m.numberOfConstraints)
    linpart[linconrange - numquadconstr] = v[linconrange]
    return (linpart, quadpart)
end

# setters
function MathProgBase.setobj!(m::OsilMathProgModel, f)
    # remove and overwrite any existing objective coefficients
    for el in child_elements(m.obj)
        unlink(el)
        free(el)
    end
    numberOfObjCoef = 0
    for (i, val) in enumerate(f)
        (val == 0.0) && continue
        numberOfObjCoef += 1
        newobjcoef!(m.obj, i - 1, val) # OSiL is 0-based
    end
    set_attribute(m.obj, "numberOfObjCoef", numberOfObjCoef)
end

function MathProgBase.setvartype!(m::OsilMathProgModel, vartypes::Vector{Symbol})
    i = 0
    first_unset = 0
    for vari in child_elements(m.variables)
        i += 1
        if i > length(vartypes)
            set_attribute(vari, "type", "C")
            if first_unset == 0
                first_unset = i
            end
            continue
        end
        if haskey(jl2osil_vartypes, vartypes[i])
            set_attribute(vari, "type", jl2osil_vartypes[vartypes[i]])
            if vartypes[i] == :Bin
                if m.xl[i] < 0.0
                    warn("Setting lower bound for binary variable x[$i] ",
                        "to 0.0 (was $(m.xl[i]))")
                    m.xl[i] = 0.0
                    set_attribute(vari, "lb", 0.0)
                end
                if m.xu[i] > 1.0
                    warn("Setting upper bound for binary variable x[$i] ",
                        "to 1.0 (was $(m.xu[i]))")
                    m.xu[i] = 1.0
                    set_attribute(vari, "ub", 1.0)
                end
            end
        else
            error("Unrecognized vartype $(vartypes[i])")
        end
    end
    if first_unset != 0
        warn("Variable type not provided for variables ",
            "$(first_unset : i), assuming Continuous")
    else
        @assertequal(i, length(vartypes))
    end
    m.vartypes = vartypes
end

function MathProgBase.setvarLB!(m::OsilMathProgModel, xl::Vector{Float64})
    i = 0
    for xi in child_elements(m.variables)
        i += 1
        if xl[i] < 0.0 && attribute(xi, "type") == "B"
            warn("Setting lower bound for binary variable x[$i] ",
                "to 0.0 (was $(xl[i]))")
            xl[i] = 0.0
        end
        # set bound attribute unconditionally, even if infinite,
        # to ensure any previously set value gets overwritten
        set_attribute(xi, "lb", xl[i])
    end
    @assertequal(i, length(xl))
    m.xl = xl
end

function MathProgBase.setvarUB!(m::OsilMathProgModel, xu::Vector{Float64})
    i = 0
    for xi in child_elements(m.variables)
        i += 1
        if xu[i] > 1.0 && attribute(xi, "type") == "B"
            warn("Setting upper bound for binary variable x[$i] ",
                "to 1.0 (was $(xu[i]))")
            xu[i] = 1.0
        end
        # set bound attribute unconditionally, even if infinite,
        # to ensure any previously set value gets overwritten
        set_attribute(xi, "ub", xu[i])
    end
    @assertequal(i, length(xu))
    m.xu = xu
end

function setlinconstrbounds!(m::OsilMathProgModel, attr, v::Vector{Float64})
    if length(v) > 0
        i = 0
        q = 1
        # need to skip quadratic constraints since MPB treats those separately
        numquadconstr = length(m.quadconidx)
        if numquadconstr == 0
            for child in child_elements(m.constraints)
                i += 1
                # set bound attribute unconditionally, even if infinite,
                # to ensure any previously set value gets overwritten
                set_attribute(child, attr, v[i])
            end
        else
            nextquadidx = m.quadconidx[q]
            for child in child_elements(m.constraints)
                i += 1
                if i == nextquadidx
                    q += 1
                    if q <= numquadconstr
                        nextquadidx = m.quadconidx[q]
                    else
                        nextquadidx = m.numberOfConstraints + 1
                    end
                    continue
                else
                    # set bound attribute unconditionally, even if infinite,
                    # to ensure any previously set value gets overwritten
                    set_attribute(child, attr, v[i - q + 1])
                end
            end
        end
        @assertequal(i - q + 1, length(v))
        @assertequal(q - 1, numquadconstr)
    end
    return v
end

function MathProgBase.setconstrLB!(m::OsilMathProgModel, cl::Vector{Float64})
    m.cl = setlinconstrbounds!(m, "lb", cl)
end

function MathProgBase.setconstrUB!(m::OsilMathProgModel, cu::Vector{Float64})
    m.cu = setlinconstrbounds!(m, "ub", cu)
end

function MathProgBase.setsense!(m::OsilMathProgModel, objsense::Symbol)
    set_attribute(m.obj, "maxOrMin", lowercase(string(objsense)))
    m.objsense = objsense
end

function MathProgBase.setwarmstart!(m::OsilMathProgModel, x0::Vector{Float64})
    @assertequal(length(x0), m.numberOfVariables)
    m.x0 = x0
end

function MathProgBase.addvar!(m::OsilMathProgModel, lb, ub, objcoef)
    push!(m.xl, lb)
    push!(m.xu, ub)
    newvar!(m.variables, lb, ub)
    if objcoef != 0.0
        set_attribute(m.obj, "numberOfObjCoef", parse(Int,
            attribute(m.obj, "numberOfObjCoef"))) + 1
        # use old numberOfVariables since OSiL is 0-based
        newobjcoef!(m.obj, m.numberOfVariables, objcoef)
    end
    m.numberOfVariables += 1
    set_attribute(m.variables, "numberOfVariables", m.numberOfVariables)
    return m # or the new <var> xml element, or nothing ?
end

function MathProgBase.addconstr!(m::OsilMathProgModel, varidx, coef, lb, ub)
    @assertequal(length(varidx), length(coef))
    if m.numLinConstr + length(m.quadconidx) < m.numberOfConstraints
        error("Adding a constraint to a nonlinear model not implemented")
        # addnlconstr! could be done though, if it existed in MathProgBase
    end
    push!(m.cl, lb)
    push!(m.cu, ub)
    newcon!(m.constraints, lb, ub)

    if m.numLinConstr + length(m.quadconidx) == 0 && length(varidx) > 0
        (linConstrCoefs, rowstarts, colIdx, values) =
            create_empty_linconstr!(m)
        numberOfValues = 0
    else
        # could save linConstrCoefs and the sparse matrix
        # data as part of m, but choosing not to optimize this much
        linConstrCoefs = find_element(m.instanceData,
            "linearConstraintCoefficients")
        if linConstrCoefs != nothing
            rowstarts = find_element(linConstrCoefs, "start")
            colIdx = find_element(linConstrCoefs, "colIdx")
            values = find_element(linConstrCoefs, "value")
            numberOfValues = parse(Int,
                attribute(linConstrCoefs, "numberOfValues"))
        end
    end
    numdupes = 0
    if issorted(varidx, lt = (<=)) # this means strictly increasing
        for (i, curval) in enumerate(coef)
            if curval != 0.0 || i == length(coef) # always add at least one "nonzero"
                addnonzero!(colIdx, values, varidx[i] - 1, curval) # OSiL is 0-based
            else
                numdupes += 1
            end
        end
    elseif length(varidx) > 0
        # we have the whole vector of indices here,
        # maybe better to sort than use a dense bitarray
        p = sortperm(varidx)
        curidx = varidx[p[1]]
        curval = coef[p[1]]
        for i = 2:length(p)
            nextidx = varidx[p[i]]
            if nextidx > curidx
                if curval != 0.0
                    addnonzero!(colIdx, values, curidx - 1, curval) # OSiL is 0-based
                else
                    numdupes += 1
                end
                curidx = nextidx
                curval = coef[p[i]]
            else
                numdupes += 1
                curval += coef[p[i]]
            end
        end
        # always add at least one "nonzero," even if curval == 0.0
        addnonzero!(colIdx, values, curidx - 1, curval) # OSiL is 0-based
    end
    if linConstrCoefs != nothing
        numberOfValues += length(varidx) - numdupes
        set_attribute(linConstrCoefs, "numberOfValues", numberOfValues)
        add_text(new_child(rowstarts, "el"), string(numberOfValues))
    end

    m.numberOfConstraints += 1
    m.numLinConstr += 1
    set_attribute(m.constraints, "numberOfConstraints", m.numberOfConstraints)
    return m # or the new <con> xml element, or nothing ?
end

function MathProgBase.setquadobjterms!(m::OsilMathProgModel,
        rowidx, colidx, quadval)
    @assertequal(length(rowidx), length(colidx))
    @assertequal(length(rowidx), length(quadval))
    numQuadTerms = initialize_quadcoefs!(m)
    if isdefined(m, :quadobjterms)
        numQuadTerms -= length(m.quadobjterms)
        # remove and overwrite any existing quadratic objective terms
        for el in m.quadobjterms
            unlink(el)
            free(el)
        end
    end
    quadobjterms = Array(XMLElement, length(quadval))
    for i = 1:length(quadval)
        quadobjterms[i] = newquadterm!(m.quadraticCoefficients, "-1",
            rowidx[i], colidx[i], quadval[i])
    end
    m.quadobjterms = quadobjterms
    set_attribute(m.quadraticCoefficients, "numberOfQuadraticTerms",
        numQuadTerms + length(quadval))
    return m # or the new quadobjterms, or nothing ?
end

function MathProgBase.addquadconstr!(m::OsilMathProgModel, linearidx,
        linearval, quadrowidx, quadcolidx, quadval, sense, rhs)
    @assertequal(length(quadrowidx), length(quadcolidx))
    @assertequal(length(quadrowidx), length(quadval))
    numQuadTerms = initialize_quadcoefs!(m)
    # use old numberOfConstraints since OSiL is 0-based
    conidx = m.numberOfConstraints
    for i = 1:length(quadval)
        newquadterm!(m.quadraticCoefficients, conidx,
            quadrowidx[i], quadcolidx[i], quadval[i])
    end
    set_attribute(m.quadraticCoefficients, "numberOfQuadraticTerms",
        numQuadTerms + length(quadval))

    push!(m.qrhs, rhs)
    if sense == '<'
        (lb, ub) = (-Inf, rhs)
    elseif sense == '>'
        (lb, ub) = (rhs, Inf)
    elseif sense == '='
        (lb, ub) = (rhs, rhs)
    else
        error("Unknown quadratic constraint sense $sense")
    end
    # always add a dummy linear part for every quadratic
    # constraint to make the bookkeeping simpler
    if isempty(linearidx) && isempty(linearval)
        MathProgBase.addconstr!(m, [1], [0.0], lb, ub)
    else
        MathProgBase.addconstr!(m, linearidx, linearval, lb, ub)
    end
    m.numLinConstr -= 1 # since this constraint is quadratic, not linear
    pop!(m.cl) # MathProgBase treats quadratic constraints separately
    pop!(m.cu)
    push!(m.quadconidx, m.numberOfConstraints)
    return m # or the new <con> xml element, or nothing ?
end

# TODO: setquadconstrRHS!, getconstrsolution, getconstrmatrix, getrawsolver,
# getsolvetime, sos constraints, basis, infeasibility/unbounded rays?

# General wrapper functions
for f in [:getsolution,:getobjval,:optimize!,:status,:getsense,:numvar,:numconstr,:getvartype,:getreducedcosts,:getconstrduals]
    @eval $f(m::OsilNonlinearModel) = $f(m.inner)
    @eval $f(m::OsilLinearQuadraticModel) = $f(m.inner)
end
for f in [:setsense!,:setvartype!,:setwarmstart!]
    @eval $f(m::OsilNonlinearModel, x) = $f(m.inner, x)
    @eval $f(m::OsilLinearQuadraticModel, x) = $f(m.inner, x)
end

# LinearQuadratic wrapper functions
for f in [:numlinconstr,:numquadconstr,:getquadconstrduals,:getvarLB,:getvarUB,:getconstrLB,:getconstrUB,:getobj]
    @eval $f(m::OsilLinearQuadraticModel) = $f(m.inner)
end
for f in [:setobj!,:setvarLB!,:setvarUB!,:setconstrLB!,:setconstrUB!]
    @eval $f(m::OsilLinearQuadraticModel, x) = $f(m.inner, x)
end
for f in [:addvar!, :setquadobjterms!]
    @eval $f(m::OsilLinearQuadraticModel, x, y, z) = $f(m.inner, x, y, z)
end
for f in [:addconstr!]
    @eval $f(m::OsilLinearQuadraticModel, w, x, y, z) = $f(m.inner, w, x, y, z)
end
for f in [:addquadconstr!]
    @eval $f(m::OsilLinearQuadraticModel, a, b, c, d, e, f, g) =
        $f(m.inner, a, b, c, d, e, f, g)
end

