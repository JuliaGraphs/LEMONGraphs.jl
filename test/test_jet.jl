@testitem "JET analysis" tags=[:jet] begin
    using JET
    using Test
    using LEMONGraphs

    JET.test_package(LEMONGraphs, target_defined_modules = true)
end
