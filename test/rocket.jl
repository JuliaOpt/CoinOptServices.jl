using JuMP, Ipopt, AmplNLWriter, CoinOptServices
open("ipopt.opt", "w") do f
    print(f, "print_timing_statistics yes") # for IpoptNLSolver
end
function rocket()
for mod in (Model(solver=IpoptSolver(print_timing_statistics="yes")),
    Model(solver=IpoptNLSolver()),
    Model(solver=OsilSolver(OSOption("print_timing_statistics", "yes"),
        OSOption("print_level", 5),
        OSOption("max_iter", 27))))

# Constants
# Note that all parameters in the model have been normalized
# to be dimensionless. See the COPS3 paper for more info.
h_0 = 1    # Initial height
v_0 = 0    # Initial velocity
m_0 = 1    # Initial mass
g_0 = 1    # Gravity at the surface

# Parameters
T_c = 3.5  # Used for thrust
h_c = 500  # Used for drag
v_c = 620  # Used for drag
m_c = 0.6  # Fraction of initial mass left at end

# Derived parameters
c     = 0.5*sqrt(g_0*h_0)  # Thrust-to-fuel mass
m_f   = m_c*m_0            # Final mass
D_c   = 0.5*v_c*m_0/g_0    # Drag scaling
T_max = T_c*g_0*m_0        # Maximum thrust

# Time steps
n = 800
# Time step with initial guess
@defVar(mod, Δt ≥ 0, start = 1/n)
# Store a useful subexpression, "time of flight"
@defNLExpr(t_f, Δt*n)

# State variables
@defVar(mod, v[0:n] ≥ 0)            # Velocity
@defVar(mod, h[0:n] ≥ h_0)          # Height
@defVar(mod, m_f ≤ m[0:n] ≤ m_0)    # Mass

# Control: thrust
@defVar(mod, 0 ≤ T[0:n] ≤ T_max)

# Provide starting solution
# Could have done this at same time as @defVar
for k in 0:n
    setValue(h[k], 1)
    setValue(v[k], (k/n)*(1 - (k/n)))
    setValue(m[k], (m_f - m_0)*(k/n) + m_0)
    setValue(T[k], T_max/2)
end

# Objective: maximize altitude at end of time of flight
@setObjective(mod, Max, h[n])

# Initial conditions
@addConstraint(mod, v[0] == v_0)
@addConstraint(mod, h[0] == h_0)
@addConstraint(mod, m[0] == m_0)
@addConstraint(mod, m[n] == m_f)

# Forces
# We'll define these as expressions too
# Wherever they appear, they will effectively be
# replaced by these longer expressions, keeps them
# nice and clean

# Drag(h,v) = Dc v^2 exp( -hc * (h - h0) / h0 )
@defNLExpr(drag[j=0:n], D_c*(v[j]^2)*exp(-h_c*(h[j]-h_0)/h_0))
# Grav(h)   = g0 * (h0 / h)^2
@defNLExpr(grav[j=0:n], g_0*(h_0/h[j])^2)

# Dynamics
for j in 1:n
    # h' = v
    # Rectangular integration
    # @addNLConstraint(mod, h[j] == h[j-1] + Δt*v[j-1])
    # Trapezoidal integration
    @addNLConstraint(mod,
        h[j] == h[j-1] + 0.5*Δt*(v[j]+v[j-1]))

    # v' = (T-D(h,v))/m - g(h)
    # Rectangular integration
    # @addNLConstraint(mod, v[j] == v[j-1] + Δt*(
    #                 (T[j-1] - drag[j-1])/m[j-1] - grav[j-1]))
    # Trapezoidal integration
    @addNLConstraint(mod,
        v[j] == v[j-1] + 0.5*Δt*(
            (T[j  ] - drag[j  ] - m[j  ]*grav[j  ])/m[j  ] +
            (T[j-1] - drag[j-1] - m[j-1]*grav[j-1])/m[j-1] ))

    # m' = -T/c
    # Rectangular integration
    # @addNLConstraint(mod, m[j] == m[j-1] - Δt*T[j-1]/c)
    # Trapezoidal integration
    @addNLConstraint(mod,
        m[j] == m[j-1] - 0.5*Δt*(T[j] + T[j-1])/c)
end
println("Solving...")
status = solve(mod)

# Display results
println("Solver status: ", status)
println("Max height: ", getObjectiveValue(mod))
end
end
