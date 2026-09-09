@testitem "GraphsOptim: LEMON shortest_path dispatch" begin
    using Graphs, GraphsOptim, LEMONGraphs, Test

    g = SimpleDiGraph(4)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 1, 3)

    weights = zeros(Int, 4, 4)
    weights[1, 2] = 1
    weights[2, 3] = 2
    weights[1, 3] = 10

    @test GraphsOptim.shortest_path(g, 1, 3, weights, LEMONAlgorithm()) == [1, 2, 3]
    @test GraphsOptim.shortest_path(g, 1, 1, weights, LEMONAlgorithm()) == [1]

    err = @test_throws ArgumentError GraphsOptim.shortest_path(
        g, 1, 4, weights, LEMONAlgorithm()
    )
    @test occursin("No path", sprint(showerror, err.value))

    float_cost = Float64.(weights)
    err = @test_throws ArgumentError GraphsOptim.shortest_path(
        g, 1, 3, float_cost, LEMONAlgorithm()
    )
    @test occursin("integer edge costs", sprint(showerror, err.value))
end

@testitem "GraphsOptim: LEMON min_cost_flow" begin
    using Graphs, GraphsOptim, LEMONGraphs, Test

    g = SimpleDiGraph(3)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)

    vertex_demand = [-1, 0, 1]
    edge_cost = zeros(Int, 3, 3)
    edge_cost[1, 2] = 1
    edge_cost[2, 3] = 1

    # uncapacitated (default) form
    flow = GraphsOptim.min_cost_flow(g, vertex_demand, edge_cost, LEMONAlgorithm())
    @test flow[1, 2] == 1
    @test flow[2, 3] == 1

    # explicit capacities, including `Inf` for an unbounded arc
    emin = zeros(Int, 3, 3)
    emax = zeros(Int, 3, 3)
    emax[1, 2] = 1
    emax[2, 3] = 1
    @test GraphsOptim.min_cost_flow(
        g, vertex_demand, edge_cost, emin, emax, LEMONAlgorithm()
    ) == flow
    @test GraphsOptim.min_cost_flow(
        g, vertex_demand, edge_cost, emin, fill(Inf, 3, 3), LEMONAlgorithm()
    ) == flow

    # a lower bound forces flow through an otherwise unused arc
    add_edge!(g, 1, 3)
    cost2 = zeros(Int, 3, 3)
    cost2[1, 2] = 1
    cost2[2, 3] = 1
    cost2[1, 3] = 1
    lower = zeros(Int, 3, 3)
    upper = fill(5, 3, 3)
    plain = GraphsOptim.min_cost_flow(g, [-2, 0, 2], cost2, lower, upper, LEMONAlgorithm())
    @test plain[1, 3] == 2
    lower[1, 2] = 1
    forced = GraphsOptim.min_cost_flow(g, [-2, 0, 2], cost2, lower, upper, LEMONAlgorithm())
    @test forced[1, 2] == 1
    @test forced[2, 3] == 1
    @test forced[1, 3] == 1

    # infeasible / malformed inputs
    err = @test_throws ArgumentError GraphsOptim.min_cost_flow(
        g, [-1, 0, 1], cost2, zeros(Int, 3, 3), zeros(Int, 3, 3), LEMONAlgorithm()
    )
    @test occursin("infeasible", sprint(showerror, err.value))

    err = @test_throws ArgumentError GraphsOptim.min_cost_flow(
        g, [-1.5, 0.0, 1.5], cost2, LEMONAlgorithm()
    )
    @test occursin("integer vertex demand", sprint(showerror, err.value))

    err = @test_throws ArgumentError GraphsOptim.min_cost_flow(
        g, [-1, 0, 1], 0.5 .* cost2, LEMONAlgorithm()
    )
    @test occursin("integer edge cost", sprint(showerror, err.value))

    err = @test_throws ArgumentError GraphsOptim.min_cost_flow(
        g, [-1, 0, 1], cost2, lower, fill(0.5, 3, 3), LEMONAlgorithm()
    )
    @test occursin("integer capacities", sprint(showerror, err.value))

    @test_throws DimensionMismatch GraphsOptim.min_cost_flow(
        g, [-1, 1], cost2, LEMONAlgorithm()
    )

    # integral floats are accepted (mixing `Inf` with finite capacities forces
    # a floating point matrix), but nothing is rounded
    mixed = fill(Inf, 3, 3)
    mixed[1, 2] = 1.0
    mixed[2, 3] = 1.0
    mixed[1, 3] = 0.0
    @test GraphsOptim.min_cost_flow(
        g, [-1.0, 0.0, 1.0], Float64.(cost2), zeros(3, 3), mixed, LEMONAlgorithm()
    ) == flow
