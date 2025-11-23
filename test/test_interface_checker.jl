using Test
using Graphs
using LEMONGraphs
using GraphsInterfaceChecker

# helper: make a small usable LEMON graph 
function make_small_undirected()
    # Example: if your package exposes LEMONGraph(n)
    g = LEMONGraph(5)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    return g
end

function make_small_directed()
    gd = LEMONDiGraph(5)
    add_edge!(gd, 1, 2)
    add_edge!(gd, 2, 3)
    return gd
end

@testset "LEMONGraphs interface checks" begin
    @testset "Undirected LEMONGraph" begin
        g = make_small_undirected()
        check_graph_interface(g)        
        if hasmethod(check_mutable_graph_interface, Tuple{typeof(g)})
            check_mutable_graph_interface(g)
        end
    end

    @testset "Directed LEMONGraph" begin
        gd = make_small_directed()
        check_digraph_interface(gd)     
        if hasmethod(check_mutable_graph_interface, Tuple{typeof(gd)})
            check_mutable_graph_interface(gd)
        end
    end
end
