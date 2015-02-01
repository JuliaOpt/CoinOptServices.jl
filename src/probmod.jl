# getters
MathProgBase.status(m::OsilMathProgModel) = m.status
MathProgBase.numvar(m::OsilMathProgModel) = m.numberOfVariables
MathProgBase.numconstr(m::OsilMathProgModel) = m.numberOfConstraints
MathProgBase.numlinconstr(m::OsilMathProgModel) = m.numLinConstr
MathProgBase.numquadconstr(m::OsilMathProgModel) = 0 # TODO: quadratic problems
MathProgBase.getobjval(m::OsilMathProgModel) = m.objval
MathProgBase.getsolution(m::OsilMathProgModel) = m.solution
MathProgBase.getreducedcosts(m::OsilMathProgModel) = m.reducedcosts
MathProgBase.getconstrduals(m::OsilMathProgModel) = m.constrduals
MathProgBase.getsense(m::OsilMathProgModel) = m.objsense
MathProgBase.getvartype(m::OsilMathProgModel) = m.vartypes
MathProgBase.getvarLB(m::OsilMathProgModel) = m.xl
MathProgBase.getvarUB(m::OsilMathProgModel) = m.xu
MathProgBase.getconstrLB(m::OsilMathProgModel) = m.cl
MathProgBase.getconstrUB(m::OsilMathProgModel) = m.cu
MathProgBase.getobj(m::OsilMathProgModel) =
    xml2vec(m.obj, m.numberOfVariables, 0.0)

# setters
function MathProgBase.setvartype!(m::OsilMathProgModel, vartypes::Vector{Symbol})
    i = 0
    for vari in child_elements(m.variables)
        i += 1
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
    @assertequal(i, length(vartypes))
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
        set_attribute(xi, "ub", xu[i])
    end
    @assertequal(i, length(xu))
    m.xu = xu
end

function setattr!(parent::XMLElement, attr, v::Vector{Float64})
    i = 0
    for child in child_elements(parent)
        i += 1
        set_attribute(child, attr, v[i])
    end
    @assertequal(i, length(v))
    return v
end

function MathProgBase.setconstrLB!(m::OsilMathProgModel, cl::Vector{Float64})
    m.cl = setattr!(m.constraints, "lb", cl)
end

function MathProgBase.setconstrUB!(m::OsilMathProgModel, cu::Vector{Float64})
    m.cu = setattr!(m.constraints, "ub", cu)
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
        set_attribute(m.obj, "numberOfObjCoef",
            int(attribute(m.obj, "numberOfObjCoef")) + 1)
        # use old numberOfVariables since OSiL is 0-based
        newobjcoef!(m.obj, m.numberOfVariables, objcoef)
    end
    m.numberOfVariables += 1
    set_attribute(m.variables, "numberOfVariables", m.numberOfVariables)
    return m # or the new <var> xml element, or nothing ?
end

function MathProgBase.addconstr!(m::OsilMathProgModel, varidx, coef, lb, ub)
    @assertequal(length(varidx), length(coef))
    if m.numLinConstr < m.numberOfConstraints
        error("Adding a constraint to a nonlinear model not implemented")
    end
    newcon!(m.constraints, lb, ub)

    if m.numLinConstr == 0
        (linConstrCoefs, rowstarts, colIdx, values) =
            create_empty_linconstr!(m)
        numberOfValues = 0
    else
        # could save linConstrCoefs and the sparse matrix
        # data as part of m, but choosing not to optimize this much
        linConstrCoefs = find_element(m.instanceData,
            "linearConstraintCoefficients")
        rowstarts = find_element(linConstrCoefs, "start")
        colIdx = find_element(linConstrCoefs, "colIdx")
        values = find_element(linConstrCoefs, "value")
        numberOfValues = int(attribute(linConstrCoefs, "numberOfValues"))
    end
    numberOfValues += length(varidx)
    set_attribute(linConstrCoefs, "numberOfValues", numberOfValues)
    add_text(new_child(rowstarts, "el"), string(numberOfValues))
    for i = 1:length(varidx)
        add_text(new_child(colIdx, "el"), string(varidx[i] - 1)) # OSiL is 0-based
        add_text(new_child(values, "el"), string(coef[i]))
    end

    m.numberOfConstraints += 1
    m.numLinConstr += 1
    set_attribute(m.constraints, "numberOfConstraints", m.numberOfConstraints)
    return m # or the new <con> xml element, or nothing ?
end

function newquadterm!(parent::XMLElement, conidx, rowidx, colidx, val)
    term = new_child(parent, "qTerm")
    set_attribute(term, "idx", conidx) # -1 for objective terms
    set_attribute(term, "idxOne", rowidx - 1) # OSiL is 0-based
    set_attribute(term, "idxTwo", colidx - 1) # OSiL is 0-based
    set_attribute(term, "coef", val)
    return term
end

function MathProgBase.setquadobjterms!(m::OsilMathProgModel,
        rowidx, colidx, quadval)
    @assertequal(length(rowidx), length(colidx))
    @assertequal(length(rowidx), length(quadval))
    if isdefined(m, :quadraticCoefficients)
        numQuadTerms = int(attribute(m.quadraticCoefficients,
            "numberOfQuadraticTerms"))
    else
        m.quadraticCoefficients = new_child(m.instanceData,
            "quadraticCoefficients")
        numQuadTerms = 0
    end
    if isdefined(m, :quadobjterms)
        numQuadTerms -= length(m.quadobjterms)
        # unlink and free any existing quadratic objective terms
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

