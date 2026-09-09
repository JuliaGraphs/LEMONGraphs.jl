```@meta
CurrentModule = LEMONGraphs
```

# LEMONGraphs.jl

LEMONGraphs.jl wraps the C++ graph library
[LEMON](https://lemon.cs.elte.hu/) for use from Graphs.jl:

- [`LEMONGraph`](@ref) and [`LEMONDiGraph`](@ref) hold LEMON's `ListGraph` and
  `ListDigraph` and implement the Graphs.jl `AbstractGraph` API, so Graphs.jl
  algorithms that stay within the interface run on them;
- conversions in both directions, reusing the C++ handles in `O(1)` when the
  graph is already a wrapper;
- LEMON implementations of some Graphs.jl, GraphsMatching.jl and GraphsOptim.jl
  functions, selected by passing [`LEMONAlgorithm`](@ref) as the last
  positional argument.

## Installation

```julia
using Pkg
Pkg.add("LEMONGraphs")
```

The C++ library itself comes from `LEMON_jll`, which is precompiled for every
platform Julia supports; there is nothing to build.

## Quick start

```julia
using Graphs, LEMONGraphs

g = path_graph(5)
lg = LEMONGraph(g)          # `g` rebuilt as a LEMON ListGraph

nv(lg), ne(lg)              # (5, 4)
outneighbors(lg, 2)         # [1, 3]
Graph(lg) == g              # true

# LEMON's Dijkstra instead of the Graphs.jl one
distmx = [abs(i - j) for i in 1:5, j in 1:5]
state = dijkstra_shortest_paths(g, 1, distmx, LEMONAlgorithm())
state.dists
```

## Contents

```@contents
Pages = ["graphs.md", "algorithms.md", "extending.md", "api.md"]
Depth = 2
```
