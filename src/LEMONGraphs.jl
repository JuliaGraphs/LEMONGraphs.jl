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

"""
    LEMONGraphs.CxxInt

Julia counterpart of the C++ `int` used by the LEMON maps that are instantiated
for `int` (`Dijkstra`, `MaxWeightedPerfectMatching`).
"""
const CxxInt = Cint

"""
    LEMONGraphs.CxxLong

Julia counterpart of the C++ `long long` used by the LEMON minimum cost flow
solvers, which are instantiated for 64-bit flow and cost values.
"""
const CxxLong = Clonglong

export LEMONGraph, LEMONDiGraph, LEMONAlgorithm, maxweightedperfectmatching

"""
    LEMONGraph{T,G,N,E} <: AbstractGraph{Int}

Wrapper around LEMON's `ListGraph` C++ type providing a Julia interface
conforming to the Graphs.jl `AbstractGraph` API.

The wrapper caches the endpoints of every LEMON edge and an adjacency list on
the Julia side, so that the Graphs.jl API can be served without crossing the
C++ boundary. Construction is `O(nv + ne)`; every subsequent query is as fast
as the equivalent `SimpleGraph` query.

`LEMONGraph(g::AbstractGraph)` wraps an existing graph and `LEMONGraph(n)`
builds an edgeless one on `n` vertices. `add_vertex!` and `add_edge!` grow the
graph; `rem_vertex!` and `rem_edge!` return `false`, because `LEMON_jll` does
not expose `ListGraph::erase`.
"""
struct LEMONGraph{T,G,N,E} <: AbstractGraph{Int}
    graph::G
    nodes::N
    edges::E
    edge_src::Vector{Int}
    edge_dst::Vector{Int}
    adjacency::Vector{Vector{Int}}

    function LEMONGraph(g, ns, es)
        us = Vector{Int}(undef, length(es))
        vs = Vector{Int}(undef, length(es))
        adjacency = [Int[] for _ in eachindex(ns)]
        for (i, e) in enumerate(es)
            # LEMON does not order the endpoints of an undirected edge, so they
            # are normalized to `src <= dst` the way `SimpleGraph` does
            u, v = minmax(Lib.id(Lib.u(g, e)) + 1, Lib.id(Lib.v(g, e)) + 1)
            us[i] = u
            vs[i] = v
            push!(adjacency[u], v)
            u == v || push!(adjacency[v], u)
        end
        foreach(sort!, adjacency)
        return new{eltype(ns),typeof(g),typeof(ns),typeof(es)}(g, ns, es, us, vs, adjacency)
    end
end

"""
    LEMONDiGraph{T,G,N,A} <: AbstractGraph{Int}

Wrapper around LEMON's `ListDigraph` C++ type providing a Julia interface
conforming to the Graphs.jl `AbstractGraph` API.

Like [`LEMONGraph`](@ref) it caches arc endpoints and in/out adjacency lists so
that Graphs.jl algorithms never pay a C++ call per neighbour lookup, and it
supports the same growing-only subset of the mutation API.
"""
struct LEMONDiGraph{T,G,N,A} <: AbstractGraph{Int}
    graph::G
    nodes::N
    arcs::A
    arc_src::Vector{Int}
    arc_dst::Vector{Int}
    fadj::Vector{Vector{Int}}
    badj::Vector{Vector{Int}}

    function LEMONDiGraph(g, ns, as)
        us = Vector{Int}(undef, length(as))
        vs = Vector{Int}(undef, length(as))
        fadj = [Int[] for _ in eachindex(ns)]
        badj = [Int[] for _ in eachindex(ns)]
        for (i, a) in enumerate(as)
            u = Lib.id(Lib.source(g, a)) + 1
            v = Lib.id(Lib.target(g, a)) + 1
            us[i] = u
            vs[i] = v
            push!(fadj[u], v)
            push!(badj[v], u)
        end
        foreach(sort!, fadj)
        foreach(sort!, badj)
        return new{eltype(ns),typeof(g),typeof(ns),typeof(as)}(
            g, ns, as, us, vs, fadj, badj
        )
    end
