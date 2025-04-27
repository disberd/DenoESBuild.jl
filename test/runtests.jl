@testsnippet setup_deno begin
    using DenoESBuild: bundle, build, _deno, jscode
end

@testitem "Bundle multifile" setup=[setup_deno] begin
    dir = joinpath(@__DIR__, "multifile")
    f() = (; stdout = IOBuffer(), stderr = IOBuffer())
    s = f()
    _deno("run main_remote.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stdout)), "CHECK THIS")

    # Check without allowing npm
    _deno("run --no-npm main_remote.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stderr)), "but --no-npm is specified")

    # We test that the local errors as we don't have the bundle yet
    _deno("run --no-npm main_local.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stderr)), "Module not found") 

    # We now bundle the module
    bundle("module.ts", "bundled.js"; dir)
    _deno("run --no-npm main_local.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stdout)), "CHECK THIS")

    isfile(joinpath(dir, "bundled.js")) && rm(joinpath(dir, "bundled.js"))
end

@testitem "Bundle jscode" setup=[setup_deno] begin
    dir = joinpath(@__DIR__, "jscode")
    f() = (; stdout = IOBuffer(), stderr = IOBuffer())
    s = f()
    mainfile = joinpath(dir, "main.ts")
    _deno("run $mainfile"; stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stderr)), r"Module not found.*bundled\.js")

    bundledfile = joinpath(dir, "bundled.js")
    @test !isfile(bundledfile)
    # Build the bundle with absolute paths and using a temporary directory
    bundle(jscode("""
        import { ceil } from "npm:lodash-es"
        export { ceil }
    """), "jscode/bundled.js")

    @test isfile(bundledfile)

    _deno("run $mainfile"; stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stdout)), "The number is: 2")

    isfile(bundledfile) && rm(bundledfile)
end