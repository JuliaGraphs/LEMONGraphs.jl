```@meta
CurrentModule = LEMONGraphs
```

# LEMON-backed algorithms

Every LEMON implementation is reached by passing [`LEMONAlgorithm`](@ref) as the
last positional argument of the function you would call anyway. The signature,
the keyword arguments and the return type are the ones of the original
function, so switching backends is a one-token change:

```julia
dijkstra_shortest_paths(g, 1, distmx)                    # Graphs.jl
dijkstra_shortest_paths(g, 1, distmx, LEMONAlgorithm())  # LEMON
```

## What is available

| Function | Owner | LEMON backend | Notes |
|:--|:--|:--|:--|
| `dijkstra_shortest_paths` | Graphs.jl | `Dijkstra` | integer weights |
| `maxweightedperfectmatching` | LEMONGraphs | `MaxWeightedPerfectMatching` | integer weights |
| `minimum_weight_perfect_matching` | GraphsMatching.jl | `MaxWeightedPerfectMatching` | integer or float weights |
| `shortest_path` | GraphsOptim.jl | `Dijkstra` | integer costs |
| `min_cost_flow` | GraphsOptim.jl | `NetworkSimplex` and friends | integer costs/capacities |
| `min_cost_assignment` | GraphsOptim.jl | `NetworkSimplex` | square integer cost matrix |
| `min_vertex_cover` | GraphsOptim.jl | none | throws; LEMON has no solver |
| `maximum_weight_clique` | GraphsOptim.jl | none | throws; LEMON has no solver |

The GraphsMatching.jl and GraphsOptim.jl methods live in package extensions, so
they appear only once you have loaded the corresponding package.

!!! note "LEMON is integer-valued"
    The LEMON templates exposed by `LEMON_jll` are instantiated for C++ `int`
    (Dijkstra, matching) and `long long` (the flow solvers). Nothing is ever
    silently rounded: a value that is not an exact integer raises an
    `ArgumentError` naming the offending argument.

    Dijkstra requires a distance matrix with an `Integer` element type. The
    flow and assignment solvers check values rather than element types, so an
    integral floating point matrix is accepted, which mixing `Inf` with finite
    capacities forces. `minimum_weight_perfect_matching` is the exception:
    it follows GraphsMatching.jl in rescaling float weights onto `Int32`.

## Shortest paths

```julia
using Graphs, LEMONGraphs

g = path_digraph(5)
distmx = [abs(i - j) for i in 1:5, j in 1:5]

state = dijkstra_shortest_paths(g, 1, distmx, LEMONAlgorithm())
state.dists, state.parents, state.pathcounts
```

The returned `Graphs.DijkstraState` is fully populated and interchangeable with
the one Graphs.jl produces: `dists`, `parents`, `pathcounts`, `closest_vertices`
(with `trackvertices=true`) and `predecessors` (with `allpaths=true`) all carry
the same meaning. LEMON only reports distances and a single predecessor per
vertex, so LEMONGraphs recovers the shortest-path DAG from the distance labels
and counts the paths itself.

Multiple sources are supported, modelled with an auxiliary zero-cost
super-source, as are `maxdist` and the two keyword flags:

```julia
dijkstra_shortest_paths(g, [1, 3], distmx, LEMONAlgorithm(); allpaths=true, maxdist=4)
```

Weights must be non-negative (Dijkstra's requirement) and must fit in a C++
`int`; both are checked.

!!! tip "Reuse the wrapper"
    Handing this method a `SimpleGraph` means building the C++ digraph and
    filling an arc map on every call, and that dominates the runtime on small
    and medium graphs, where the pure-Julia `Graphs.dijkstra_shortest_paths` is
    faster. Passing a [`LEMONDiGraph`](@ref) you already hold skips the
    construction entirely and is roughly three times faster than converting
    each time (see `benchmark/benchmarks.jl`). Multi-source queries always
    build a fresh graph, because of the auxiliary super-source.

Zero-weight edges are allowed. If a zero-weight cycle lies on a shortest path
there are infinitely many shortest walks to the vertices behind it, and the
corresponding `pathcounts` entries are `Inf`.

## Matching

```julia
using Graphs, LEMONGraphs

g = complete_graph(6)
weights = rand(-100:100, ne(g))
total, mates = maxweightedperfectmatching(g, weights, LEMONAlgorithm())
```

`weights` is either a vector ordered like `edges(g)` or a `Dict{Edge,<:Integer}`.
`mates[v]` is the vertex matched to `v`.

With GraphsMatching.jl loaded you can also go through its API:

```julia
using GraphsMatching
w = Dict(Edge(1, 2) => 10, Edge(1, 3) => 1, #= ... =#)
minimum_weight_perfect_matching(g, w, LEMONAlgorithm())
```

GraphsMatching.jl ≥ 0.2.1 already routes its default
`minimum_weight_perfect_matching` to LEMON through its own
`LEMONMWPMAlgorithm()`; the `LEMONAlgorithm()` spelling above exists so that
every LEMON dispatch in the ecosystem looks the same.

## Flows and assignment

```julia
using Graphs, GraphsOptim, LEMONGraphs

g = path_digraph(3)
demand = [-1, 0, 1]          # negative at sources, positive at sinks
cost = [0 1 0; 0 0 1; 0 0 0]

flow = min_cost_flow(g, demand, cost, LEMONAlgorithm())
```

Minimum and maximum capacities can be given as the fourth and fifth positional
arguments, matching `GraphsOptim.min_cost_flow`. Entries of the maximum
capacity matrix may be `Inf` for an uncapacitated arc. The result is a sparse
matrix of flows over all arcs.

LEMON ships four minimum cost flow solvers, all reachable through the `solver`
keyword. They return equally optimal flows and differ only in running time:

```julia
min_cost_flow(g, demand, cost, LEMONAlgorithm(); solver=:cost_scaling)
```

`:network_simplex` (default), `:capacity_scaling`, `:cost_scaling` and
`:cycle_canceling` are accepted. Only `:network_simplex` handles negative costs
on arcs whose upper capacity is infinite; the other three report such a problem
as unbounded, so give those arcs a finite capacity if you need them.

The square linear assignment problem is solved on top of the same machinery:

```julia
cost = [4 1 3; 2 0 5; 3 2 2]
assignment = min_cost_assignment(cost, LEMONAlgorithm())   # 0/1 Matrix{Int}
```

## When a dispatch does not exist

`min_vertex_cover` and `maximum_weight_clique` accept `LEMONAlgorithm()` and
throw an `ArgumentError` pointing at the default GraphsOptim backend, rather
than failing with a bare `MethodError`. For anything else, LEMONGraphs installs
an error hint, so an unsupported call still explains itself:

```julia-repl
julia> dijkstra_shortest_paths(g, 1, rand(5, 5), LEMONAlgorithm())
ERROR: ArgumentError: LEMON Dijkstra only supports integer edge weights, ...
```
