@testitem "Aqua analysis" begin

using Aqua, LEMONGraphs

Aqua.test_all(LEMONGraphs, ambiguities=false)

end
