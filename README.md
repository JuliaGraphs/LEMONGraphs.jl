# LEMONGraphs.jl

A Julia wrapper for the C++ graph algorithms library [LEMON](http://lemon.cs.elte.hu/).

LEMONGraphs provides:
- **Fast LEMON graph types** (`LEMONGraph`, `LEMONDiGraph`) implementing the `AbstractGraph` interface
- **Efficient conversions** between Graphs.jl and LEMON C++ structures with O(1) reuse
- **LEMON algorithm dispatch** for matching, shortest paths, and other algorithms
- **GraphsInterfaceChecker.jl integration** for API compliance

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

# Use LEMON-backed algorithms
weights = [1, 2, 3, 4]
w, matching = maxweightedperfectmatching(g, weights, LEMONAlgorithm())
```

## Features

### LEMONGraph and LEMONDiGraph Types

Wrapper types that implement the full Graphs.jl `AbstractGraph` API:

```julia
# Undirected
g = complete_graph(4)
lg = LEMONGraph(g)

# Directed  
dg = SimpleDiGraph(4)
ldg = LEMONDiGraph(dg)

# All standard Graph.jl methods work:
nv(lg), ne(lg), vertices(lg), edges(lg)
has_vertex(lg, 1), has_edge(lg, 1, 2)
inneighbors(lg, 1), outneighbors(lg, 1)
```

### Fast Graph Reuse

O(1) conversion reuse when a graph is already converted:

```julia
g = complete_graph(100)
lg1 = LEMONGraph(g)
lg2 = LEMONGraph(g)  # Reuses internal LEMON graph (nearly free)
```

### Maximum-Weight Perfect Matching

```julia
using Graphs, LEMONGraphs

g = complete_graph(6)
weights = Dict(Edge(i,j) => rand(-100:100) for (i,j) in edges(g))
w, spouse_map = maxweightedperfectmatching(g, weights, LEMONAlgorithm())
```

### Extension Support

LEMONGraphs provides extensions for ecosystem packages:

- **GraphsMatching.jl**: Dispatch `minimum_weight_perfect_matching` to LEMON for efficient maximum-weight perfect matching (when GraphsMatching is installed)
- **GraphsOptim.jl**: Dispatch `shortest_path` to LEMON Dijkstra by passing `LEMONAlgorithm()` (integer costs only). Additional LEMONAlgorithm stubs are provided for `min_cost_assignment`, `min_vertex_cover`, `maximum_weight_clique`, and `min_cost_flow`.

## Testing

```julia
using Pkg
Pkg.test("LEMONGraphs")
```

## References

- LEMON documentation: http://lemon.cs.elte.hu/
- Graphs.jl: https://github.com/JuliaGraphs/Graphs.jl
- Issue #447: [A reliable idiomatic wrapper for the C++ library LEMON](https://github.com/JuliaGraphs/Graphs.jl/issues/447)