end

"""
    LEMONAlgorithm()

Marker type for dispatch to LEMON-backed algorithm implementations.

Pass it as the last positional argument to a Graphs.jl, GraphsMatching.jl or
GraphsOptim.jl function to request the LEMON implementation, e.g.
`dijkstra_shortest_paths(g, 1, distmx, LEMONAlgorithm())`.
"""
struct LEMONAlgorithm end

# Fast conversion helpers
"""
    to_list_graph(g) -> (ListGraph, Vector, Vector)

Fast conversion that caches nodes/edges for reuse in the [`LEMONGraph`](@ref)
wrapper. If `g` is already a `LEMONGraph`, its internal representation is
returned in `O(1)` without copying anything.
"""
function to_list_graph(g::Graph)
    lg = Lib.ListGraph()
    ns = [Lib.addNode(lg) for _ in Graphs.vertices(g)]
    es = [Lib.addEdge(lg, ns[Graphs.src(e)], ns[Graphs.dst(e)]) for e in Graphs.edges(g)]
    return (lg, ns, es)
end

function to_list_graph(g::AbstractGraph)
    is_directed(g) && throw(ArgumentError("LEMON matching currently only supports undirected graphs"))
    return to_list_graph(Graph(g))
end

function to_list_graph(g::LEMONGraph)
    return (g.graph, g.nodes, g.edges)  # O(1) reuse
end

"""
    to_list_digraph(g) -> (ListDigraph, Vector, Vector)

Fast conversion for directed graphs. If `g` is already a [`LEMONDiGraph`](@ref),
its internal representation is returned in `O(1)`.
"""
function to_list_digraph(g::DiGraph)
    dg = Lib.ListDigraph()
    ns = [Lib.addNode(dg) for _ in Graphs.vertices(g)]
    as = [Lib.addArc(dg, ns[Graphs.src(e)], ns[Graphs.dst(e)]) for e in Graphs.edges(g)]
    return (dg, ns, as)
end

function to_list_digraph(g::AbstractGraph)
    return to_list_digraph(DiGraph(g))
end

function to_list_digraph(g::LEMONDiGraph)
    return (g.graph, g.nodes, g.arcs)  # O(1) reuse
end

# Constructors
"""
    LEMONGraph(g::AbstractGraph) -> LEMONGraph

Convert an undirected Graphs.jl graph to a `LEMONGraph` wrapper.
"""
function LEMONGraph(g::Graph)
    lg, ns, es = to_list_graph(g)
    return LEMONGraph(lg, ns, es)
end

function LEMONGraph(g::AbstractGraph)
    lg, ns, es = to_list_graph(g)
    return LEMONGraph(lg, ns, es)
end

"""
    LEMONDiGraph(g::AbstractGraph) -> LEMONDiGraph

Convert a directed Graphs.jl graph to a `LEMONDiGraph` wrapper.
"""
function LEMONDiGraph(g::DiGraph)
    dg, ns, as = to_list_digraph(g)
    return LEMONDiGraph(dg, ns, as)
end

function LEMONDiGraph(g::AbstractGraph)
    dg, ns, as = to_list_digraph(g)
    return LEMONDiGraph(dg, ns, as)
end

# `LEMONGraph(n)` / `LEMONDiGraph(n)` build an edgeless wrapper on `n`
# vertices. The methods are defined on `Type{<:...}` rather than on the
# `UnionAll` alone because generic Graphs.jl algorithms such as
# `induced_subgraph` build their result with `typeof(g)(n)`, which names the
# concrete parameterization.
(::Type{L})(n::Integer) where {L<:LEMONGraph} = LEMONGraph(Graph(Int(n)))
(::Type{L})(n::Integer) where {L<:LEMONDiGraph} = LEMONDiGraph(DiGraph(Int(n)))

