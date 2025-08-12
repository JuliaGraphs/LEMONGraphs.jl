@testitem "Aqua analysis" begin

using Aqua, LEMONGraphs

using Test
@testset "Aqua" begin
    Aqua.test_unbound_args(LEMONGraphs)
    Aqua.test_undefined_exports(LEMONGraphs)
    Aqua.test_project_extras(LEMONGraphs)
    Aqua.test_stale_deps(LEMONGraphs)
    Aqua.test_deps_compat(LEMONGraphs)
    Aqua.test_persistent_tasks(LEMONGraphs)
end

end
