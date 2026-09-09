@testitem "LEMONGraph: Basic construction and properties" begin
    using LEMONGraphs, Graphs

    g = path_graph(5)
    lg = LEMONGraph(g)

    @test nv(lg) == 5
    @test ne(lg) == 4
    @test vertices(lg) == 1:5
    @test length(edges(lg)) == 4
    @test is_directed(typeof(lg)) == false
    @test edgetype(lg) == Edge{Int}
    @test eltype(lg) == Int
end

@testitem "LEMONGraph: has_vertex and has_edge" begin
    using LEMONGraphs, Graphs
    
    g = cycle_graph(4)
    lg = LEMONGraph(g)
    
    # Check vertices
    @test has_vertex(lg, 1)
    @test has_vertex(lg, 4)
    @test !has_vertex(lg, 5)
    @test !has_vertex(lg, 0)
    
    # Check edges (cycle: 1-2, 2-3, 3-4, 4-1)
    @test has_edge(lg, 1, 2)
    @test has_edge(lg, 2, 3)
    @test has_edge(lg, 4, 1)
    @test !has_edge(lg, 1, 3)
    @test !has_edge(lg, 2, 4)
end

@testitem "LEMONGraph: neighbors (inneighbors/outneighbors)" begin
    using LEMONGraphs, Graphs
    
    g = star_graph(5)  # Star: central node 1, leaves 2,3,4,5
    lg = LEMONGraph(g)
    
    # Central node neighbors
    central_neighbors = sort(inneighbors(lg, 1))
    @test central_neighbors == [2, 3, 4, 5]
    
    # Leaf neighbors
    leaf_neighbors = inneighbors(lg, 2)
    @test leaf_neighbors == [1]
    
    # For undirected graphs, outneighbors should match inneighbors
    @test inneighbors(lg, 1) == outneighbors(lg, 1)
end

@testitem "LEMONGraph: fast reuse (to_list_graph)" begin
    using LEMONGraphs, Graphs
    
    g = complete_graph(4)
    lg = LEMONGraph(g)
    
    # Basic checks
    @test nv(lg) == 4
    @test ne(lg) == 6
end

@testitem "LEMONDiGraph: Basic construction and properties" begin
    using LEMONGraphs, Graphs
    
    dg = SimpleDiGraph(5)
    add_edge!(dg, 1, 2)
    add_edge!(dg, 2, 3)
    add_edge!(dg, 3, 1)
    add_edge!(dg, 2, 5)
    
    ldg = LEMONDiGraph(dg)
    
    @test nv(ldg) == 5
    @test ne(ldg) == 4
    @test is_directed(typeof(ldg)) == true
    @test edgetype(ldg) == Edge{Int}
    @test eltype(ldg) == Int
end

@testitem "LEMONDiGraph: has_edge for directed edges" begin
    using LEMONGraphs, Graphs
    
    dg = SimpleDiGraph(3)
    add_edge!(dg, 1, 2)
    add_edge!(dg, 2, 3)
    
    ldg = LEMONDiGraph(dg)
    
    @test has_edge(ldg, 1, 2)
    @test has_edge(ldg, 2, 3)
    @test !has_edge(ldg, 2, 1)  # directed: reverse should not exist
    @test !has_edge(ldg, 1, 3)
end

@testitem "LEMONDiGraph: inneighbors and outneighbors" begin
    using LEMONGraphs, Graphs
    
    dg = SimpleDiGraph(4)
    add_edge!(dg, 1, 2)
    add_edge!(dg, 1, 3)
    add_edge!(dg, 2, 4)
    add_edge!(dg, 3, 4)
    
    ldg = LEMONDiGraph(dg)
    
    # Node 1: outgoing to 2,3; incoming from none
    out1 = sort(outneighbors(ldg, 1))
    in1 = inneighbors(ldg, 1)
    @test out1 == [2, 3]
    @test isempty(in1)
    
    # Node 4: incoming from 2,3; outgoing to none
    out4 = outneighbors(ldg, 4)
    in4 = sort(inneighbors(ldg, 4))
    @test isempty(out4)
    @test in4 == [2, 3]
end

