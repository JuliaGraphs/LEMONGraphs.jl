```@meta
CurrentModule = LEMONGraphs
```

# Graph types and conversions

## The wrapper types

[`LEMONGraph`](@ref) wraps LEMON's `ListGraph` and [`LEMONDiGraph`](@ref) wraps
`ListDigraph`. Both are `AbstractGraph{Int}` subtypes with 1-based vertex
numbering, matching Graphs.jl (LEMON itself uses 0-based node ids; the wrappers
translate).

```julia
using Graphs, LEMONGraphs

lg = LEMONGraph(wheel_graph(6))
ldg = LEMONDiGraph(path_digraph(5))
```

Alongside the C++ handles, each wrapper stores the endpoints of every
edge/arc and an adjacency list on the Julia side. Construction costs
`O(nv + ne)`; afterwards `has_edge`, `inneighbors` and `outneighbors` are as
fast as on a `SimpleGraph`, and no C++ call happens per query. This matters:
Graphs.jl algorithms call `outneighbors` in their inner loops.

`edges(g)` returns a lazy iterator (`LEMONGraphs.LEMONEdgeIter`), the same
design `SimpleGraph` uses, so iterating the edges does not materialise a
vector.

## Interface compliance

Both types implement every component of the Graphs.jl `AbstractGraph`
interface, mandatory and optional, which the test suite checks with
[GraphsInterfaceChecker.jl](https://github.com/JuliaGraphs/GraphsInterfaceChecker.jl):

```julia
using GraphsInterfaceChecker, Interfaces
Interfaces.test(AbstractGraphInterface, LEMONGraph)   # true
Interfaces.test(AbstractGraphInterface, LEMONDiGraph) # true
```

With the interface complete, generic Graphs.jl algorithms run on the wrappers:

```julia
connected_components(lg)
degree(lg)
kruskal_mst(lg)
induced_subgraph(lg, [1, 2, 3])
is_strongly_connected(ldg)
```

The two exceptions are `complement` and `transitiveclosure`, which Graphs.jl
defines only for `SimpleGraph`/`SimpleDiGraph` rather than for `AbstractGraph`.
No wrapper can satisfy them; convert with `Graph(lg)` first.

## Growing a graph

`add_vertex!` and `add_edge!` grow the underlying LEMON structure and the Julia
caches together, with the same semantics as `SimpleGraph`. In particular
`add_edge!` returns `false` for an edge that is already present, instead of
letting LEMON create a parallel one.

```julia
lg = LEMONGraph(4)      # four vertices, no edges
add_edge!(lg, 1, 2)     # true
add_edge!(lg, 2, 1)     # false, it is already there
add_vertex!(lg)         # true
```

!!! warning "Removal is not available"
    `rem_edge!` and `rem_vertex!` always return `false`. LEMON's `ListGraph`
    does support erasure, but `LEMON_jll` does not currently expose
    `ListGraph::erase`, and the Graphs.jl interface expects a graph type that
    cannot perform a removal to decline it rather than to throw. If you need
    removal, convert to a `SimpleGraph`, edit it, and wrap the result.

`copy` produces an independent graph, backed by its own C++ structure, and
`zero` an empty one of the same type.

## Converting back and forth

| From | To | How |
|:--|:--|:--|
| `AbstractGraph` | `LEMONGraph` | `LEMONGraph(g)` |
| `AbstractGraph` | `LEMONDiGraph` | `LEMONDiGraph(g)` |
| `LEMONGraph` | `SimpleGraph` | `Graph(lg)` or `convert(Graph, lg)` |
| `LEMONDiGraph` | `SimpleDiGraph` | `DiGraph(ldg)` or `convert(DiGraph, ldg)` |

Undirected graphs handed to `LEMONDiGraph` are expanded into arcs in both
directions, exactly as `SimpleDiGraph(g)` does.

## Avoiding repeated conversions

The LEMON-backed algorithms convert their graph argument with
[`LEMONGraphs.to_list_graph`](@ref) / [`LEMONGraphs.to_list_digraph`](@ref).
Both return the internal C++ handles unchanged, in `O(1)` and with no copying,
when they are given a graph that is already a wrapper:

```julia
lg = LEMONGraph(complete_graph(500))

# the conversion happens once, not once per call
for _ in 1:100
    maxweightedperfectmatching(lg, ones(Int, ne(lg)))
end
```

So if you call several LEMON algorithms on the same graph, wrap it once and
pass the wrapper around.
