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

    # the same answer as GraphsMatching's own LEMON-backed default
    @test GraphsMatching.minimum_weight_perfect_matching(g, weights).weight == match.weight

    lg = LEMONGraph(g)
    weight_sum, mate_vec = LEMONGraphs.maxweightedperfectmatching(lg, [10, 1, 1, 1, 1, 10])
    @test weight_sum == 20
    @test mate_vec == [2, 1, 4, 3] || mate_vec == [3, 4, 1, 2]
end

@testitem "GraphsMatching: LEMONAlgorithm with floating point weights" begin
    using Graphs, GraphsMatching, LEMONGraphs, Test

    g = complete_graph(4)
    weights = Dict(
        Edge(1, 2) => 10.0,
        Edge(1, 3) => 1.0,
        Edge(1, 4) => 1.0,
        Edge(2, 3) => 1.0,
        Edge(2, 4) => 1.0,
        Edge(3, 4) => 10.0,
    )

    match = GraphsMatching.minimum_weight_perfect_matching(g, weights, LEMONAlgorithm())
    @test match isa GraphsMatching.MatchingResult
    @test match.weight ≈ 2.0
    @test match.mate == [3, 4, 1, 2] || match.mate == [4, 3, 2, 1]
end

@testitem "LEMON matching: legacy 2-argument API" begin
    using Graphs, LEMONGraphs, Test

    g = complete_graph(4)
    weights = [10, 1, 1, 1, 1, 10]
    weight_sum, mate_vec = LEMONGraphs.maxweightedperfectmatching(g, weights)

    @test weight_sum == 20
    @test mate_vec == [2, 1, 4, 3] || mate_vec == [3, 4, 1, 2]

    @test_throws DimensionMismatch LEMONGraphs.maxweightedperfectmatching(g, [1, 2, 3])

    # weights are stored in a C++ `int`
    toobig = fill(typemax(Int), 6)
    err = @test_throws ArgumentError LEMONGraphs.maxweightedperfectmatching(g, toobig)
    @test occursin("does not fit", sprint(showerror, err.value))

    # directed graphs have no perfect matching notion in LEMON's ListGraph
    err = @test_throws ArgumentError LEMONGraphs.maxweightedperfectmatching(
        path_digraph(4), [1, 1, 1]
    )
    @test occursin("undirected", sprint(showerror, err.value))
end
