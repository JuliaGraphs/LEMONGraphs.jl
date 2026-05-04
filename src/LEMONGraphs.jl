module LEMONGraphs

import Graphs
import Graphs: 
    Graph, DiGraph, Edge, vertices, edges, nv, ne, src, dst, 
    has_vertex, has_edge, inneighbors, outneighbors, is_directed, 
    edgetype, AbstractGraph

using CxxWrap

# CxxWrap binding module
module Lib
  using CxxWrap
  import LEMON_jll
  @wrapmodule(LEMON_jll.get_liblemoncxxwrap_path)

  function __init__()
    @initcxx
  end

  # Convenience helpers for node/edge ID extraction
  id(n::ListGraphNodeIt) = id(convert(ListGraphNode, n))
  id(n::ListGraphEdgeIt) = id(convert(ListGraphEdge, n))
  id(n::ListDigraphNodeIt) = id(convert(ListDigraphNode, n))
end

export LEMONGraph, LEMONDiGraph, LEMONAlgorithm, maxweightedperfectmatching

"""
    LEMONGraph{T,G,N,E} <: AbstractGraph{Int}

Wrapper around LEMON's `ListGraph` C++ type providing a Julia interface
conforming to the Graphs.jl AbstractGraph API.
"""
struct LEMONGraph{T,G,N,E} <: AbstractGraph{Int}
    graph::G
    nodes::N
    edges::E
    
    LEMONGraph(g, ns, es) = new{eltype(ns), typeof(g), typeof(ns), typeof(es)}(g, ns, es)
end

"""
    LEMONDiGraph{T,G,N,A} <: AbstractGraph{Int}

Wrapper around LEMON's `ListDigraph` C++ type providing a Julia interface
conforming to the Graphs.jl AbstractGraph API.
"""
struct LEMONDiGraph{T,G,N,A} <: AbstractGraph{Int}
    graph::G
    nodes::N
    arcs::A
    
    LEMONDiGraph(g, ns, as) = new{eltype(ns), typeof(g), typeof(ns), typeof(as)}(g, ns, as)
end

"""
    LEMONAlgorithm()

Marker type for dispatch to LEMON-backed algorithm implementations.
"""
struct LEMONAlgorithm end

# Fast conversion helpers
"""
    to_list_graph(g::Graph) -> (ListGraph, Vector, Vector)
    
Fast conversion that caches nodes/edges for reuse in LEMONGraph wrapper.
If `g` is already a LEMONGraph, returns its internal representation.
"""
function to_list_graph(g::Graph)
    lg = Lib.ListGraph()
    ns = [Lib.addNode(lg) for _ in Graphs.vertices(g)]
    es = [Lib.addEdge(lg, ns[Graphs.src(e)], ns[Graphs.dst(e)]) for e in Graphs.edges(g)]
    return (lg, ns, es)
end

function to_list_graph(g::LEMONGraph)
    return (g.graph, g.nodes, g.edges)  # O(1) reuse
end

"""
    to_list_digraph(g::DiGraph) -> (ListDigraph, Vector, Vector)
    
Fast conversion for directed graphs.
"""
function to_list_digraph(g::DiGraph)
    dg = Lib.ListDigraph()
    ns = [Lib.addNode(dg) for _ in Graphs.vertices(g)]
    as = [Lib.addArc(dg, ns[Graphs.src(e)], ns[Graphs.dst(e)]) for e in Graphs.edges(g)]
    return (dg, ns, as)
end

function to_list_digraph(g::LEMONDiGraph)
    return (g.graph, g.nodes, g.arcs)  # O(1) reuse
end

# Constructors
"""
    LEMONGraph(g::Graph) -> LEMONGraph

Convert a Graphs.jl Graph to a LEMONGraph wrapper.
"""
function LEMONGraph(g::Graph)
    lg, ns, es = to_list_graph(g)
    return LEMONGraph(lg, ns, es)
end

"""
    LEMONDiGraph(g::DiGraph) -> LEMONDiGraph

Convert a Graphs.jl DiGraph to a LEMONDiGraph wrapper.
"""
function LEMONDiGraph(g::DiGraph)
    dg, ns, as = to_list_digraph(g)
    return LEMONDiGraph(dg, ns, as)
end

# AbstractGraph API for LEMONGraph (undirected)
Graphs.nv(g::LEMONGraph) = length(g.nodes)
Graphs.ne(g::LEMONGraph) = length(g.edges)
Graphs.vertices(g::LEMONGraph) = Base.OneTo(length(g.nodes))
Graphs.edges(g::LEMONGraph) = [Edge(Lib.id(Lib.u(g.graph, e)) + 1, Lib.id(Lib.v(g.graph, e)) + 1) for e in g.edges]
Graphs.has_vertex(g::LEMONGraph, v::Integer) = 1 ≤ v ≤ length(g.nodes)
Graphs.has_edge(g::LEMONGraph, u::Integer, v::Integer) = any(g.edges) do e
    su = Lib.id(Lib.u(g.graph, e)) + 1
    sv = Lib.id(Lib.v(g.graph, e)) + 1
    (su == u && sv == v) || (su == v && sv == u)
end
Graphs.is_directed(::Type{<:LEMONGraph}) = false
Graphs.is_directed(::LEMONGraph) = false
Graphs.edgetype(::LEMONGraph) = Edge
Graphs.edgetype(::Type{<:LEMONGraph}) = Edge

