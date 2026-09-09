@testitem "LEMON Dijkstra: basic shortest paths" begin
    using LEMONGraphs, Graphs

    # Simple directed graph: 1 -> 2 -> 3 with weights 10 and 5
    g = SimpleDiGraph(3)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)

    weights = zeros(Int, 3, 3)
    weights[1, 2] = 10
    weights[2, 3] = 5

    state = dijkstra_shortest_paths(g, 1, weights, LEMONAlgorithm())

    @test state.dists == [0, 10, 15]
    @test state.parents == [0, 1, 2]
    @test state.pathcounts == [1.0, 1.0, 1.0]

    # unreachable vertices keep `typemax` and a zero parent
    add_vertex!(g)
    weights = zeros(Int, 4, 4)
    weights[1, 2] = 10
    weights[2, 3] = 5
    state = dijkstra_shortest_paths(g, 1, weights, LEMONAlgorithm())
    @test state.dists[4] == typemax(Int)
    @test state.parents[4] == 0
    @test state.pathcounts[4] == 0.0
end

@testitem "LEMON Dijkstra: keyword arguments" begin
    using LEMONGraphs, Graphs, Test

    g = SimpleDiGraph(4)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 1, 4)

    weights = zeros(Int, 4, 4)
    weights[1, 2] = 2
    weights[2, 3] = 2
    weights[1, 4] = 10

    state = dijkstra_shortest_paths(
        g, 1, weights, LEMONAlgorithm(); trackvertices=true, maxdist=4
    )

    @test state.dists == [0, 2, 4, typemax(Int)]
    @test state.pathcounts == [1.0, 1.0, 1.0, 0.0]
    @test state.closest_vertices == [1, 2, 3, 4]
    @test all(isempty, state.predecessors)

    withpaths = dijkstra_shortest_paths(g, 1, weights, LEMONAlgorithm(); allpaths=true)
    @test withpaths.predecessors == [Int[], [1], [2], [1]]

    # the distance matrix defaults to `weights(g)`
    @test dijkstra_shortest_paths(g, 1, LEMONAlgorithm()).dists == [0, 1, 2, 1]
end

@testitem "LEMON Dijkstra: multiple sources" begin
    using LEMONGraphs, Graphs, Test

    g = path_digraph(5)
    w = ones(Int, 5, 5)

    state = dijkstra_shortest_paths(g, [1, 3], w, LEMONAlgorithm())
    @test state.dists == [0, 1, 0, 1, 2]
    @test state.parents == [0, 1, 0, 3, 4]
    @test state.pathcounts == [1.0, 1.0, 1.0, 1.0, 1.0]

    @test_throws ArgumentError dijkstra_shortest_paths(g, Int[], w, LEMONAlgorithm())
    @test_throws ArgumentError dijkstra_shortest_paths(g, [9], w, LEMONAlgorithm())
end

@testitem "LEMON Dijkstra: input validation" begin
    using LEMONGraphs, Graphs, Test

    g = path_digraph(3)

    negative = zeros(Int, 3, 3)
    negative[1, 2] = -1
    err = @test_throws ArgumentError dijkstra_shortest_paths(g, 1, negative, LEMONAlgorithm())
    @test occursin("non-negative", sprint(showerror, err.value))

    floats = ones(Float64, 3, 3)
    err = @test_throws ArgumentError dijkstra_shortest_paths(g, 1, floats, LEMONAlgorithm())
    @test occursin("integer edge weights", sprint(showerror, err.value))

    toobig = zeros(Int, 3, 3)
    toobig[1, 2] = typemax(Int)
    err = @test_throws ArgumentError dijkstra_shortest_paths(g, 1, toobig, LEMONAlgorithm())
    @test occursin("does not fit", sprint(showerror, err.value))
end

