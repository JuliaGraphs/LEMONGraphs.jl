module LEMONGraphsGraphsOptimExt

using LEMONGraphs
using Graphs
using GraphsOptim

"""
    shortest_path(g::AbstractGraph, source::Int, target::Int, edge_cost::AbstractMatrix, ::LEMONGraphs.LEMONAlgorithm)

Compute the shortest path using LEMON's Dijkstra backend.

Returns a sequence of vertices from `source` to `target`.
"""
function GraphsOptim.shortest_path(
    g::AbstractGraph,
    source::Int,
    target::Int,
    edge_cost::AbstractMatrix,
    alg::LEMONGraphs.LEMONAlgorithm
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
    min_cost_assignment(edge_cost::AbstractMatrix, ::LEMONGraphs.LEMONAlgorithm; kwargs...)

Stub for a future LEMON-backed assignment solver.
"""
function GraphsOptim.min_cost_assignment(
    edge_cost::AbstractMatrix,
    ::LEMONGraphs.LEMONAlgorithm;
    kwargs...
)
    throw(ArgumentError(
        "LEMON min_cost_assignment is not available yet. " *
        "Use GraphsOptim.min_cost_assignment without LEMONAlgorithm."
    ))
end

"""
    min_vertex_cover(g::AbstractGraph, ::LEMONGraphs.LEMONAlgorithm; kwargs...)

Stub for a future LEMON-backed minimum vertex cover solver.
"""
function GraphsOptim.min_vertex_cover(
    g::AbstractGraph,
    ::LEMONGraphs.LEMONAlgorithm;
    kwargs...
)
    throw(ArgumentError(
        "LEMON min_vertex_cover is not available yet. " *
        "Use GraphsOptim.min_vertex_cover without LEMONAlgorithm."
    ))
end

"""
    maximum_weight_clique(g::AbstractGraph, ::LEMONGraphs.LEMONAlgorithm; kwargs...)

Stub for a future LEMON-backed maximum weight clique solver.
"""
function GraphsOptim.maximum_weight_clique(
    g::AbstractGraph,
    ::LEMONGraphs.LEMONAlgorithm;
    kwargs...
)
    throw(ArgumentError(
        "LEMON maximum_weight_clique is not available yet. " *
        "Use GraphsOptim.maximum_weight_clique without LEMONAlgorithm."
    ))
end

"""
    min_cost_flow(g::AbstractGraph, vertex_demand, edge_cost, ::LEMONGraphs.LEMONAlgorithm; kwargs...)

Stub for a future LEMON-backed min cost flow solver.
"""
function GraphsOptim.min_cost_flow(
    g::AbstractGraph,
    vertex_demand,
    edge_cost,
    ::LEMONGraphs.LEMONAlgorithm;
    kwargs...
)
    throw(ArgumentError(
        "LEMON min_cost_flow is not available yet. " *
        "Use GraphsOptim.min_cost_flow without LEMONAlgorithm."
    ))
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

# Future algorithms: As more LEMON algorithms are exposed in Yggdrasil,
# add corresponding dispatch methods here.

end  # module
