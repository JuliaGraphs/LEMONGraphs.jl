using Documenter
using LEMONGraphs

makedocs(
    sitename = "LEMONGraphs.jl",
    modules = [LEMONGraphs],
    # internal helpers carry docstrings for the sake of contributors without
    # being part of the manual
    checkdocs = :exports,
    repo = "https://github.com/JuliaGraphs/LEMONGraphs.jl/blob/{commit}{path}#L{line}",
    format = Documenter.HTML(
        repolink = "https://github.com/JuliaGraphs/LEMONGraphs.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Graph types and conversions" => "graphs.md",
        "LEMON-backed algorithms" => "algorithms.md",
        "Adding another LEMON algorithm" => "extending.md",
        "API reference" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/JuliaGraphs/LEMONGraphs.jl.git",
    push_preview = true,
)