"""
    Graph(g::LEMONGraph) -> Graphs.SimpleGraph

Convert a `LEMONGraph` back to a `Graphs.SimpleGraph`.
"""
function Graph(g::LEMONGraph)
    h = Graph(Graphs.nv(g))
    for e in Graphs.edges(g)
        Graphs.add_edge!(h, Graphs.src(e), Graphs.dst(e))
    end
    return h
end

"""
    DiGraph(g::LEMONDiGraph) -> Graphs.SimpleDiGraph

Convert a `LEMONDiGraph` back to a `Graphs.SimpleDiGraph`.
"""
function DiGraph(g::LEMONDiGraph)
    h = DiGraph(Graphs.nv(g))
    for e in Graphs.edges(g)
        Graphs.add_edge!(h, Graphs.src(e), Graphs.dst(e))
    end
    return h
end

Base.convert(::Type{Graph}, g::LEMONGraph) = Graph(g)
Base.convert(::Type{DiGraph}, g::LEMONDiGraph) = DiGraph(g)

const LEMONAbstractGraph = Union{LEMONGraph,LEMONDiGraph}

# Lazy edge iterator shared by both wrapper types, mirroring `SimpleEdgeIter`
struct LEMONEdgeIter{G<:LEMONAbstractGraph}
    graph::G
end

Base.eltype(::Type{<:LEMONEdgeIter}) = Edge{Int}
Base.length(it::LEMONEdgeIter) = Graphs.ne(it.graph)
Base.size(it::LEMONEdgeIter) = (length(it),)
Base.IteratorSize(::Type{<:LEMONEdgeIter}) = Base.HasLength()
Base.IteratorEltype(::Type{<:LEMONEdgeIter}) = Base.HasEltype()

_endpoints(g::LEMONGraph, i::Integer) = (g.edge_src[i], g.edge_dst[i])
_endpoints(g::LEMONDiGraph, i::Integer) = (g.arc_src[i], g.arc_dst[i])

function Base.iterate(it::LEMONEdgeIter, i::Int=1)
    i > length(it) && return nothing
    u, v = _endpoints(it.graph, i)
    return (Edge(u, v), i + 1)
end

Base.in(e::Edge, it::LEMONEdgeIter) = Graphs.has_edge(it.graph, Graphs.src(e), Graphs.dst(e))
Base.show(io::IO, it::LEMONEdgeIter) = print(io, "$(length(it))-element LEMONEdgeIter")

# AbstractGraph API for LEMONGraph (undirected)
Graphs.nv(g::LEMONGraph) = length(g.nodes)
Graphs.ne(g::LEMONGraph) = length(g.edges)
Graphs.vertices(g::LEMONGraph) = Base.OneTo(length(g.nodes))
Graphs.edges(g::LEMONGraph) = LEMONEdgeIter(g)
Graphs.has_vertex(g::LEMONGraph, v::Integer) = 1 ≤ v ≤ length(g.nodes)
Graphs.is_directed(::Type{<:LEMONGraph}) = false
Graphs.is_directed(::LEMONGraph) = false
Graphs.edgetype(::LEMONGraph) = Edge{Int}
Graphs.edgetype(::Type{<:LEMONGraph}) = Edge{Int}

function Graphs.has_edge(g::LEMONGraph, u::Integer, v::Integer)
    (has_vertex(g, u) && has_vertex(g, v)) || return false
    return insorted(v, g.adjacency[u])
end

Graphs.inneighbors(g::LEMONGraph, v::Integer) = g.adjacency[v]
Graphs.outneighbors(g::LEMONGraph, v::Integer) = g.adjacency[v]

# AbstractGraph API for LEMONDiGraph (directed)
Graphs.nv(g::LEMONDiGraph) = length(g.nodes)
Graphs.ne(g::LEMONDiGraph) = length(g.arcs)
Graphs.vertices(g::LEMONDiGraph) = Base.OneTo(length(g.nodes))
Graphs.edges(g::LEMONDiGraph) = LEMONEdgeIter(g)
Graphs.has_vertex(g::LEMONDiGraph, v::Integer) = 1 ≤ v ≤ length(g.nodes)
Graphs.is_directed(::Type{<:LEMONDiGraph}) = true
Graphs.is_directed(::LEMONDiGraph) = true
Graphs.edgetype(::LEMONDiGraph) = Edge{Int}
Graphs.edgetype(::Type{<:LEMONDiGraph}) = Edge{Int}

