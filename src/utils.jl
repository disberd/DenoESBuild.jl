struct JSCode
    code::String
end
@inline StructTypes.StructType(::Type{JSCode}) = JSON3.RawType()
@inline JSON3.rawbytes(x::JSCode) = codeunits(x.code)

"""
    jscode(s::AbstractString)

Takes a string `s` representing javascript/typescript code and returns a `JSCode` object wrapping it.

The main purpose of this is to handle custom printing through `JSON3.write` and to dispatch the [`DenoESBuild.bundle`](@ref) function.

See also: [`DenoESBuild.bundle`](@ref)
"""
jscode(s::AbstractString) = JSCode(s)

default_build_command(scriptpath::AbstractString) = deno_command(
    :run, 
    "--allow-env",
    "--allow-read",
    "--allow-write",
    "--allow-net",
    "--allow-run",
    "--node-modules-dir",
    scriptpath
)

# Create the default build script
function default_build_script_contents(filepath::AbstractString; prettify_file = false, kwargs...) 
    open(filepath, "w") do io
        println(io, "import * as esbuild from \"npm:esbuild@0.23.0\";")
        println(io, "import { denoPlugins, denoLoader, denoResolver, denoPluginOptions } from \"jsr:@duesabati/esbuild-deno-plugin@0.2.6\";")

        println(io)
        println(io, "// Build the bundle")

        print(io, "const result = await esbuild.build(")

        build_options = (;
            plugins = [jscode("...denoPlugins()")],
            kwargs...
        )

        # Write the option to build
        JSON3.write(io, build_options)

        println(io, ");")
        println(io)
        println(io, "esbuild.stop();")
    end
    if prettify_file
        # Prettify
        _deno(:fmt, filepath; stdout = devnull)
    end
    return filepath
end
# Version that returns the contents as a string
function default_script_contents(::Type{String}; kwargs...)
    filepath = tempname() * ".js"
    default_script_contents(filepath; kwargs...)
    return read(filepath, String)
end