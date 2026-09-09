@testitem "GraphsInterfaceChecker: AbstractGraph interface compliance" begin
    using LEMONGraphs, Graphs, Test
    using GraphsInterfaceChecker
    using Interfaces

    test_graphs = [
        LEMONGraph(SimpleGraph(0)),
        LEMONGraph(SimpleGraph(3)),
        LEMONGraph(path_graph(4)),
        LEMONGraph(complete_graph(4)),
        LEMONGraph(wheel_graph(6)),
    ]
    test_digraphs = [
        LEMONDiGraph(SimpleDiGraph(0)),
        LEMONDiGraph(SimpleDiGraph(3)),
        LEMONDiGraph(path_digraph(4)),
        LEMONDiGraph(complete_digraph(4)),
        LEMONDiGraph(cycle_digraph(5)),
    ]

    # The optional `mutation` component is claimed as well: `add_vertex!` and
    # `add_edge!` grow the LEMON structure, and `rem_vertex!`/`rem_edge!`
    # decline by returning `false` -- which the interface explicitly allows --
    # because LEMON_jll does not expose `ListGraph::erase`.
    @implements AbstractGraphInterface{(:mutation)} LEMONGraph test_graphs
    @implements AbstractGraphInterface{(:mutation)} LEMONDiGraph test_digraphs

    @test Interfaces.test(AbstractGraphInterface, LEMONGraph)
    @test Interfaces.test(AbstractGraphInterface, LEMONDiGraph)
end