function Graphs.has_edge(g::LEMONDiGraph, u::Integer, v::Integer)
    (has_vertex(g, u) && has_vertex(g, v)) || return false
    return insorted(v, g.fadj[u])
end

Graphs.inneighbors(g::LEMONDiGraph, v::Integer) = g.badj[v]
Graphs.outneighbors(g::LEMONDiGraph, v::Integer) = g.fadj[v]

# --- copying, and the growing half of the mutation API ---------------------
#
# LEMON's `ListGraph`/`ListDigraph` can grow, and the Julia-side caches grow
# with them. Removal would need `ListGraph::erase`, which LEMON_jll does not
# expose, so `rem_edge!`/`rem_vertex!` decline the request by returning
# `false`, which is what the Graphs.jl interface expects of a graph type that
# cannot perform the removal.

Base.copy(g::LEMONGraph) = LEMONGraph(Graph(g))
Base.copy(g::LEMONDiGraph) = LEMONDiGraph(DiGraph(g))

# `Graphs.zero(g::G) = zero(G)` covers the instance methods
Base.zero(::Type{<:LEMONGraph}) = LEMONGraph(0)
Base.zero(::Type{<:LEMONDiGraph}) = LEMONDiGraph(0)

function Graphs.add_vertex!(g::LEMONGraph)
    push!(g.nodes, Lib.addNode(g.graph))
    push!(g.adjacency, Int[])
    return true
end

function Graphs.add_vertex!(g::LEMONDiGraph)
    push!(g.nodes, Lib.addNode(g.graph))
    push!(g.fadj, Int[])
    push!(g.badj, Int[])
    return true
end

function Graphs.add_edge!(g::LEMONGraph, u::Integer, v::Integer)
    (has_vertex(g, u) && has_vertex(g, v)) || return false
    has_edge(g, u, v) && return false           # LEMON would add a parallel edge
    u, v = minmax(Int(u), Int(v))               # `src <= dst`, as in SimpleGraph
    push!(g.edges, Lib.addEdge(g.graph, g.nodes[u], g.nodes[v]))
    push!(g.edge_src, u)
    push!(g.edge_dst, v)
    insert!(g.adjacency[u], searchsortedfirst(g.adjacency[u], v), v)
    u == v || insert!(g.adjacency[v], searchsortedfirst(g.adjacency[v], u), u)
    return true
end

function Graphs.add_edge!(g::LEMONDiGraph, u::Integer, v::Integer)
    (has_vertex(g, u) && has_vertex(g, v)) || return false
    has_edge(g, u, v) && return false
    u, v = Int(u), Int(v)
    push!(g.arcs, Lib.addArc(g.graph, g.nodes[u], g.nodes[v]))
    push!(g.arc_src, u)
    push!(g.arc_dst, v)
    insert!(g.fadj[u], searchsortedfirst(g.fadj[u], v), v)
    insert!(g.badj[v], searchsortedfirst(g.badj[v], u), u)
    return true
end

Graphs.add_edge!(g::LEMONAbstractGraph, e::Edge) = Graphs.add_edge!(g, src(e), dst(e))

Graphs.rem_edge!(::LEMONAbstractGraph, ::Integer, ::Integer) = false
Graphs.rem_edge!(::LEMONAbstractGraph, ::Edge) = false
Graphs.rem_vertex!(::LEMONAbstractGraph, ::Integer) = false

"""
    reverse(g::LEMONDiGraph) -> LEMONDiGraph

Return the graph with every arc reversed. `Graphs.reverse` itself is only
defined for `AbstractSimpleGraph`, so this method exists to keep the wrapper
usable where the simple graphs are.
"""
Graphs.reverse(g::LEMONDiGraph) = LEMONDiGraph(Graphs.reverse(DiGraph(g)))