end

@testitem "GraphsOptim: LEMON min_cost_flow solver selection" begin
    using Graphs, GraphsOptim, LEMONGraphs, StableRNGs, Test

    rng = StableRNG(20260729)
    g = SimpleDiGraph(6)
    for u in 1:6, v in 1:6
        u < v && rand(rng) < 0.6 && add_edge!(g, u, v)
    end
    add_edge!(g, 1, 6)
    cost = rand(rng, 1:9, 6, 6)
    cap = fill(3, 6, 6)
    demand = zeros(Int, 6)
    demand[1] = -2
    demand[6] = 2

    arcs = [(src(e), dst(e)) for e in edges(g)]
    solvers = (:network_simplex, :capacity_scaling, :cost_scaling, :cycle_canceling)
    totals = map(solvers) do solver
        flow = GraphsOptim.min_cost_flow(
            g, demand, cost, zeros(Int, 6, 6), cap, LEMONAlgorithm(); solver
        )
        for v in 1:6
            inflow = sum(flow[u, v] for u in inneighbors(g, v); init=0)
            outflow = sum(flow[v, w] for w in outneighbors(g, v); init=0)
            @test inflow - outflow == demand[v]
        end
        return sum(cost[u, v] * flow[u, v] for (u, v) in arcs; init=0)
    end
    @test all(==(first(totals)), totals)

    err = @test_throws ArgumentError GraphsOptim.min_cost_flow(
        g, demand, cost, LEMONAlgorithm(); solver=:nope
    )
    @test occursin("unknown LEMON minimum cost flow solver", sprint(showerror, err.value))

    # only the network simplex copes with a negative cost on an uncapacitated arc
    h = SimpleDiGraph(3)
    add_edge!(h, 1, 2)
    add_edge!(h, 2, 3)
    negative = zeros(Int, 3, 3)
    negative[1, 2] = -1
    negative[2, 3] = 1
    @test GraphsOptim.min_cost_flow(
        h, [-1, 0, 1], negative, LEMONAlgorithm(); solver=:network_simplex
    )[1, 2] == 1
    for solver in (:capacity_scaling, :cost_scaling, :cycle_canceling)
        err = @test_throws ArgumentError GraphsOptim.min_cost_flow(
            h, [-1, 0, 1], negative, LEMONAlgorithm(); solver
        )
        @test occursin("unbounded", sprint(showerror, err.value))
    end
    # ... and giving those arcs a finite capacity makes them agree again
    for solver in (:capacity_scaling, :cost_scaling, :cycle_canceling)
        @test GraphsOptim.min_cost_flow(
            h, [-1, 0, 1], negative, zeros(Int, 3, 3), fill(4, 3, 3), LEMONAlgorithm();
            solver,
        )[1, 2] == 1
    end
end

