module LEMONGraphsGraphsOptimExt

using LEMONGraphs
using Graphs
using GraphsOptim
using SparseArrays: sparse

const Lib = LEMONGraphs.Lib
const LEMONAlg = LEMONGraphs.LEMONAlgorithm
const CxxLong = LEMONGraphs.CxxLong

"""
    shortest_path(g, source, target, edge_cost, ::LEMONAlgorithm)

Compute the shortest path using LEMON's Dijkstra backend.

Returns the sequence of vertices from `source` to `target`. Only integer
`edge_cost` matrices are supported, because LEMON's `Dijkstra` binding is
instantiated for C++ `int`.
"""
function GraphsOptim.shortest_path(
    g::AbstractGraph,
    source::Int,
    target::Int,
    edge_cost::AbstractMatrix,
    alg::LEMONAlg,
)
    if !(eltype(edge_cost) <: Integer)
        throw(ArgumentError(
            "LEMON shortest_path only supports integer edge costs. " *
            "Provide an integer cost matrix or use the default GraphsOptim solver backend."
        ))
    end
    state = Graphs.dijkstra_shortest_paths(g, source, edge_cost, alg)
    return _reconstruct_path(state.parents, source, target)
end

"""
    min_cost_assignment(edge_cost, ::LEMONAlgorithm; kwargs...)

Solve the square linear assignment problem with LEMON's `NetworkSimplex`.

`edge_cost` must be a square matrix of integer-valued costs. The result is a
`Matrix{Int}` of zeros and ones with exactly one `1` per row and per column,
minimising `sum(edge_cost .* assignment)`.

The `integer` keyword accepted by `GraphsOptim.min_cost_assignment` is ignored:
the network simplex is always integral, and so is the assignment polytope.
"""
function GraphsOptim.min_cost_assignment(
    edge_cost::AbstractMatrix, ::LEMONAlg; integer::Bool=true, kwargs...
)
    n, m = size(edge_cost)
    n == m || throw(DimensionMismatch(
        "LEMON min_cost_assignment requires a square cost matrix, got $(n)×$(m)"
    ))
    n == 0 && return zeros(Int, 0, 0)

    # Bipartite transportation network:
    #   source -> row i -> column j -> sink, every arc of capacity 1.
    dg = Lib.ListDigraph()
    nnodes = 2n + 2
    source, sink = 2n + 1, 2n + 2
    nodes = [Lib.addNode(dg) for _ in 1:nnodes]

    arcs = [Lib.addArc(dg, nodes[source], nodes[i]) for i in 1:n]
    append!(arcs, Lib.addArc(dg, nodes[n + j], nodes[sink]) for j in 1:n)
    # `arc_cell[k]` is the (row, column) an arc represents, or `(0, 0)` for the
    # source/sink arcs that carry no cost.
    arc_cell = fill((0, 0), length(arcs))
    arc_cost = zeros(CxxLong, length(arcs))
    for i in 1:n, j in 1:n
        push!(arcs, Lib.addArc(dg, nodes[i], nodes[n + j]))
        push!(arc_cell, (i, j))
        push!(arc_cost, _lemon_value(edge_cost[i, j], "assignment cost"))
    end

    supply = zeros(CxxLong, nnodes)
    supply[source] = CxxLong(n)
    supply[sink] = CxxLong(-n)

    flows = _run_min_cost_flow(
        dg, nodes, arcs, supply, :network_simplex;
        lower=_ -> zero(CxxLong), upper=_ -> one(CxxLong), cost=k -> arc_cost[k],
    )

    assignment = zeros(Int, n, n)
    for (k, f) in enumerate(flows)
        i, j = arc_cell[k]
        i == 0 && continue
        assignment[i, j] = Int(f)
    end
    return assignment
end

"""
    min_vertex_cover(g, ::LEMONAlgorithm; kwargs...)

LEMON does not ship a minimum vertex cover solver, so this method always throws.
It exists so that the `LEMONAlgorithm()` dispatch fails with an actionable
message rather than a bare `MethodError`.
"""
function GraphsOptim.min_vertex_cover(g::AbstractGraph, ::LEMONAlg; kwargs...)
    throw(ArgumentError(
        "LEMON ships no minimum vertex cover solver, so min_vertex_cover has no " *
        "LEMON backend. Drop the LEMONAlgorithm() argument to use GraphsOptim's."
    ))
