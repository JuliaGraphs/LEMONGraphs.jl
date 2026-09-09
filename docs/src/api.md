```@meta
CurrentModule = LEMONGraphs
```

# API reference

## Graph types

```@docs
LEMONGraph
LEMONDiGraph
Graph(::LEMONGraph)
DiGraph(::LEMONDiGraph)
Graphs.reverse(::LEMONDiGraph)
```

## Algorithm selection

```@docs
LEMONAlgorithm
```

## Algorithms

```@docs
maxweightedperfectmatching
Graphs.dijkstra_shortest_paths(::AbstractGraph, ::Vector{<:Integer}, ::AbstractMatrix{T}, ::LEMONAlgorithm) where {T<:Integer}
```

## Conversion helpers

```@docs
LEMONGraphs.to_list_graph
LEMONGraphs.to_list_digraph
```

## Value types

```@docs
LEMONGraphs.CxxInt
LEMONGraphs.CxxLong
```
