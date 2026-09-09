```@meta
CurrentModule = LEMONGraphs
```

# Adding another LEMON algorithm

LEMON is a large library and `LEMON_jll` currently exposes a slice of it. This
page is the recipe for widening that slice; it is deliberately concrete so that
each new algorithm is a mechanical change rather than a design exercise.

## 1. Expose the C++ symbol in `LEMON_jll`

The bindings come from the CxxWrap shim built in
[Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil/tree/master/L/LEMON).
Adding an algorithm means instantiating its template there and registering the
methods you need, then releasing a new `LEMON_jll`.

Everything the shim registers shows up under `LEMONGraphs.Lib`, so you can see
what is available with

```julia
using LEMONGraphs
filter(n -> !startswith(String(n), "_"), names(LEMONGraphs.Lib; all=true))
```

The C++ types are instantiated for a fixed value type. LEMONGraphs
names them [`LEMONGraphs.CxxInt`](@ref) (C++ `int`, used by `Dijkstra` and the
matching solver) and [`LEMONGraphs.CxxLong`](@ref) (C++ `long long`, used by the
flow solvers); use those aliases rather than hard-coding `Int32`/`Int64`.

## 2. Decide where the Julia-side method belongs

There are three cases.

**The function already exists in Graphs.jl.** Add a method to it in
`src/LEMONGraphs.jl` taking `::LEMONAlgorithm` as the last positional argument,
keeping the original signature and return type otherwise:

```julia
function Graphs.some_property(g::AbstractGraph, distmx::AbstractMatrix{T}, ::LEMONAlgorithm) where {T<:Integer}
    dg, ns, as = to_list_digraph(is_directed(g) ? g : DiGraph(g))
    # ... fill LEMON maps, run the solver, translate the result back ...
end
```

Always go through [`to_list_graph`](@ref LEMONGraphs.to_list_graph) /
[`to_list_digraph`](@ref LEMONGraphs.to_list_digraph): they convert an arbitrary
`AbstractGraph` and reuse an existing wrapper in `O(1)`. Remember that LEMON
node and arc ids are 0-based.

**The function exists in an ecosystem package** (GraphsMatching.jl,
GraphsOptim.jl, …). Put the method in the corresponding extension under `ext/`,
so that the dependency stays weak. Add the package to `[weakdeps]` and
`[extensions]` in `Project.toml` if it is not there yet.

**The function does not exist anywhere yet.** Then it should be *declared* in
Graphs.jl, as a function with a docstring and no methods, and LEMONGraphs adds
the method. That way the name is discoverable from Graphs.jl alone, and users
who call it without LEMONGraphs loaded are told what to install.

Graphs.jl keeps those declarations in `src/external_algorithms.jl`, together
with a registry and a `MethodError` hint, so its side of the change is two
entries:

```julia
# in Graphs.jl, src/external_algorithms.jl
"""
    min_mean_cycle(g, weights, alg)

Find the directed cycle of `g` minimising the mean weight of its arcs.

!!! note "Implementation package required"
    Graphs.jl only declares this function; it has no methods of its own.
"""
function min_mean_cycle end

@declare_external min_mean_cycle "LEMONGraphs.jl"
```

plus exporting the name. LEMONGraphs then adds the method:

```julia
Graphs.min_mean_cycle(g::AbstractGraph, weights, ::LEMONAlgorithm) = # ...
```

Calling it with neither package's method available now reports which package to
install, and once LEMONGraphs is loaded but does not cover the algorithm the
message says that instead. `Graphs.max_weight_perfect_matching` is declared this
way already; see the Graphs.jl page on
[externally implemented algorithms](https://juliagraphs.org/Graphs.jl/stable/algorithms/external/).

LEMONGraphs installs an error hint of its own for the mirror-image case: a call
that *does* pass `LEMONAlgorithm()` but hits no method, usually because a
weight or capacity was floating point, gets a note explaining that LEMON
algorithms are integer-valued.

## 3. Validate the inputs

LEMON will happily produce nonsense from inputs its templates cannot represent,
so check before calling into C++:

- integer-valued arguments, with an `ArgumentError` naming the argument;
- range: values must fit the instantiated C++ type;
- algorithm preconditions, e.g. Dijkstra's non-negative weights.

## 4. Test it against a reference

Every algorithm in the test suite is cross-checked against an independent
implementation, and that is the bar for new ones:

- `test/test_dijkstra.jl` compares against `Graphs.dijkstra_shortest_paths` on
  random graphs, field by field;
- `test/test_graphsoptim_ext.jl` compares against the JuMP/HiGHS solvers that
  GraphsOptim.jl uses by default;
- `test/test_mwpm.jl` compares against a brute-force matching and, where it is
  installed, against BlossomV.

Tests are `@testitem`s picked up by TestItemRunner; add a new file under
`test/` and it is collected automatically. Randomised tests use `StableRNGs` so
that failures reproduce.

## 5. Document it

Add a row to the table in [LEMON-backed algorithms](@ref) and a short example.
Public functions need a docstring that states the numeric restrictions and the
error behaviour.