@testitem "LEMON Dijkstra: matches the Graphs.jl implementation" begin
    using LEMONGraphs, Graphs, StableRNGs, Test

    rng = StableRNG(20260729)
    for _ in 1:60
        n = rand(rng, 2:9)
        directed = rand(rng, Bool)
        g = directed ? SimpleDiGraph(n) : SimpleGraph(n)
        for u in 1:n, v in 1:n
            u == v && continue
            (!directed && v < u) && continue
            rand(rng) < 0.35 && add_edge!(g, u, v)
        end
        # strictly positive weights, so that the shortest path counts are unique
        w = zeros(Int, n, n)
        for e in edges(g)
            x = rand(rng, 1:5)
            w[src(e), dst(e)] = x
            directed || (w[dst(e), src(e)] = x)
        end
        srcs = sort(unique(rand(rng, 1:n, rand(rng, 1:2))))
        maxdist = rand(rng, Bool) ? typemax(Int) : rand(rng, 0:8)

        for allpaths in (false, true), trackvertices in (false, true)
            ref = dijkstra_shortest_paths(g, srcs, w; allpaths, trackvertices, maxdist)
            lem = dijkstra_shortest_paths(
                g, srcs, w, LEMONAlgorithm(); allpaths, trackvertices, maxdist
            )

            @test lem.dists == ref.dists
            @test lem.pathcounts == ref.pathcounts
            if allpaths
                @test sort.(lem.predecessors) == sort.(ref.predecessors)
            end
            if trackvertices
                # ties may be broken differently, so compare the distance profile
                @test lem.dists[lem.closest_vertices] == ref.dists[ref.closest_vertices]
            end
            # `parents` must span a valid shortest path tree
            for v in 1:n
                p = lem.parents[v]
                p == 0 && continue
                @test lem.dists[p] + w[p, v] == lem.dists[v]
            end
        end
    end
end

@testitem "LEMON Dijkstra: accepts the LEMON wrapper types" begin
    using LEMONGraphs, Graphs

    g = wheel_graph(7)
    w = [i == j ? 0 : (i + j) for i in 1:7, j in 1:7]
    @test dijkstra_shortest_paths(LEMONGraph(g), 1, w, LEMONAlgorithm()).dists ==
        dijkstra_shortest_paths(g, 1, w).dists

    dg = cycle_digraph(6)
    wd = [i == j ? 0 : (i + 2j) for i in 1:6, j in 1:6]
    @test dijkstra_shortest_paths(LEMONDiGraph(dg), 2, wd, LEMONAlgorithm()).dists ==
        dijkstra_shortest_paths(dg, 2, wd).dists
end

@testitem "LEMON Dijkstra: zero-weight edges" begin
    using LEMONGraphs, Graphs

    # 2 -0-> 3 -0-> 2 is a zero-weight cycle away from the source, so vertices
    # 2, 3 and everything behind them are reached by infinitely many shortest
    # walks
    g = SimpleDiGraph(4)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 3, 2)
    add_edge!(g, 3, 4)
    w = zeros(Int, 4, 4)
    w[3, 4] = 1

    state = dijkstra_shortest_paths(g, 1, w, LEMONAlgorithm())
    @test state.dists == [0, 0, 0, 1]
    @test state.pathcounts[1] == 1.0
    @test state.pathcounts[2] == Inf
    @test state.pathcounts[3] == Inf
    @test state.pathcounts[4] == Inf

    # a zero-weight cycle through the source does not count: as in
    # `Graphs.dijkstra_shortest_paths`, walks returning to a source are ignored
    h0 = SimpleDiGraph(2)
    add_edge!(h0, 1, 2)
    add_edge!(h0, 2, 1)
    state = dijkstra_shortest_paths(h0, 1, zeros(Int, 2, 2), LEMONAlgorithm())
    @test state.pathcounts == [1.0, 1.0]

    # without a cycle the zero-weight arcs still yield exact counts
    h = SimpleDiGraph(4)
    add_edge!(h, 1, 2)
    add_edge!(h, 1, 3)
    add_edge!(h, 2, 4)
    add_edge!(h, 3, 4)
    wh = zeros(Int, 4, 4)
    state = dijkstra_shortest_paths(h, 1, wh, LEMONAlgorithm())
    @test state.dists == [0, 0, 0, 0]
    @test state.pathcounts == [1.0, 1.0, 1.0, 2.0]
end
