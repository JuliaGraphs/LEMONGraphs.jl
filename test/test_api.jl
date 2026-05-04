using Test
using LEMONGraphs
using Graphs

@testitem "LEMONGraph: Basic construction and properties" begin
    using LEMONGraphs, Graphs
    
    g = path_graph(5)
    lg = LEMONGraph(g)
    
    @test nv(lg) == 5
    @test ne(lg) == 4
    @test vertices(lg) == 1:5
    @test length(edges(lg)) == 4
    @test is_directed(typeof(lg)) == false
    @test edgetype(lg) == Edge
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
    @test edgetype(ldg) == Edge
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
