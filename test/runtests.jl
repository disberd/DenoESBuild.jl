using TestItemRunner

@testsnippet setup_deno begin
    using DenoESBuild: bundle, build, _deno, JSCode, prettify
    using Logging
    using Test
end

@testitem "Bundle multifile" setup=[setup_deno] begin
    dir = joinpath(@__DIR__, "multifile")
    f() = (; stdout = IOBuffer(), stderr = IOBuffer())
    s = f()
    _deno("run main_remote.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stdout)), "CHECK THIS")

    s = f()
    # Check without allowing npm
    _deno("run --no-npm main_remote.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stderr)), "but --no-npm is specified")

    s = f()
    # We test that the local errors as we don't have the bundle yet
    _deno("run --no-npm main_local.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stderr)), "Module not found") 

    s = f()
    # We now bundle the module
    bundle("module.ts", "bundled.js"; dir)
    _deno("run --no-npm main_local.ts"; dir, stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stdout)), "CHECK THIS")

    isfile(joinpath(dir, "bundled.js")) && rm(joinpath(dir, "bundled.js"))
end

@testitem "Bundle JSCode" setup=[setup_deno] begin
    dir = joinpath(@__DIR__, "jscode")
    f() = (; stdout = IOBuffer(), stderr = IOBuffer())
    s = f()
    mainfile = joinpath(dir, "main.ts")
    _deno("run $mainfile"; stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stderr)), r"Module not found.*bundled\.js")

    bundledfile = joinpath(dir, "bundled.js")
    @test !isfile(bundledfile)
    # Build the bundle with absolute paths and using a temporary directory
    bundle(JSCode("""
        import { ceil } from "npm:lodash-es"
        export { ceil }
    """), "jscode/bundled.js")

    @test isfile(bundledfile)

    s = f()
    _deno("run $mainfile"; stderr = s.stderr, stdout = s.stdout)
    @test contains(String(take!(s.stdout)), "The number is: 2")

    isfile(bundledfile) && rm(bundledfile)
end

@testitem "Prettify" setup=[setup_deno] begin
    code = JSCode("console.log(    'asd')")
    @test prettify(code) == "console.log(\"asd\");\n"
end

@testitem "Deno Errors" setup=[setup_deno] begin
    test_logger = TestLogger()
    io = IOBuffer()
    with_logger(test_logger) do
        _deno("info asdf"; stderr = io)
    end
    @test contains(String(take!(io)), "error: module could not be found")
    logrecord = pop!(test_logger.logs)
    @test :deno_error ∉ keys(logrecord.kwargs)

    with_logger(test_logger) do
        _deno("error asdf"; stderr = devnull)
    end
    logrecord = pop!(test_logger.logs)
    @test :deno_error ∈ keys(logrecord.kwargs)
    
    @test_throws ProcessFailedException _deno("info asdf"; stderr = devnull, rethrow_errors = true)
end

@testitem "Aqua" begin
    using Aqua
    Aqua.test_all(DenoESBuild)
end

@run_package_tests verbose=true