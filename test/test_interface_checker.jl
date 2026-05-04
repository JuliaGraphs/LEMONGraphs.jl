using Test
using LEMONGraphs
using Graphs
using GraphsInterfaceChecker
using Interfaces

test_graphs = [LEMONGraph(SimpleGraph(0)), LEMONGraph(path_graph(4)), LEMONGraph(complete_graph(4))]
test_digraphs = [LEMONDiGraph(SimpleDiGraph(0)), LEMONDiGraph(path_digraph(4)), LEMONDiGraph(complete_digraph(4))]

@implements AbstractGraphInterface{(:mutation)} LEMONGraph test_graphs
@implements AbstractGraphInterface{(:mutation)} LEMONDiGraph test_digraphs

@test Interfaces.test(AbstractGraphInterface, LEMONGraph)
@test Interfaces.test(AbstractGraphInterface, LEMONDiGraph)