@testitem "GraphsOptim: LEMON min_cost_flow matches the JuMP backend" begin
    using Graphs, GraphsOptim, LEMONGraphs, StableRNGs, Test

    rng = StableRNG(20260729)
    for _ in 1:15
        n = rand(rng, 3:7)
        g = SimpleDiGraph(n)
        for u in 1:n, v in 1:n
            u != v && rand(rng) < 0.4 && add_edge!(g, u, v)
        end
        cost = rand(rng, 0:9, n, n)
        cap = rand(rng, 0:3, n, n)
        lower = zeros(Int, n, n)
        demand = zeros(Int, n)
        demand[1] = -1
        demand[n] = 1

        lem = try
            GraphsOptim.min_cost_flow(g, demand, cost, lower, cap, LEMONAlgorithm())
        catch err
            err isa ArgumentError || rethrow()
            nothing
        end
        ref = try
            GraphsOptim.min_cost_flow(g, demand, cost, lower, cap; integer=true)
        catch
            nothing
        end
        lem === nothing && ref === nothing && continue
        @test (lem === nothing) == (ref === nothing)
        lem === nothing && continue

        arcs = [(src(e), dst(e)) for e in edges(g)]
        # the flows themselves may differ between optima, but the costs must not
        @test sum(cost[u, v] * lem[u, v] for (u, v) in arcs; init=0) ≈
            sum(cost[u, v] * ref[u, v] for (u, v) in arcs; init=0)
        # and the LEMON flow must be feasible
        for (u, v) in arcs
            @test lower[u, v] <= lem[u, v] <= cap[u, v]
        end
        for v in 1:n
            inflow = sum(lem[u, v] for u in inneighbors(g, v); init=0)
            outflow = sum(lem[v, w] for w in outneighbors(g, v); init=0)
            @test inflow - outflow == demand[v]
        end
    end
end

@testitem "GraphsOptim: LEMON min_cost_assignment" begin
    using Graphs, GraphsOptim, LEMONGraphs, StableRNGs, Test

    cost = [4 1 3; 2 0 5; 3 2 2]
    assignment = GraphsOptim.min_cost_assignment(cost, LEMONAlgorithm())
    @test assignment isa Matrix{Int}
    @test all(sum(assignment; dims=1) .== 1)
    @test all(sum(assignment; dims=2) .== 1)
    @test sum(cost .* assignment) == 5

    @test GraphsOptim.min_cost_assignment(zeros(Int, 0, 0), LEMONAlgorithm()) ==
        zeros(Int, 0, 0)

    @test_throws DimensionMismatch GraphsOptim.min_cost_assignment(
        zeros(Int, 2, 3), LEMONAlgorithm()
    )
    err = @test_throws ArgumentError GraphsOptim.min_cost_assignment(
        fill(0.5, 2, 2), LEMONAlgorithm()
    )
    @test occursin("integer assignment cost", sprint(showerror, err.value))

    # integral floats are fine
    @test GraphsOptim.min_cost_assignment(Float64.(cost), LEMONAlgorithm()) == assignment

    rng = StableRNG(20260729)
    for _ in 1:15
        n = rand(rng, 1:6)
        C = rand(rng, 0:20, n, n)
        A = GraphsOptim.min_cost_assignment(C, LEMONAlgorithm())
        ref = GraphsOptim.min_cost_assignment(C; integer=true)
        @test all(sum(A; dims=1) .== 1)
        @test all(sum(A; dims=2) .== 1)
        @test sum(C .* A) == round(Int, sum(C .* ref))
    end
end

@testitem "GraphsOptim: unimplemented LEMON dispatches raise helpful errors" begin
    using Graphs, GraphsOptim, LEMONGraphs, Test

    ug = path_graph(3)

    err = @test_throws ArgumentError GraphsOptim.min_vertex_cover(ug, LEMONAlgorithm())
    @test occursin("min_vertex_cover", sprint(showerror, err.value))

    err = @test_throws ArgumentError GraphsOptim.maximum_weight_clique(ug, LEMONAlgorithm())
    @test occursin("maximum_weight_clique", sprint(showerror, err.value))
end
