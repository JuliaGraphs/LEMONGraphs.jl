using Test
using Graphs
using GraphsOptim
using LEMONGraphs

@testitem "GraphsOptim: LEMONAlgorithm dispatch" begin
    using Graphs, GraphsOptim, LEMONGraphs, Test

    g = SimpleDiGraph(3)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)

    weights = zeros(Int, 3, 3)
    weights[1, 2] = 1
    weights[2, 3] = 2

    path = GraphsOptim.shortest_path(g, 1, 3, weights, LEMONAlgorithm())
    @test path == [1, 2, 3]

    float_cost = zeros(Float64, 3, 3)
    float_cost[1, 2] = 1.0
    float_cost[2, 3] = 2.0

    err = try
        GraphsOptim.shortest_path(g, 1, 3, float_cost, LEMONAlgorithm())
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("integer edge costs", sprint(showerror, err))

    edge_cost = ones(2, 2)
    err = try
        GraphsOptim.min_cost_assignment(edge_cost, LEMONAlgorithm())
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("min_cost_assignment", sprint(showerror, err))

    ug = SimpleGraph(3)
    add_edge!(ug, 1, 2)
    add_edge!(ug, 2, 3)

    err = try
        GraphsOptim.min_vertex_cover(ug, LEMONAlgorithm())
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("min_vertex_cover", sprint(showerror, err))

    err = try
        GraphsOptim.maximum_weight_clique(ug, LEMONAlgorithm())
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("maximum_weight_clique", sprint(showerror, err))

    vertex_demand = [-1, 0, 1]
    edge_cost_flow = zeros(Int, 3, 3)
    edge_cost_flow[1, 2] = 1
    edge_cost_flow[2, 3] = 1

    err = try
        GraphsOptim.min_cost_flow(g, vertex_demand, edge_cost_flow, LEMONAlgorithm())
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("min_cost_flow", sprint(showerror, err))
end
