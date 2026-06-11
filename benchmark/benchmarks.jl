using BenchmarkTools
using Graphs
using LEMONGraphs: maxweightedperfectmatching

const SUITE = BenchmarkGroup()

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