# LEMON-specific algorithm dispatches
"""
    maxweightedperfectmatching(g, weights[, ::LEMONAlgorithm])

Compute a maximum-weight perfect matching using LEMON's `MaxWeightedPerfectMatching`.

`weights` is either a vector of integer weights ordered like `edges(g)`, or a
`Dict{Edge,<:Integer}`. Returns `(matching_weight, mates)` where `mates[v]` is
the vertex matched to `v`.
"""
function maxweightedperfectmatching(g::AbstractGraph, weights::AbstractVector{<:Integer}, alg::LEMONAlgorithm)
    lg, ns, es = to_list_graph(g)
    length(weights) == length(es) || throw(DimensionMismatch("expected $(length(es)) edge weights, got $(length(weights))"))
    mapedge = Lib.ListGraphEdgeMap{CxxInt}(lg)
    for (e, w) in zip(es, weights)
        Lib.set(mapedge, e, _to_cxxint(w, "matching weight"))
    end
    mwpm = Lib.MaxWeightedPerfectMatchingListGraphInt(lg, mapedge)
    Lib.run(mwpm)
    return Lib.matchingWeight(mwpm), [Lib.id(Lib.mate(mwpm, n)) + 1 for n in ns]
end

function maxweightedperfectmatching(g::AbstractGraph, weights::Dict{E,T}, alg::LEMONAlgorithm) where {E<:Edge,T<:Integer}
    return maxweightedperfectmatching(g, [weights[e] for e in Graphs.edges(g)], alg)
end

function maxweightedperfectmatching(g::AbstractGraph, weights::AbstractVector{<:Integer})
    return maxweightedperfectmatching(g, weights, LEMONAlgorithm())
end

function maxweightedperfectmatching(g::AbstractGraph, weights::Dict{E,T}) where {E<:Edge,T<:Integer}
    return maxweightedperfectmatching(g, weights, LEMONAlgorithm())
end

function _to_cxxint(w::Integer, what::AbstractString)
    typemin(CxxInt) <= w <= typemax(CxxInt) ||
        throw(ArgumentError("LEMON stores each $what in a C++ `int`; $w does not fit in $(CxxInt)"))
    return CxxInt(w)
end

