@testitem "Max Weighted Perfect Matching" begin

using Graphs
using Graphs.Experimental
using LEMONGraphs: maxweightedperfectmatching
using Test
if Sys.islinux() && Sys.ARCH == :x86_64
    import BlossomV
end

function blossomv_mwpm(g::Graph, weights::AbstractVector{<:Integer})
    m = BlossomV.Matching(nv(g))
    wdict = Dict{Tuple{Int,Int},Int}()
    for (e,w) in zip(edges(g),weights)
        BlossomV.add_edge(m, e.src-1, e.dst-1, -w)
        wdict[(e.src,e.dst)] = w
        wdict[(e.dst,e.src)] = w
    end
    BlossomV.solve(m)
    matches = [BlossomV.get_match(m,i-1)+1 for i in vertices(g)]
    weight = sum(wdict[(matches[i],i)] for i in 1:nv(g))
    return weight/2, matches
end

for repetition in 1:100
    g = random_regular_graph(10,3)
    pweights = rand(1:1000, ne(g))
    nweights = rand(-1000:-1, ne(g))
    aweights = rand(-1000:1000, ne(g))
    lemon_pweight, lemon_pmatching = maxweightedperfectmatching(g, pweights)
    lemon_nweight, lemon_nmatching = maxweightedperfectmatching(g, nweights)
    lemon_aweight, lemon_amatching = maxweightedperfectmatching(g, aweights)

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

    if Sys.islinux() && Sys.ARCH == :x86_64
        blossomv_pweight, blossomv_pmatching = blossomv_mwpm(g, pweights)
        @test lemon_pweight == blossomv_pweight
        #@test lemon_pmatching == blossomv_pmatching
        blossomv_nweight, blossomv_nmatching = blossomv_mwpm(g, nweights)
        @test lemon_nweight == blossomv_nweight
        #@test lemon_nmatching == blossomv_nmatching
        blossomv_aweight, blossomv_amatching = blossomv_mwpm(g, aweights)
        @test lemon_aweight == blossomv_aweight
        #@test lemon_amatching == blossomv_amatching
    end
end

end
