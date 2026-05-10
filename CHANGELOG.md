# News

## v0.1.2 - 2026-05-01

- Add `LEMONGraph` and `LEMONDiGraph` wrapper types with full `AbstractGraph` API support
- Implement fast O(1) reuse of converted graphs via `to_list_graph()` and `to_list_digraph()`
- Add `LEMONAlgorithm` marker type for dispatch to LEMON-backed implementations
- Expose new Yggdrasil CxxWrap bindings: Dijkstra, graph accessors (u, v, source, target), ArcMap
- Add extension for GraphsMatching.jl: `minimum_weight_perfect_matching` dispatch to LEMON
- Add extension for GraphsOptim.jl: LEMON-backed `shortest_path` via Dijkstra
- Add GraphsOptim LEMONAlgorithm stubs for min_cost_assignment, min_vertex_cover, maximum_weight_clique, and min_cost_flow
- Update `LEMON_jll` compat to 1.3.4+ for Julia 1.14 support

## v0.1.1 - 2025-10-10

- Recompile LEMON_jll dependencies for newer versions of Julia

## v0.1.0 - 2025-07-03

- First release.
- Simple wrapper/converter between Graphs.jl and LEMONGraphs.jl.
- Wrapper for the MWPM algorithm.

