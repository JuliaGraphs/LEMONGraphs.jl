A very thin Julia wrapper around the C++ graphs library [`LEMON`](http://lemon.cs.elte.hu/).

Currently used mainly for its Min/Max Weight Perfect Matching algorithm,
wrapped into a more user-friendly API in GraphsMatching.jl,
but additional bindings can be added on request.

No public API is provided yet.

Depends on `LEMON_jll`, which is compiled and packaged for all platforms supported by Julia.
