using Test
using Graphs
using GraphsMatching
using LEMONGraphs

@testitem "GraphsMatching: LEMONAlgorithm dispatch" begin
    using Graphs, GraphsMatching, LEMONGraphs, Test

    g = complete_graph(4)
    weights = Dict(
        Edge(1, 2) => 10,
        Edge(1, 3) => 1,
        Edge(1, 4) => 1,
        Edge(2, 3) => 1,
        Edge(2, 4) => 1,
        Edge(3, 4) => 10,
    )

    match = GraphsMatching.minimum_weight_perfect_matching(g, weights, LEMONAlgorithm())
    @test match isa GraphsMatching.MatchingResult
    @test match.weight == 2
    @test match.mate == [3, 4, 1, 2] || match.mate == [4, 3, 2, 1]

    lg = LEMONGraph(g)
    weight_sum, mate_vec = LEMONGraphs.maxweightedperfectmatching(lg, [10, 1, 1, 1, 1, 10])
    @test weight_sum == 20
    @test mate_vec == [2, 1, 4, 3] || mate_vec == [3, 4, 1, 2]
end

@testitem "LEMON matching: legacy 2-argument API" begin
    using Graphs, LEMONGraphs, Test

    g = complete_graph(4)
    weights = [10, 1, 1, 1, 1, 10]
    weight_sum, mate_vec = LEMONGraphs.maxweightedperfectmatching(g, weights)

    @test weight_sum == 20
    @test mate_vec == [2, 1, 4, 3] || mate_vec == [3, 4, 1, 2]
end