@testitem "LEMONGraph: Roundtrip conversion" begin
    using LEMONGraphs, Graphs
    
    # Create a graph
    g = wheel_graph(6)
    
    # Convert to LEMON
    lg = LEMONGraph(g)
    
    # Check preservation
    @test nv(lg) == nv(g)
    @test ne(lg) == ne(g)
    
    # Check edge preservation (convert back)
    edges_orig = Set(edges(g))
    edges_lemon = Set(edges(lg))
    @test edges_orig == edges_lemon
end

@testitem "LEMONDiGraph: Roundtrip conversion" begin
    using LEMONGraphs, Graphs
    
    # Create a digraph
    dg = SimpleDiGraph(5)
    for (u, v) in [(1,2), (2,3), (3,4), (4,5), (5,1)]
        add_edge!(dg, u, v)
    end
    
    # Convert to LEMON
    ldg = LEMONDiGraph(dg)
    
    # Check preservation
    @test nv(ldg) == nv(dg)
    @test ne(ldg) == ne(dg)
    
    # Check edge preservation
    edges_orig = Set(edges(dg))
    edges_lemon = Set(edges(ldg))
    @test edges_orig == edges_lemon
end

@testitem "LEMON graphs: conversion back to Graphs.jl" begin
    using LEMONGraphs, Graphs

    g = wheel_graph(6)
    lg = LEMONGraph(g)
    g2 = Graph(lg)
    @test g2 == g
    @test convert(Graph, lg) == g

    dg = path_digraph(5)
    ldg = LEMONDiGraph(dg)
    dg2 = DiGraph(ldg)
    @test dg2 == dg
    @test convert(DiGraph, ldg) == dg
end

@testitem "LEMON graphs: edge iterator is lazy and consistent" begin
    using LEMONGraphs, Graphs

    for g in (wheel_graph(6), path_graph(4), complete_graph(5))
        lg = LEMONGraph(g)
        it = edges(lg)
        @test eltype(it) == Edge{Int}
        @test length(it) == ne(g)
        @test !(it isa AbstractArray)      # a lazy view, not a materialised vector
        @test Set(collect(it)) == Set(edges(g))
        @test all(e -> e in it, edges(g))
        @test !(Edge(1, nv(g) + 1) in it)
        @test src.(it) == src.(collect(edges(g)))
    end

    dg = complete_digraph(4)
    ldg = LEMONDiGraph(dg)
    @test Set(collect(edges(ldg))) == Set(edges(dg))
    @test length(edges(ldg)) == ne(dg)
end

@testitem "LEMON graphs: neighbours agree with the SimpleGraph originals" begin
    using LEMONGraphs, Graphs, StableRNGs

    rng = StableRNG(20260729)
    for _ in 1:20
        n = rand(rng, 1:12)
        g = erdos_renyi(n, 0.35; rng)
        dg = erdos_renyi(n, 0.35; is_directed=true, rng)
        lg, ldg = LEMONGraph(g), LEMONDiGraph(dg)

        @test nv(lg) == nv(g) && ne(lg) == ne(g)
        @test nv(ldg) == nv(dg) && ne(ldg) == ne(dg)
        for v in vertices(g)
            @test sort(collect(outneighbors(lg, v))) == sort(outneighbors(g, v))
            @test sort(collect(inneighbors(lg, v))) == sort(inneighbors(g, v))
            @test sort(collect(outneighbors(ldg, v))) == sort(outneighbors(dg, v))
            @test sort(collect(inneighbors(ldg, v))) == sort(inneighbors(dg, v))
        end
        for u in vertices(g), v in vertices(g)
            @test has_edge(lg, u, v) == has_edge(g, u, v)
            @test has_edge(ldg, u, v) == has_edge(dg, u, v)
        end
        @test !has_edge(lg, 0, 1)
        @test !has_edge(ldg, 1, nv(dg) + 1)
    end
end

@testitem "LEMON graphs: work with generic Graphs.jl algorithms" begin
    using LEMONGraphs, Graphs

    # Algorithms that only use the AbstractGraph API must accept the wrappers.
    g = wheel_graph(7)
    lg = LEMONGraph(g)
    @test connected_components(lg) == connected_components(g)
    @test sort(degree(lg)) == sort(degree(g))
    @test diameter(lg) == diameter(g)
    @test length(kruskal_mst(lg)) == nv(g) - 1
    @test gdistances(lg, 1) == gdistances(g, 1)

    dg = cycle_digraph(6)
    ldg = LEMONDiGraph(dg)
    @test is_strongly_connected(ldg) == is_strongly_connected(dg)
    @test length(topological_sort_by_dfs(LEMONDiGraph(path_digraph(5)))) == 5
