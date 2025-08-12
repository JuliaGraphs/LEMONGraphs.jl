using Documenter

makedocs(
    sitename = "LEMONGraphs.jl",
    format = Documenter.HTML(),
    modules = Module[],
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(
    repo = "github.com/JuliaGraphs/LEMONGraphs.jl.git",
)