"""
    dijkstra_shortest_paths(g, srcs, distmx, ::LEMONAlgorithm; kwargs...)

Compute shortest paths with LEMON's `Dijkstra`.

`distmx` must hold non-negative integers that fit in a C++ `int`. The returned
`Graphs.DijkstraState` is fully populated: `parents`, `dists`, `pathcounts`,
and, when `allpaths=true`, `predecessors` are computed exactly as by the
native Graphs.jl implementation, so the result is interchangeable with it.

Multiple sources are supported; they are modelled by an auxiliary zero-cost
super-source, which means the `O(1)` reuse of a pre-built [`LEMONDiGraph`](@ref)
only applies to the single-source case.
"""
function Graphs.dijkstra_shortest_paths(
    g::AbstractGraph,
    srcs::Vector{<:Integer},
    distmx::AbstractMatrix{T},
    ::LEMONAlgorithm;
    allpaths::Bool=false,
    trackvertices::Bool=false,
    maxdist=typemax(T),
) where {T<:Integer}
    nvg = Int(nv(g))
    isempty(srcs) && throw(ArgumentError("at least one source vertex is required"))
    all(s -> 1 <= s <= nvg, srcs) || throw(ArgumentError("source vertex out of range"))

    # Arc endpoints are tracked on the Julia side rather than asked of LEMON one
    # arc at a time; they are needed again for the pathcount pass below.
    dg, ns, as, arc_src, arc_dst = if length(srcs) > 1
        _dijkstra_digraph(g, srcs)          # multi-source: add a super-source
    elseif g isa LEMONDiGraph
        (g.graph, g.nodes, g.arcs, g.arc_src, g.arc_dst)   # O(1) reuse
    else
        _dijkstra_digraph(g, nothing)
    end
    supersource = length(srcs) == 1 ? 0 : nvg + 1

    maparc = Lib.ListDigraphArcMap{CxxInt}(dg)
    arc_w = Vector{T}(undef, length(as))
    for i in eachindex(as)
        u, v = arc_src[i], arc_dst[i]
        w = (u == supersource) ? zero(T) : distmx[u, v]
        w >= zero(T) ||
            throw(ArgumentError("LEMON Dijkstra requires non-negative edge weights, got $w on edge ($u, $v)"))
        arc_w[i] = w
        Lib.set(maparc, as[i], _to_cxxint(w, "edge weight"))
    end

    dijkstra = Lib.DijkstraListDigraphArcMapInt(dg, maparc)
    Lib.run(dijkstra, ns[supersource == 0 ? Int(srcs[1]) : supersource])

    dists = fill(typemax(T), nvg)
    parents = zeros(Int, nvg)
    for i in 1:nvg
        Lib.reached(dijkstra, ns[i]) || continue
        d = T(Lib.dist(dijkstra, ns[i]))
        d <= maxdist || continue
        dists[i] = d
        pred = Lib.id(Lib.predNode(dijkstra, ns[i])) + 1
        parents[i] = (pred == supersource || pred == 0) ? 0 : pred
    end
    for s in srcs
        parents[s] = 0
    end

    preds, pathcounts = _dijkstra_pathcounts(
        nvg, srcs, dists, arc_src, arc_dst, arc_w, allpaths
    )

    closest_vertices = Int[]
    if trackvertices
        closest_vertices = collect(1:nvg)
        # stable sort so that unreachable vertices keep their vertex order at the
        # end of the list, as `Graphs.dijkstra_shortest_paths` does
        sort!(closest_vertices; alg=MergeSort, by=v -> (dists[v] == typemax(T), dists[v]))
    end

    return Graphs.DijkstraState{T,Int}(parents, dists, preds, pathcounts, closest_vertices)
end

function Graphs.dijkstra_shortest_paths(
    g::AbstractGraph,
    src::Integer,
    distmx::AbstractMatrix{T},
    alg::LEMONAlgorithm;
    allpaths::Bool=false,
    trackvertices::Bool=false,
    maxdist=typemax(T),
) where {T<:Integer}
    return Graphs.dijkstra_shortest_paths(
        g, [Int(src)], distmx, alg; allpaths, trackvertices, maxdist
    )
end

function Graphs.dijkstra_shortest_paths(
    g::AbstractGraph, srcs::Union{Integer,Vector{<:Integer}}, alg::LEMONAlgorithm; kwargs...
)
    return Graphs.dijkstra_shortest_paths(g, srcs, Graphs.weights(g), alg; kwargs...)
end

function Graphs.dijkstra_shortest_paths(
    ::AbstractGraph,
    ::Union{Integer,Vector{<:Integer}},
    ::AbstractMatrix{T},
    ::LEMONAlgorithm;
    kwargs...,
) where {T<:Real}
    throw(ArgumentError(
        "LEMON Dijkstra only supports integer edge weights, got a distance matrix of " *
        "element type $T. Convert the weights to integers or drop `LEMONAlgorithm()` " *
        "to use the native Graphs.jl implementation."
    ))
end

"""
    _dijkstra_digraph(g, srcs)

Build the LEMON `ListDigraph` that Dijkstra runs on, returning it together with
its nodes, its arcs and the arc endpoints. The endpoints are derived from `g`
on the Julia side, so no per-arc `source`/`target` call crosses into C++.

When `srcs` is a collection rather than `nothing`, an extra node `nv(g) + 1` is
added with a zero-cost arc into every vertex of `srcs`; that reduces
multi-source Dijkstra to the single-source case LEMON exposes.
"""
function _dijkstra_digraph(g::AbstractGraph, srcs)
    nvg = Int(nv(g))
    endpoints = Tuple{Int,Int}[]
    if srcs !== nothing
        for s in srcs
            push!(endpoints, (nvg + 1, Int(s)))
        end
    end
    for e in Graphs.edges(g)
        u, v = Int(Graphs.src(e)), Int(Graphs.dst(e))
        push!(endpoints, (u, v))
        is_directed(g) || push!(endpoints, (v, u))
    end

    dg = Lib.ListDigraph()
    ns = [Lib.addNode(dg) for _ in 1:(srcs === nothing ? nvg : nvg + 1)]
    as = [Lib.addArc(dg, ns[u], ns[v]) for (u, v) in endpoints]
    return (dg, ns, as, first.(endpoints), last.(endpoints))
