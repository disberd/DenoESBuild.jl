"""
    build(; dir = pwd(), stdin = devnull, stdout = devnull, stderr = nothing, kwargs...)
    
Builds JavaScript/TypeScript code using esbuild.build through Deno.

This function creates a temporary build script and executes it with Deno to run esbuild.build.

The template of the generated build script is the following:
```js
import * as esbuild from "npm:esbuild@0.23.0";
import { denoPlugins, denoLoader, denoResolver, denoPluginOptions } from "jsr:@duesabati/esbuild-deno-plugin@0.2.6";

const result = await esbuild.build({
    plugins: [...denoPlugins()],
    ...kwargs
});

esbuild.stop();
```
where the kwargs passed to the julia function will be forwarded to the esbuild.build function using the JSON3.write function.

The generated build script following the template above will be run using the command:
```bash
deno run --allow-env --allow-read --allow-write --allow-net --allow-run --node-modules-dir <scriptpath>
```

## Keyword Arguments
- `dir`: Directory to run the deno command in (defaults to current directory)
- `stdin`, `stdout`, `stderr`: these are simply forwarded to the `pipeline` function that is wrapping the deno command
- `kwargs...`: Additional arguments passed to esbuild.build as options, example of valid arguments are:
  - `entryPoints`: Array of entry point file paths
  - `outfile`: Output file path
  - `bundle`: Whether to bundle dependencies (Boolean)
  - `format`: Output format (e.g., "esm", "cjs")
  - `minify`: Whether to minify the output (Boolean)
  - `platform`: Target platform (e.g., "browser", "node", "neutral")
  - `target`: Browser compatibility targets

# Example
```julia
build(;
    entryPoints = ["src/main.ts"],
    outfile = "dist/main.js",
    bundle = true,
    format = "esm",
    minify = true,
)
```
"""
function build(; dir = pwd(), stdin = devnull, stdout = devnull, stderr = nothing, kwargs...)
    dir = abspath(dir)
    mktemp(dir) do scriptpath, io
        default_build_script_contents(scriptpath; kwargs...)
        bin = default_build_command(scriptpath)
        _run(bin; dir, stdin, stdout, stderr)
    end
end

"""
    build(entrypoint::AbstractString, outfile::AbstractString; kwargs...)

Builds a single entry point file to an output file using esbuild.build through Deno.

This function is a shortcut for `build(; entryPoints = [entrypoint], outfile, kwargs...)`.
"""
function build(entrypoint::AbstractString, outfile::AbstractString; kwargs...)
    build(; entryPoints = [entrypoint], outfile, kwargs...)
end

"""
    bundle(entrypoint::AbstractString, outfile::AbstractString; kwargs...)

Bundles a single entry point file to a standalone output file using esbuild.build through Deno.

This function is a shortcut for `build(; entryPoints = [entrypoint], outfile, bundle = true, format = "esm", minify = true, platform = "browser", kwargs...)`.

# Example
```julia
bundle("src/main.ts", "dist/main.js")
``` 

See also: [`DenoESBuild.build`](@ref)
"""
function bundle(entrypoint::AbstractString, outfile::AbstractString; kwargs...) 
    entrypoint = abspath(entrypoint)
    outfile = abspath(outfile)
    mktempdir() do dir
        cd(dir) do
            build(entrypoint, outfile; dir, bundle = true, format = "esm", minify = true, platform = "browser", kwargs...)
        end
    end
end

"""
    bundle(code::DenoESBuild.JSCode, outfile::AbstractString; kwargs...)

Takes the input javascript/typescript code representing an ESM module and bundles it into a single standalone file `outfile` using esbuild.build through Deno.

This function simply creates a temporary file whose contents are the provided code and then calls 
```julia
bundle(entrypoint, outfile; kwargs...)
```
where `entrypoint` is the path to the temporary file containing the provided code.

# Example
```julia
bundle(DenoESBuild.jscode("export function hello() { return 'Hello, world!'; }"), "hello.js")
```

See also: [`DenoESBuild.build`](@ref), [`DenoESBuild.bundle`](@ref), [`DenoESBuild.jscode`](@ref)
""" 
function bundle(code::JSCode, args...; kwargs...) 
    entrypoint = tempname() * ".js"
    write(entrypoint, code.code)
    bundle(entrypoint, args...; kwargs...)
end
