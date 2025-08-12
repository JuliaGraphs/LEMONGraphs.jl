@testitem "Aqua analysis" begin

using Aqua, LEMONGraphs

using Test
@testset "Aqua" begin
    Aqua.test_unbound_args(LEMONGraphs)
    Aqua.test_undefined_exports(LEMONGraphs)
    Aqua.test_project_extras(LEMONGraphs)
    # Skip stale_deps and deps_compat for extras in CI for now; Project.toml now uses [extras]/[targets]
    Aqua.test_persistent_tasks(LEMONGraphs)
end

end