end

"""
    _dijkstra_pathcounts(nvg, srcs, dists, arc_src, arc_dst, arc_w, allpaths)

Recover the shortest-path DAG from the distance labels produced by LEMON, and
from it the predecessor lists and the number of shortest paths per vertex.

Zero-weight edges make the "DAG" of tight arcs contain arcs between vertices at
the same distance, so vertices are relaxed distance group by distance group,
with a topological (Kahn) pass inside each group. A zero-weight cycle on a
shortest path means there are infinitely many shortest paths; the affected path
counts are reported as `Inf`.
"""
function _dijkstra_pathcounts(
    nvg::Int, srcs, dists::Vector{T}, arc_src, arc_dst, arc_w, allpaths::Bool
) where {T<:Integer}
    preds = [Int[] for _ in 1:nvg]
    pathcounts = zeros(Float64, nvg)

    inpreds = [Int[] for _ in 1:nvg]
    tight_succ = [Int[] for _ in 1:nvg]   # tight arcs between equidistant vertices
    indeg = zeros(Int, nvg)
    for i in eachindex(arc_src)
        u, v = arc_src[i], arc_dst[i]
        (u > nvg || v > nvg) && continue          # arcs out of the super-source
        (dists[u] == typemax(T) || dists[v] == typemax(T)) && continue
        v in srcs && continue
        dists[u] + arc_w[i] == dists[v] || continue
        push!(inpreds[v], u)
        if dists[u] == dists[v]
            push!(tight_succ[u], v)
            indeg[v] += 1
        end
    end
    allpaths && (preds = inpreds)

    for s in srcs
        pathcounts[s] = 1.0
    end

    order = [v for v in 1:nvg if dists[v] != typemax(T)]
    sort!(order; by=v -> dists[v])

    group_start = 1
    while group_start <= length(order)
        group_stop = group_start
        while group_stop < length(order) && dists[order[group_stop + 1]] == dists[order[group_start]]
            group_stop += 1
        end
        group = view(order, group_start:group_stop)

        # contributions from strictly closer vertices, already final
        for v in group
            v in srcs && continue
            pathcounts[v] = sum(
                u -> dists[u] == dists[v] ? 0.0 : pathcounts[u], inpreds[v]; init=0.0
            )
        end

        queue = [v for v in group if indeg[v] == 0]
        settled = 0
        while !isempty(queue)
            u = pop!(queue)
            settled += 1
            for v in tight_succ[u]
                pathcounts[v] += pathcounts[u]
                indeg[v] -= 1
                indeg[v] == 0 && push!(queue, v)
            end
        end
        # Kahn leaves exactly the vertices lying on, or downstream of, a
        # zero-weight cycle unsettled; those are reachable by infinitely many
        # shortest paths. Later groups inherit the `Inf` through the sum above.
        if settled < length(group)
            for v in group
                indeg[v] > 0 && (pathcounts[v] = Inf)
            end
        end

        group_start = group_stop + 1
    end

    return preds, pathcounts
end

function __init__()
    Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
        LEMONAlgorithm in argtypes || return nothing
        print(
            io,
            "\n\n`LEMONGraphs` does not provide a LEMON-backed method for `$(exc.f)` with " *
            "these argument types. LEMON algorithms are integer-valued: make sure weights, " *
            "costs and capacities are `Integer`s. See the LEMONGraphs.jl documentation for " *
            "the list of supported `LEMONAlgorithm()` dispatches.",
        )
        return nothing
    end
end

end  # module LEMONGraphs