function Graphs.inneighbors(g::LEMONGraph, v::Integer)
    return [
        Lib.id(Lib.u(g.graph, e)) + 1 == v ? Lib.id(Lib.v(g.graph, e)) + 1 : Lib.id(Lib.u(g.graph, e)) + 1
        for e in g.edges if Lib.id(Lib.u(g.graph, e)) + 1 == v || Lib.id(Lib.v(g.graph, e)) + 1 == v
    ]
end

function Graphs.outneighbors(g::LEMONGraph, v::Integer)
    return Graphs.inneighbors(g, v)  # undirected
end

# AbstractGraph API for LEMONDiGraph (directed)
Graphs.nv(g::LEMONDiGraph) = length(g.nodes)
Graphs.ne(g::LEMONDiGraph) = length(g.arcs)
Graphs.vertices(g::LEMONDiGraph) = Base.OneTo(length(g.nodes))
Graphs.edges(g::LEMONDiGraph) = [Edge(Lib.id(Lib.source(g.graph, a)) + 1, Lib.id(Lib.target(g.graph, a)) + 1) for a in g.arcs]
Graphs.has_vertex(g::LEMONDiGraph, v::Integer) = 1 ≤ v ≤ length(g.nodes)
Graphs.has_edge(g::LEMONDiGraph, u::Integer, v::Integer) = any(g.arcs) do a
    Lib.id(Lib.source(g.graph, a)) + 1 == u && Lib.id(Lib.target(g.graph, a)) + 1 == v
end
Graphs.is_directed(::Type{<:LEMONDiGraph}) = true
Graphs.is_directed(::LEMONDiGraph) = true
Graphs.edgetype(::LEMONDiGraph) = Edge
Graphs.edgetype(::Type{<:LEMONDiGraph}) = Edge

function Graphs.inneighbors(g::LEMONDiGraph, v::Integer)
    return [Lib.id(Lib.source(g.graph, a)) + 1 for a in g.arcs if Lib.id(Lib.target(g.graph, a)) + 1 == v]
end

function Graphs.outneighbors(g::LEMONDiGraph, v::Integer)
    return [Lib.id(Lib.target(g.graph, a)) + 1 for a in g.arcs if Lib.id(Lib.source(g.graph, a)) + 1 == v]
end

# LEMON-specific algorithm dispatches
"""
    maxweightedperfectmatching(g::Graph, weights::AbstractVector, alg::LEMONAlgorithm)

Compute maximum-weight perfect matching using LEMON backend.
"""
function maxweightedperfectmatching(g::Graph, weights::AbstractVector{<:Integer}, alg::LEMONAlgorithm)
    lg, ns, es = to_list_graph(g)
    mapedge = Lib.ListGraphEdgeMapInt(lg)
    for (e, w) in zip(es, weights)
        Lib.set(mapedge, e, w)
    end
    mwpm = Lib.MaxWeightedPerfectMatchingListGraphInt(lg, mapedge)
    Lib.run(mwpm)
    return Lib.matchingWeight(mwpm), [Lib.id(Lib.mate(mwpm, n)) + 1 for n in ns]
end

function maxweightedperfectmatching(g::Graph, weights::Dict{E,T}, alg::LEMONAlgorithm) where {E<:Edge,T<:Integer}
    return maxweightedperfectmatching(g, [weights[e] for e in Graphs.edges(g)], alg)
end

"""
    dijkstra_shortest_paths(g::AbstractGraph, srcs::Vector{<:Integer}, distmx::AbstractMatrix, alg::LEMONAlgorithm)

Compute shortest paths using LEMON Dijkstra backend.
"""
function Graphs.dijkstra_shortest_paths(
    g::AbstractGraph,
    srcs::Vector{<:Integer},
    distmx::AbstractMatrix{T},
    alg::LEMONAlgorithm
) where {T<:Integer}
    length(srcs) == 1 || throw(ArgumentError("LEMON Dijkstra wrapper currently only supports a single source node"))
    src = srcs[1]

    dg, ns, as = to_list_digraph(is_directed(g) ? g : DiGraph(g))
    
    maparc = Lib.ListDigraphArcMapInt(dg)
    for a in as
        u = Lib.id(Lib.source(dg, a)) + 1
        v = Lib.id(Lib.target(dg, a)) + 1
        Lib.set(maparc, a, distmx[u, v])
    end
    
    dijkstra = Lib.DijkstraListDigraphArcMapInt(dg, maparc)
    Lib.run(dijkstra, ns[src])
    
    nvg = nv(g)
    dists = fill(typemax(T), nvg)
    parents = zeros(Int, nvg)
    
    for i in 1:nvg
        if Lib.reached(dijkstra, ns[i])
            dists[i] = Lib.dist(dijkstra, ns[i])
            pred = Lib.predNode(dijkstra, ns[i])
            if Lib.id(pred) != -1
                parents[i] = Lib.id(pred) + 1
            end
        end
    end
    parents[src] = 0

    return Graphs.DijkstraState{T, Int}(
        parents, dists, 
        fill(Vector{Int}(), nvg), zeros(Float64, nvg), Vector{Int}()
    )
end

function Graphs.dijkstra_shortest_paths(
    g::AbstractGraph,
    src::Integer,
    distmx::AbstractMatrix{T},
    alg::LEMONAlgorithm
) where {T<:Integer}
    return Graphs.dijkstra_shortest_paths(g, [src], distmx, alg)
end

end  # module LEMONGraphs
