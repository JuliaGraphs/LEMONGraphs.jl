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

  const WRAP_OK = Ref(false)

  # Attempt to load the wrapped C++ module; do not hard-fail so the
  # Julia package can still load and downstream tests can decide to skip.
  try
    @wrapmodule(LEMON_jll.get_liblemoncxxwrap_path)
    WRAP_OK[] = true
  catch err
    @warn "LEMONGraphs: failed to load LEMON C++ wrapper; functionality disabled" error=err
    WRAP_OK[] = false
  end

  function __init__()
    if WRAP_OK[]
      @initcxx
    end
  end

  # Helper id shims only if types are defined by the wrapper
  if isdefined(@__MODULE__, :ListGraphNodeIt) && isdefined(@__MODULE__, :ListGraphNode)
    id(n::ListGraphNodeIt) = id(convert(ListGraphNode, n))
  end
  if isdefined(@__MODULE__, :ListGraphEdgeIt) && isdefined(@__MODULE__, :ListGraphEdge)
    id(n::ListGraphEdgeIt) = id(convert(ListGraphEdge, n))
  end
  if isdefined(@__MODULE__, :ListDigraphNodeIt) && isdefined(@__MODULE__, :ListDigraphNode)
    id(n::ListDigraphNodeIt) = id(convert(ListDigraphNode, n))
  end
  # not defined in the c++ wrapper
  # if isdefined(@__MODULE__, :ListDigraphArcIt) && isdefined(@__MODULE__, :ListDigraphArc)
  #   id(n::ListDigraphArcIt) = id(convert(ListDigraphArc, n))
  # end
end

# Conversion helpers between Graphs.jl graphs and LEMON ListGraph.
# Returns the created LEMON graph and the corresponding node/edge handles.
function toListGraph(sourcegraph::Graph)
    if !Lib.WRAP_OK[]
        error("LEMONGraphs Lib is not available; failed to load C++ wrapper")
    end
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
