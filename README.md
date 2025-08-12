A very thin Julia wrapper around the C++ graphs library [`LEMON`](http://lemon.cs.elte.hu/).

Currently used mainly for its Min/Max Weight Perfect Matching algorithm,
wrapped into a more user-friendly API in GraphsMatching.jl,
but additional bindings can be added on request.

Public API surface (WIP):

- `LEMONGraphs.LEMONAlgorithm` — marker type to opt into LEMON-backed algorithm dispatch.
- `LEMONGraphs.maxweightedperfectmatching(g::Graphs.Graph, weights::AbstractVector{<:Integer})`
  and a `Dict{Graphs.Edge,Int}` variant.

Note: This package is evolving toward fuller Graphs.jl API coverage and LEMON-backed algorithm dispatch as discussed in [Graphs.jl issue #447](https://github.com/JuliaGraphs/Graphs.jl/issues/447).

Depends on `LEMON_jll`, which is compiled and packaged for all platforms supported by Julia.
