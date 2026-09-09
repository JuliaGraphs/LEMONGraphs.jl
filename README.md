# LEMONGraphs.jl

A Julia wrapper for the C++ graph algorithms library [LEMON](http://lemon.cs.elte.hu/).

It provides `LEMONGraph` and `LEMONDiGraph`, which implement the Graphs.jl
`AbstractGraph` interface on top of LEMON's `ListGraph` and `ListDigraph`,
conversions in both directions with `O(1)` reuse, and LEMON implementations of
matching, shortest paths, minimum cost flow and assignment. The interface is
checked in the test suite with GraphsInterfaceChecker.jl.

Full documentation: <https://juliagraphs.org/LEMONGraphs.jl/>.

## Installation

```julia
using Pkg
Pkg.add("LEMONGraphs")
```

Depends on `LEMON_jll`, which is compiled and packaged for all platforms supported by Julia.

## Quick Start

```julia
using Graphs, LEMONGraphs

# Convert a Graphs.jl graph to LEMON
g = path_graph(5)
lg = LEMONGraph(g)

# Use LEMON graph like any AbstractGraph
@assert nv(lg) == 5
@assert ne(lg) == 4
@assert Graph(lg) == g

# Use LEMON-backed algorithms by passing LEMONAlgorithm() last
distmx = [abs(i - j) for i in 1:5, j in 1:5]
state = dijkstra_shortest_paths(g, 1, distmx, LEMONAlgorithm())
@assert state.dists == [0, 1, 2, 3, 4]
```

## Usage

### Graph types

```julia
# Undirected
g = complete_graph(4)
lg = LEMONGraph(g)

# Directed
dg = SimpleDiGraph(4)
ldg = LEMONDiGraph(dg)

# All standard Graphs.jl methods work:
nv(lg), ne(lg), vertices(lg), edges(lg)
has_vertex(lg, 1), has_edge(lg, 1, 2)
inneighbors(lg, 1), outneighbors(lg, 1)

# ... and so do generic Graphs.jl algorithms:
connected_components(lg), kruskal_mst(lg), is_strongly_connected(ldg)
```

Adjacency is cached on the Julia side when the wrapper is built, so neighbour
and edge queries are as fast as on a `SimpleGraph` and never cross into C++.
Every component of the `AbstractGraph` interface, the optional `mutation` one
included, is checked in the test suite with GraphsInterfaceChecker.jl.

`add_vertex!` and `add_edge!` grow the underlying LEMON structure. Removal is
the one gap: `LEMON_jll` does not expose `ListGraph::erase`, so `rem_edge!` and
`rem_vertex!` decline by returning `false`.

### Reusing a wrapper

A LEMON-backed algorithm handed an existing `LEMONGraph` or `LEMONDiGraph`
reuses it in `O(1)` rather than converting again:

```julia
g = complete_graph(100)
lg1 = LEMONGraph(g)
w, mate = maxweightedperfectmatching(lg1, ones(Int, ne(lg1)))  # no reconversion
```

### Maximum weight perfect matching

```julia
using Graphs, LEMONGraphs

g = complete_graph(6)
weights = Dict(e => rand(-100:100) for e in edges(g))
w, spouse_map = maxweightedperfectmatching(g, weights, LEMONAlgorithm())
```

### Package extensions

- GraphsMatching.jl: `minimum_weight_perfect_matching(g, weights, LEMONAlgorithm())`, for
  integer or floating point weight dictionaries.
- GraphsOptim.jl: `shortest_path` (LEMON Dijkstra), `min_cost_flow` (LEMON
  `NetworkSimplex`, with `:capacity_scaling`, `:cost_scaling` and
  `:cycle_canceling` also available through the `solver` keyword), and
  `min_cost_assignment` (square integer cost matrices). `min_vertex_cover` and
  `maximum_weight_clique` accept `LEMONAlgorithm()` only to report that LEMON
  has no such solver.

All LEMON solvers exposed by `LEMON_jll` are integer-valued, so weights, costs
and capacities must be `Integer`s; a floating point input raises an
`ArgumentError` instead of being silently rounded.

## Testing

```julia
using Pkg
Pkg.test("LEMONGraphs")
```

## References

- LEMON documentation: http://lemon.cs.elte.hu/
- Graphs.jl: https://github.com/JuliaGraphs/Graphs.jl
- Issue #447: [A reliable idiomatic wrapper for the C++ library LEMON](https://github.com/JuliaGraphs/Graphs.jl/issues/447)
