using Test
using LEMONGraphs
using Graphs

@testitem "LEMONGraph: Dijkstra Shortest Paths" begin
    using LEMONGraphs, Graphs
    
    # Simple directed graph: 1 -> 2 -> 3
    # Weights: 1->2 (10), 2->3 (5)
    g = SimpleDiGraph(3)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    
    weights = zeros(Int, 3, 3)
    weights[1, 2] = 10
    weights[2, 3] = 5
    
    # Run LEMON Dijkstra
    state = dijkstra_shortest_paths(g, 1, weights, LEMONAlgorithm())
    
    @test state.dists[1] == 0
    @test state.dists[2] == 10
    @test state.dists[3] == 15
    @test state.parents[1] == 0
    @test state.parents[2] == 1
    @test state.parents[3] == 2
end