end

@testitem "LEMON graphs: growing a wrapper matches the SimpleGraph oracle" begin
    using LEMONGraphs, Graphs, StableRNGs, Test

    rng = StableRNG(20260729)
    for _ in 1:40
        n = rand(rng, 1:8)
        lg, sg = LEMONGraph(n), SimpleGraph(n)
        ldg, sdg = LEMONDiGraph(n), SimpleDiGraph(n)
        for _ in 1:15
            if rand(rng) < 0.25
                @test add_vertex!(lg) == add_vertex!(sg)
                @test add_vertex!(ldg) == add_vertex!(sdg)
            else
                u, v = rand(rng, 1:nv(sg)), rand(rng, 1:nv(sg))
                @test add_edge!(lg, u, v) == add_edge!(sg, u, v)
                @test add_edge!(ldg, u, v) == add_edge!(sdg, u, v)
            end
            @test nv(lg) == nv(sg) && ne(lg) == ne(sg)
            @test Graph(lg) == sg
            @test DiGraph(ldg) == sdg
            @test Set(edges(lg)) == Set(edges(sg))
            @test Set(edges(ldg)) == Set(edges(sdg))
            for w in vertices(sg)
                @test outneighbors(lg, w) == outneighbors(sg, w)
                @test inneighbors(lg, w) == inneighbors(sg, w)
                @test outneighbors(ldg, w) == outneighbors(sdg, w)
                @test inneighbors(ldg, w) == inneighbors(sdg, w)
            end
        end
    end

    # adding an edge that is already there is a no-op, as in Graphs.jl
    lg = LEMONGraph(path_graph(3))
    @test !add_edge!(lg, 1, 2)
    @test !add_edge!(lg, 2, 1)
    @test !add_edge!(lg, 1, 9)
    @test ne(lg) == 2
    @test add_edge!(lg, Edge(1, 3))
    @test has_edge(lg, 3, 1)

    # LEMON_jll exposes no `erase`, so removal declines rather than lying
    @test !rem_edge!(lg, 1, 2)
    @test !rem_edge!(lg, Edge(1, 2))
    @test !rem_vertex!(lg, 1)
    @test ne(lg) == 3 && nv(lg) == 3
end

@testitem "LEMON graphs: copy, zero, reverse and derived subgraphs" begin
    using LEMONGraphs, Graphs, Test

    g = wheel_graph(6)
    lg = LEMONGraph(g)

    h = copy(lg)
    @test add_edge!(h, 2, 4)
    @test ne(h) == ne(lg) + 1     # the copy is independent of the original
    @test Graph(lg) == g

    @test nv(zero(lg)) == 0
    @test typeof(zero(lg)) == typeof(lg)
    @test typeof(zero(typeof(lg))) == typeof(lg)
    @test nv(LEMONGraph(4)) == 4 && ne(LEMONGraph(4)) == 0
    @test nv(LEMONDiGraph(4)) == 4 && ne(LEMONDiGraph(4)) == 0

    dg = path_digraph(4)
    @test DiGraph(reverse(LEMONDiGraph(dg))) == reverse(dg)

    # generic Graphs.jl algorithms that build a graph of the same type
    sub, vmap = induced_subgraph(lg, [1, 2, 3])
    ref, refmap = induced_subgraph(g, [1, 2, 3])
    @test Graph(sub) == ref
    @test vmap == refmap
    @test Graph(egonet(lg, 1, 1)) == egonet(g, 1, 1)
end

@testitem "LEMON graphs: O(1) reuse of an existing wrapper" begin
    using LEMONGraphs, Graphs

    g = complete_graph(6)
    lg = LEMONGraph(g)
    graph, nodes, edgs = LEMONGraphs.to_list_graph(lg)
    @test graph === lg.graph
    @test nodes === lg.nodes
    @test edgs === lg.edges

    dg = complete_digraph(5)
    ldg = LEMONDiGraph(dg)
    dgraph, dnodes, arcs = LEMONGraphs.to_list_digraph(ldg)
    @test dgraph === ldg.graph
    @test dnodes === ldg.nodes
    @test arcs === ldg.arcs
end
