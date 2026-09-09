using BenchmarkTools
using Graphs
using LEMONGraphs
using LEMONGraphs: maxweightedperfectmatching

const SUITE = BenchmarkGroup()

# ---------------------------------------------------------------------------
# Maximum weight perfect matching (the original benchmark, kept unchanged so
# that historical comparisons stay meaningful)
# ---------------------------------------------------------------------------

function mwpm_benchmark_input()
    g = Graph(6)
    add_edge!(g, 1, 2)
    add_edge!(g, 1, 3)
    add_edge!(g, 2, 4)
    add_edge!(g, 3, 4)
    add_edge!(g, 3, 5)
    add_edge!(g, 4, 6)
    add_edge!(g, 5, 6)
    weights = [10, 4, 8, 7, 6, 9, 5]
    return g, weights
end

const MWPM_GRAPH, MWPM_WEIGHTS = mwpm_benchmark_input()

SUITE["maxweightedperfectmatching"] = @benchmarkable maxweightedperfectmatching(
    $MWPM_GRAPH,
    $MWPM_WEIGHTS,
)

# ---------------------------------------------------------------------------
# Conversions between Graphs.jl and the LEMON C++ structures
# ---------------------------------------------------------------------------

const CONV_GRAPH = complete_graph(100)
const CONV_DIGRAPH = complete_digraph(70)
const CONV_LEMON = LEMONGraph(CONV_GRAPH)
const CONV_LEMON_DI = LEMONDiGraph(CONV_DIGRAPH)

SUITE["conversion"] = BenchmarkGroup()
SUITE["conversion"]["to LEMONGraph"] = @benchmarkable LEMONGraph($CONV_GRAPH)
SUITE["conversion"]["to LEMONDiGraph"] = @benchmarkable LEMONDiGraph($CONV_DIGRAPH)
SUITE["conversion"]["back to Graph"] = @benchmarkable Graph($CONV_LEMON)
SUITE["conversion"]["back to DiGraph"] = @benchmarkable DiGraph($CONV_LEMON_DI)
# O(1) reuse: handing a wrapper to a LEMON algorithm must not re-convert it
SUITE["conversion"]["reuse a wrapper"] = @benchmarkable LEMONGraphs.to_list_graph(
    $CONV_LEMON
)

# ---------------------------------------------------------------------------
# AbstractGraph API, the inner loop of every generic Graphs.jl algorithm
# ---------------------------------------------------------------------------

function neighbor_sweep(g)
    total = 0
    for v in vertices(g), u in outneighbors(g, v)
        total += u
    end
    return total
end

function edge_sweep(g)
    total = 0
    for e in edges(g)
        total += src(e) + dst(e)
    end
    return total
end

function has_edge_sweep(g, n)
    total = 0
    for u in 1:n, v in 1:n
        total += has_edge(g, u, v)
    end
    return total
end

const API_GRAPH = grid([25, 25])
const API_LEMON = LEMONGraph(API_GRAPH)

SUITE["api"] = BenchmarkGroup()
for (name, g) in ("LEMONGraph" => API_LEMON, "SimpleGraph" => API_GRAPH)
    SUITE["api"]["outneighbors ($name)"] = @benchmarkable neighbor_sweep($g)
    SUITE["api"]["edges ($name)"] = @benchmarkable edge_sweep($g)
    SUITE["api"]["has_edge ($name)"] = @benchmarkable has_edge_sweep($g, 60)
end
# a generic Graphs.jl algorithm driven entirely through the interface
SUITE["api"]["connected_components (LEMONGraph)"] = @benchmarkable connected_components(
    $API_LEMON
)

# ---------------------------------------------------------------------------
# Dijkstra: the LEMON backend against the native Graphs.jl one
# ---------------------------------------------------------------------------

const DIJKSTRA_GRAPH = grid([20, 20])
const DIJKSTRA_LEMON = LEMONDiGraph(DIJKSTRA_GRAPH)
const DIJKSTRA_WEIGHTS = [
    1 + ((i + j) % 7) for i in 1:nv(DIJKSTRA_GRAPH), j in 1:nv(DIJKSTRA_GRAPH)
]

SUITE["dijkstra"] = BenchmarkGroup()
SUITE["dijkstra"]["Graphs.jl"] = @benchmarkable dijkstra_shortest_paths(
    $DIJKSTRA_GRAPH, 1, $DIJKSTRA_WEIGHTS
)
# from a SimpleGraph the LEMON backend has to build the C++ digraph first ...
SUITE["dijkstra"]["LEMON (converting)"] = @benchmarkable dijkstra_shortest_paths(
    $DIJKSTRA_GRAPH, 1, $DIJKSTRA_WEIGHTS, LEMONAlgorithm()
)
# ... whereas a wrapper it already holds is reused as is
SUITE["dijkstra"]["LEMON (prebuilt wrapper)"] = @benchmarkable dijkstra_shortest_paths(
    $DIJKSTRA_LEMON, 1, $DIJKSTRA_WEIGHTS, LEMONAlgorithm()
)
SUITE["dijkstra"]["LEMON (multi-source)"] = @benchmarkable dijkstra_shortest_paths(
    $DIJKSTRA_GRAPH, [1, 5], $DIJKSTRA_WEIGHTS, LEMONAlgorithm()
)
