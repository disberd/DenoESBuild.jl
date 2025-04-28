"""
    DenoESBuild.JSCode(s::AbstractString)

Takes a string `s` representing javascript/typescript code and returns a `JSCode` object wrapping it.

The main purpose of this is to handle custom printing through `JSON3.write` and to dispatch the [`DenoESBuild.bundle`](@ref) function.

See also: [`DenoESBuild.bundle`](@ref)
"""
struct JSCode
    code::String
end
@inline StructTypes.StructType(::Type{JSCode}) = JSON3.RawType()
@inline JSON3.rawbytes(x::JSCode) = codeunits(x.code)

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
function default_build_script!(filepath::AbstractString; kwargs...)
    open(filepath, "w") do io
        default_build_script!(io; kwargs...)
    end
    return filepath
end
function default_build_script!(io::IO; kwargs...)
    # Version that returns the contents as a string
    println(io, "import * as esbuild from \"npm:esbuild@0.23.0\";")
    println(io, "import { denoPlugins, denoLoader, denoResolver } from \"jsr:@duesabati/esbuild-deno-plugin@0.2.6\";")

    println(io)
    println(io, "// Build the bundle")

    print(io, "const result = await esbuild.build(")

    build_options = (;
        plugins=[JSCode("...denoPlugins()")],
        kwargs...
    )

    # Write the option to build
    JSON3.write(io, build_options)

    println(io, ");")
    println(io)
    println(io, "esbuild.stop();")
end


"""
    prettify(files::Vector{<:AbstractString}, options::AbstractString...; kwargs...)
    prettify(file::AbstractString, options::AbstractString...; kwargs...)
    prettify(code::JSCode, options::AbstractString...; kwargs...)

Prettify the given code or file(s) using the Deno formatter via the `deno fmt` command.
All extra arguments are directly forwarded to the deno call with the following synthax 
```
deno fmt [options] [files]
```

If the first input is an object of type `JSCode`, the function will return the formatted code as a String.

See also: [`DenoESBuild.JSCode`](@ref)
"""
function prettify(filepaths::Vector{<:AbstractString}, options::AbstractString...; kwargs...)
    _deno(:fmt,
        options...,
        filepaths...;
        kwargs...)
end
prettify(filepath::AbstractString, options::AbstractString...; kwargs...) = prettify([filepath], options...; kwargs...)
function prettify(code::JSCode, options::AbstractString...; kwargs...)
    filepath = tempname() * ".js"
    try
        open(filepath, "w") do io
            print(io, code.code)
        end
        prettify(filepath, options...; stderr=devnull, kwargs...)
        read(filepath, String)
    finally
        rm(filepath)
    end
end

#= 
We need this function because on windows entry points with absolute paths are broken as the drive letter gets removed from the path. 
See this comment on reddit: https://www.reddit.com/r/Deno/comments/1j5puzk/comment/mgmajp0
And these related issues where the drive letter is evident from examples but not explicitly mentioned:
- https://github.com/slackapi/deno-slack-sdk/issues/258
- https://github.com/slackapi/deno-slack-sdk/issues/391

The approach here is to make all paths relative so the drive letter is not present. Unfortunately this does not work if the 
=#
function process_entrypoint(entrypoint::AbstractString, dir::AbstractString)
    isabspath(entrypoint) || return entrypoint
    if Sys.iswindows()
        f(path) = lowercase(first(path)) # Find the drive letter
        f(dir) == f(entrypoint) || let 
            @error "The drive letters of the entrypoint and the dir where build is being run are not matching, and this causes errors on windows. Please call the `deno` command from the same drive where the entrypoint file is located." dir entrypoint
            error("dir and entrypoint on different windows drives")
        end
        newpath = relpath(entrypoint, dir)
        return newpath
    else
        return entrypoint
    end
end
function process_entrypoint(entrypoint, dir::AbstractString)
    if Sys.iswindows()
        # We assume entrypoint is an object that can be converted to json with JSON3.write. We go back and forth from JSON to get a consistent output type
        d = entrypoint |> JSON3.write |> JSON3.read |> copy # The copy is just to make the JSON3.Object a plain dict
        path = get(d, :in, "")
        isabspath(path) || return d # If we don't have an abspath in the `in` field we just return the dict as is
        # If we get here, there is an abspath in the `in` field so we have to process it
        d[:in] = process_entrypoint(path, dir)
        return d
    else
        # There is no problem with abspaths on linux/macos so we simply return
        return entrypoint
    end
end
process_entrypoint(dir::AbstractString) = Base.Fix2(process_entrypoint, dir)
