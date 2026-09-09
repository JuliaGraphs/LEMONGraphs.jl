module LEMONGraphsGraphsMatchingExt

using LEMONGraphs
using Graphs
using GraphsMatching

function GraphsMatching.minimum_weight_perfect_matching(
    g::AbstractGraph,
    weights::Dict{E,U},
    ::LEMONGraphs.LEMONAlgorithm;
) where {E<:Edge,U<:Integer}
    max_penalty = 2 * abs(maximum(values(weights)))
    lemon_weights = [-get(weights, e, max_penalty) for e in edges(g)]
    weight_sum, mate_vec = LEMONGraphs.maxweightedperfectmatching(g, lemon_weights)
    return GraphsMatching.MatchingResult(-weight_sum, mate_vec)
end

function GraphsMatching.minimum_weight_perfect_matching(
    g::AbstractGraph,
    weights::Dict{E,U},
    ::LEMONGraphs.LEMONAlgorithm;
    tmaxscale=10.0,
) where {E<:Edge,U<:AbstractFloat}
    scaled = Dict{E,Int32}()
    cmax = maximum(values(weights))
    cmin = minimum(values(weights))
    tmax = typemax(Int32) / tmaxscale

    for (e, c) in weights
        scaled[e] = round(Int32, (c - cmin) / max(cmax - cmin, 1) * tmax)
    end

    match = GraphsMatching.minimum_weight_perfect_matching(g, scaled, LEMONGraphs.LEMONAlgorithm())
    total_weight = zero(U)
    for i in 1:nv(g)
        j = match.mate[i]
        if j > i
            total_weight += get(weights, E(i, j), zero(U))
        end
    end
    return GraphsMatching.MatchingResult(total_weight, match.mate)
end

end  # module
