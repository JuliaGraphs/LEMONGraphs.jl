using Documenter
using LEMONGraphs

makedocs(
    sitename = "LEMONGraphs.jl",
    modules = [LEMONGraphs],
    repo = "https://github.com/JuliaGraphs/LEMONGraphs.jl/blob/{commit}{path}#L{line}",
    format = Documenter.HTML(
        repolink = "https://github.com/JuliaGraphs/LEMONGraphs.jl",
    ),
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(
    repo = "github.com/JuliaGraphs/LEMONGraphs.jl.git",
    push_preview = true,
)
