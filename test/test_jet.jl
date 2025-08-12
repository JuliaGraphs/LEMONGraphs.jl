if get(ENV, "JET_TEST", "") == "true"
    @testitem "JET analysis" tags=[:jet] begin
        using JET
        using Test
        using LEMONGraphs

        JET.test_package(LEMONGraphs, target_defined_modules = true)
    end
else
    @info "Skipping JET analysis (JET_TEST != true)"
end
