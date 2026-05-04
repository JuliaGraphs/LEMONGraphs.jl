module LEMONGraphsGraphsMatchingExt

using LEMONGraphs
using Graphs
using GraphsMatching

"""
    minimum_weight_perfect_matching(g::AbstractGraph, weights, ::LEMONGraphs.LEMONAlgorithm)

Compute minimum-weight perfect matching using LEMON backend.

# Arguments
- `g::AbstractGraph`: input graph
- `weights`: edge weights (Dict or Vector)
- `::LEMONAlgorithm`: dispatch marker

# Returns
- `MatchingResult` with valid spouse mapping and total weight
"""
function GraphsMatching.minimum_weight_perfect_matching(g::AbstractGraph, weights, alg::LEMONGraphs.LEMONAlgorithm)
    # For LEMON: we need to negate weights (since LEMON maximizes, we minimize by negating)
    if weights isa Dict
        weights_vec = [-weights[e] for e in edges(g)]
    else
        weights_vec = -weights
    end
    
    # Call LEMON MWPM with negated weights
    weight_sum, mate_vec = LEMONGraphs.maxweightedperfectmatching(g, weights_vec, alg)
    
    # Convert mate vector to spouse dict expected by GraphsMatching
    spouse = Dict{Int,Int}()
    for (i, j) in enumerate(mate_vec)
        spouse[i] = j
    end
    
    return GraphsMatching.MatchingResult(spouse, -weight_sum)  # negate back to get original sum
end

end  # module
