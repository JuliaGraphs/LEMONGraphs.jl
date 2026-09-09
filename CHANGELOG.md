# News

## unreleased

- Require `LEMON_jll` 1.3.6 and move to its parameterized CxxWrap bindings
  (`ListGraphEdgeMap{T}`, `ListDigraphArcMap{T}`, `NetworkSimplex{V,C}`, ...),
  replacing the `…Int`-suffixed names of earlier releases
- `LEMONGraph`/`LEMONDiGraph` now cache edge endpoints and adjacency lists, so
  `has_edge`, `inneighbors` and `outneighbors` are O(1)-ish instead of scanning
  every edge through the C++ boundary
- `edges` returns a lazy edge iterator, and `edgetype` returns the concrete
  `Edge{Int}`; undirected edges are normalized to `src <= dst`, as in
  `SimpleGraph`
- Complete the `AbstractGraph` interface: `LEMONGraph(n)`/`LEMONDiGraph(n)`,
  `zero`, `copy`, `add_vertex!`, `add_edge!` and `reverse`, so that generic
  algorithms such as `induced_subgraph` and `egonet` work on the wrappers.
  `rem_edge!`/`rem_vertex!` return `false` because `LEMON_jll` exposes no
  `ListGraph::erase`. Both the mandatory and the optional `mutation`
  components of `AbstractGraphInterface` now pass
- Add `Graph(::LEMONGraph)` / `DiGraph(::LEMONDiGraph)` conversions back to
  Graphs.jl, plus the matching `convert` methods
- LEMON `dijkstra_shortest_paths` is now a drop-in replacement for the
  Graphs.jl one: multiple sources, `allpaths`, `trackvertices` and `maxdist`
  are supported, and `pathcounts`/`predecessors` are computed exactly
  (including `Inf` counts behind zero-weight cycles)
- Validate Dijkstra inputs: non-negative integer weights that fit a C++ `int`
- Implement `GraphsOptim.min_cost_flow` on LEMON's minimum cost flow solvers,
  selectable with `solver = :network_simplex` (default), `:capacity_scaling`,
  `:cost_scaling` or `:cycle_canceling`; infinite upper capacities are accepted
- Implement `GraphsOptim.min_cost_assignment` on top of the same solvers,
  replacing the previous stub
- Register an error hint so that unsupported `LEMONAlgorithm()` calls explain
  the integer-only restriction instead of raising a bare `MethodError`
- Raise the `GraphsMatching` compat bound to 0.2.1, which removes a method
  ambiguity with its `cutoff` argument
- Run the GraphsInterfaceChecker suite as a `@testitem` (it was previously
  never collected), and cross-check Dijkstra, minimum cost flow and assignment
  against Graphs.jl and the JuMP-based GraphsOptim solvers
- Expand the documentation: graph types, algorithm dispatch, and a guide for
  adding further LEMON algorithms
- Track arc endpoints on the Julia side in the Dijkstra wrapper instead of
  asking LEMON for them arc by arc; this makes it ~2x faster from a
  `SimpleGraph` and ~3x faster from a pre-built `LEMONDiGraph`
- Benchmark conversions, the `AbstractGraph` API and Dijkstra, not just
  maximum weight perfect matching
- Add the `LEMONAlgorithm` marker type, which picks the LEMON implementation
  when passed as the last positional argument
- Add a GraphsMatching.jl extension implementing
  `minimum_weight_perfect_matching` on LEMON, for integer and floating point
  weights
- Add a GraphsOptim.jl extension implementing `shortest_path` on LEMON's
  Dijkstra

## v0.1.2 - 2026-09-09

- Fix maximum-weight perfect matching broken by a change to the parametric map types in LEMON_jll 1.3.6.

## v0.1.1 - 2025-10-10

- Recompile LEMON_jll dependencies for newer versions of Julia

## v0.1.0 - 2025-07-03

- First release.
- Simple wrapper/converter between Graphs.jl and LEMONGraphs.jl.
- Wrapper for the MWPM algorithm.