end

"""
    maximum_weight_clique(g, ::LEMONAlgorithm; kwargs...)

LEMON does not ship a maximum weight clique solver, so this method always
throws, for the same reason as `min_vertex_cover`.
"""
function GraphsOptim.maximum_weight_clique(g::AbstractGraph, ::LEMONAlg; kwargs...)
    throw(ArgumentError(
        "LEMON ships no maximum weight clique solver, so maximum_weight_clique has " *
        "no LEMON backend. Drop the LEMONAlgorithm() argument to use GraphsOptim's."
    ))
end

"""
    min_cost_flow(g, vertex_demand, edge_cost, ::LEMONAlgorithm; solver=:network_simplex)
    min_cost_flow(g, vertex_demand, edge_cost, edge_min_capacity, edge_max_capacity, ::LEMONAlgorithm; solver=:network_simplex)

Compute a minimum cost flow with one of LEMON's minimum cost flow solvers.

The argument conventions match `GraphsOptim.min_cost_flow`: `vertex_demand` is
positive at sinks and negative at sources, and the capacity/cost matrices are
indexed by `[u, v]`. All values must be integers; `edge_max_capacity` entries
may also be `Inf` to denote an uncapacitated arc.

`solver` selects the LEMON implementation, one of `:network_simplex` (the
default and usually the fastest), `:capacity_scaling`, `:cost_scaling` or
`:cycle_canceling`. All four return an optimal flow; they differ in running
time, and only `:network_simplex` accepts negative costs on arcs whose upper
capacity is infinite; the others report such a problem as unbounded.

The returned sparse matrix holds the flow on every arc. For an undirected `g`
each edge is modelled by an arc in both directions (as `GraphsOptim` does), and
unlike `GraphsOptim` both orientations appear in the result.

Throws an `ArgumentError` if the problem is infeasible or unbounded.
"""
function GraphsOptim.min_cost_flow(
    g::AbstractGraph, vertex_demand, edge_cost, alg::LEMONAlg; kwargs...
)
    return GraphsOptim.min_cost_flow(
        g, vertex_demand, edge_cost, nothing, nothing, alg; kwargs...
    )
end

function GraphsOptim.min_cost_flow(
    g::AbstractGraph,
    vertex_demand,
    edge_cost,
    edge_min_capacity,
    edge_max_capacity,
    ::LEMONAlg;
    solver::Symbol=:network_simplex,
    integer::Bool=true,
    kwargs...,
)
    ldg = LEMONGraphs.LEMONDiGraph(g)
    nvg = Graphs.nv(ldg)
    length(vertex_demand) == nvg || throw(DimensionMismatch(
        "vertex_demand has length $(length(vertex_demand)) but the graph has $nvg vertices"
    ))

    us, vs = ldg.arc_src, ldg.arc_dst
    supply = Vector{CxxLong}(undef, nvg)
    for v in 1:nvg
        # GraphsOptim states the balance as `inflow == demand + outflow`, whereas
        # LEMON's supply map is `outflow - inflow`; hence the sign flip.
        supply[v] = -_lemon_value(vertex_demand[v], "vertex demand")
    end

    flows = _run_min_cost_flow(
        ldg.graph, ldg.nodes, ldg.arcs, supply, solver;
        lower=k -> _lemon_capacity(edge_min_capacity, us[k], vs[k], zero(CxxLong)),
        upper=k -> _lemon_capacity(edge_max_capacity, us[k], vs[k], typemax(CxxLong)),
        cost=k -> _lemon_value(edge_cost[us[k], vs[k]], "edge cost"),
    )

    return sparse(us, vs, Int.(flows), nvg, nvg)
end

# --- helpers ---------------------------------------------------------------

# LEMON's flow solvers are instantiated for `long long`, so every value has to
# be an exact integer. Integral floats are accepted -- mixing `Inf` with finite
# capacities forces a floating point matrix -- but nothing is ever rounded.
_lemon_value(x::Integer, what::AbstractString) = CxxLong(x)
function _lemon_value(x, what::AbstractString)
    x isa Real && isinteger(x) && return CxxLong(x)
    throw(ArgumentError(
        "LEMON requires an integer $what, got $(repr(x))::$(typeof(x))"
    ))
end

