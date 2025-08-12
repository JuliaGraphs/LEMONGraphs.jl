module LEMONGraphs

import Graphs
import Graphs: Graph, Edge, vertices, edges, nv, ne

# Marker type to request LEMON-backed algorithm dispatch from
# packages that extend Graphs.jl algorithms.
#
# Example usage pattern (in client code):
#   shortest_paths(g::AbstractGraph, s, ::LEMONAlgorithm)
# The method would be defined in this package to call into the C++ LEMON impl.
struct LEMONAlgorithm end

module Lib
  using CxxWrap
  import LEMON_jll
  @wrapmodule(LEMON_jll.get_liblemoncxxwrap_path)

  function __init__()
    @initcxx
  end

  id(n::ListGraphNodeIt) = id(convert(ListGraphNode, n))
  id(n::ListGraphEdgeIt) = id(convert(ListGraphEdge, n))
  id(n::ListDigraphNodeIt) = id(convert(ListDigraphNode, n))
  # not defined in the c++ wrapper
  #id(n::ListDigraphArcIt) = id(convert(ListDigraphArc, n))
end

# Conversion helpers between Graphs.jl graphs and LEMON ListGraph.
# Returns the created LEMON graph and the corresponding node/edge handles.
function toListGraph(sourcegraph::Graph)
    g = Lib.ListGraph()
    ns = [Lib.addNode(g) for i in vertices(sourcegraph)]
    es = [Lib.addEdge(g,ns[src],ns[dst]) for (;src, dst) in edges(sourcegraph)]
    return (g,ns,es)
end

Lib.ListGraph(sourcegraph::Graph) = toListGraph(sourcegraph)[1]

function maxweightedperfectmatching(graph::Graph, weights::AbstractVector{<:Integer})
    g,ns,es = toListGraph(graph)
    mapedge = Lib.ListGraphEdgeMapInt(g)
    for (e,w) in zip(es,weights)
        Lib.set(mapedge, e, w)
    end
    mwpm = Lib.MaxWeightedPerfectMatchingListGraphInt(g,mapedge)
    Lib.run(mwpm)
    return Lib.matchingWeight(mwpm), [Lib.id(Lib.mate(mwpm,i))+1 for i in ns]
end

function maxweightedperfectmatching(graph::Graph, weights::Dict{E,T}) where {E<:Edge,T<:Integer}
    return maxweightedperfectmatching(graph, [weights[e] for e in edges(graph)])
end

end
