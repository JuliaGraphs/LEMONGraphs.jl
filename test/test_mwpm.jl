@testitem "Max Weighted Perfect Matching" begin

using Graphs
using Graphs.Experimental
using LEMONGraphs: maxweightedperfectmatching
using StableRNGs
using Test

function brute_force_mwpm_weight(g::Graph, weights::AbstractVector{<:Integer})
    weight_by_edge = Dict{Tuple{Int,Int},Int}()
    for (e, w) in zip(edges(g), weights)
        u, v = minmax(e.src, e.dst)
        weight_by_edge[(u, v)] = w
    end

    best_weight = Ref(typemin(Int))

    function search(unmatched::Vector{Int}, current_weight::Int)
        if isempty(unmatched)
            best_weight[] = max(best_weight[], current_weight)
            return
        end

        u = first(unmatched)
        for i in 2:length(unmatched)
            v = unmatched[i]
            key = minmax(u, v)
            haskey(weight_by_edge, key) || continue

            remaining = [unmatched[2:(i - 1)]; unmatched[(i + 1):end]]
            search(remaining, current_weight + weight_by_edge[key])
        end
    end

    search(collect(vertices(g)), 0)
    @test best_weight[] != typemin(Int)
    return best_weight[]
end

rng = StableRNG(1234)

for repetition in 1:100
    g = random_regular_graph(10, 3; rng)
    pweights = rand(rng, 1:1000, ne(g))
    nweights = rand(rng, -1000:-1, ne(g))
    aweights = rand(rng, -1000:1000, ne(g))
    lemon_pweight, lemon_pmatching = maxweightedperfectmatching(g, pweights)
    lemon_nweight, lemon_nmatching = maxweightedperfectmatching(g, nweights)
    lemon_aweight, lemon_amatching = maxweightedperfectmatching(g, aweights)
    oracle_pweight = brute_force_mwpm_weight(g, pweights)
    oracle_nweight = brute_force_mwpm_weight(g, nweights)
    oracle_aweight = brute_force_mwpm_weight(g, aweights)

    pweightsdict = Dict{Edge,Int}()
    nweightsdict = Dict{Edge,Int}()
    aweightsdict = Dict{Edge,Int}()
    for (e,w) in zip(edges(g),pweights)
        pweightsdict[e] = w
    end
    for (e,w) in zip(edges(g),nweights)
        nweightsdict[e] = w
    end
    for (e,w) in zip(edges(g),aweights)
        aweightsdict[e] = w
    end
    lemon_pweight_d, lemon_pmatching_d = maxweightedperfectmatching(g, pweightsdict)
    lemon_nweight_d, lemon_nmatching_d = maxweightedperfectmatching(g, nweightsdict)
    lemon_aweight_d, lemon_amatching_d = maxweightedperfectmatching(g, aweightsdict)

    @test lemon_pweight == lemon_pweight_d
    @test lemon_nweight == lemon_nweight_d
    @test lemon_aweight == lemon_aweight_d
    @test lemon_pweight == oracle_pweight
    @test lemon_nweight == oracle_nweight
    @test lemon_aweight == oracle_aweight
end

end