_lemon_capacity(::Nothing, _u, _v, default::CxxLong) = default
function _lemon_capacity(m, u, v, default::CxxLong)
    x = m[u, v]
    x isa Integer && return CxxLong(x)
    (x isa Real && isinf(x) && x > 0) && return typemax(CxxLong)
    x isa Real && isinteger(x) && return CxxLong(x)
    throw(ArgumentError(
        "LEMON requires integer capacities (or `Inf` for an unbounded upper capacity), " *
        "got $(repr(x))::$(typeof(x)) at ($u, $v)"
    ))
end

"""
    LEMONGraphsGraphsOptimExt.MIN_COST_FLOW_SOLVERS

The LEMON minimum cost flow solvers reachable through the `solver` keyword of
`min_cost_flow(..., LEMONAlgorithm())`.
"""
const MIN_COST_FLOW_SOLVERS = (
    :network_simplex, :capacity_scaling, :cost_scaling, :cycle_canceling
)

function _min_cost_flow_solver_type(solver::Symbol)
    solver === :network_simplex && return Lib.NetworkSimplex{CxxLong,CxxLong}
    solver === :capacity_scaling && return Lib.CapacityScaling{CxxLong,CxxLong}
    solver === :cost_scaling && return Lib.CostScaling{CxxLong,CxxLong}
    solver === :cycle_canceling && return Lib.CycleCanceling{CxxLong,CxxLong}
    throw(ArgumentError(
        "unknown LEMON minimum cost flow solver $(repr(solver)); " *
        "expected one of $(MIN_COST_FLOW_SOLVERS)"
    ))
end

"""
    _run_min_cost_flow(dg, nodes, arcs, supply, solver; lower, upper, cost)

Fill LEMON arc/node maps from the callables `lower`, `upper` and `cost` (each
called with an arc index) plus the `supply` vector, run the requested LEMON
minimum cost flow solver, and return the flow on each arc in the order of
`arcs`.
"""
function _run_min_cost_flow(
    dg, nodes, arcs, supply::Vector{CxxLong}, solver::Symbol; lower, upper, cost
)
    solver_type = _min_cost_flow_solver_type(solver)
    lower_map = Lib.ListDigraphArcMap{CxxLong}(dg)
    upper_map = Lib.ListDigraphArcMap{CxxLong}(dg)
    cost_map = Lib.ListDigraphArcMap{CxxLong}(dg)
    supply_map = Lib.ListDigraphNodeMap{CxxLong}(dg)

    for (k, a) in enumerate(arcs)
        lo = lower(k)
        up = upper(k)
        lo <= up || throw(ArgumentError(
            "arc $k has a minimum capacity ($lo) above its maximum capacity ($up)"
        ))
        Lib.set(lower_map, a, lo)
        Lib.set(upper_map, a, up)
        Lib.set(cost_map, a, cost(k))
    end
    for (v, node) in enumerate(nodes)
        Lib.set(supply_map, node, v <= length(supply) ? supply[v] : zero(CxxLong))
    end

    backend = solver_type(dg)
    Lib.lowerMap(backend, lower_map)
    Lib.upperMap(backend, upper_map)
    Lib.costMap(backend, cost_map)
    Lib.supplyMap(backend, supply_map)

    status = Lib.run(backend)
    if status == Lib.ProblemTypeInfeasible()
        throw(ArgumentError("LEMON found the minimum cost flow problem infeasible"))
    elseif status == Lib.ProblemTypeUnbounded()
        throw(ArgumentError(
            "LEMON found the minimum cost flow problem unbounded. Only " *
            "`solver = :network_simplex` supports negative costs on arcs with an " *
            "infinite upper capacity; give those arcs a finite capacity otherwise."
        ))
    end
    return CxxLong[Lib.flow(backend, a) for a in arcs]
end

function _reconstruct_path(parents::AbstractVector{<:Integer}, source::Int, target::Int)
    source == target && return [source]

    path = Int[]
    current = target
    while current != 0
        push!(path, current)
        current == source && break
        current = parents[current]
    end

    if isempty(path) || path[end] != source
        throw(ArgumentError("No path from source to target using LEMON backend"))
    end

    reverse!(path)
    return path
end

# Future algorithms: as more LEMON solvers are exposed by LEMON_jll (it also
# ships the CapacityScaling, CostScaling and CycleCanceling minimum cost flow
# solvers), add the corresponding `LEMONAlgorithm` dispatches here.

end  # module
