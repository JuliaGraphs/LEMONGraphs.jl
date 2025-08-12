using LEMONGraphs
using TestItemRunner
import Pkg
using Graphs
using GraphsInterfaceChecker

if Sys.islinux() && Sys.ARCH == :x86_64
    Pkg.add("BlossomV")
end

# filter for the test
testfilter = ti -> begin
  exclude = Symbol[]
  if get(ENV,"JET_TEST","")!="true"
    push!(exclude, :jet)
  end
  if !(VERSION >= v"1.10")
    push!(exclude, :doctests)
    push!(exclude, :aqua)
  end

  return all(!in(exclude), ti.tags)
end

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")

@run_package_tests filter=testfilter default_usings=true

# Smoke test: ensure the module initializes and the marker type exists.
@testitem "LEMON init and marker" begin
    using Test
    using LEMONGraphs
    @test isdefined(LEMONGraphs, :LEMONAlgorithm)
end

# Placeholder interface check to ratchet compliance.
@testitem "Graphs interface checker placeholder" begin
    # We will introduce a concrete LEMON-backed graph type later.
    # For now, just confirm Graphs is loaded and basic constructors work.
    g = Graphs.SimpleGraph(4)
    Graphs.add_edge!(g, 1, 2)
    Graphs.add_edge!(g, 3, 4)
    @test Graphs.nv(g) == 4
    @test Graphs.ne(g) == 2
end