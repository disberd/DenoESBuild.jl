"""
    build(; dir = pwd(), stdin = devnull, stdout = devnull, stderr = nothing, kwargs...)
    
Builds JavaScript/TypeScript code using esbuild.build through Deno.

This function creates a temporary build script (within the `dir` directory) which contains a call to `esbuild.build` and executes it with Deno.

The template of the generated build script is the following:
```js
import * as esbuild from "npm:esbuild@0.23.0";
import { denoPlugins, denoLoader, denoResolver } from "jsr:@duesabati/esbuild-deno-plugin@0.2.6";

const result = await esbuild.build({
    plugins: [...denoPlugins()],
    ...kwargs
});

esbuild.stop();
```
where the kwargs passed to the julia function will be forwarded to the esbuild.build function and translated into JS code using the `JSON3.write` function.

The generated build script following the template above will be run using the command:
```bash
deno run --allow-env --allow-read --allow-write --allow-net --allow-run --node-modules-dir <scriptpath>
```
where `<scriptpath>` is the path to the generated build script.

## Keyword Arguments
- `dir`: Directory to run the deno command in (defaults to current directory)
- `stdin`, `stdout`, `stderr`: these are simply forwarded to the [`Base.pipeline`](@ref) function that is wrapping the deno command
- `rethrow_errors`: Whether to errors that are encountered when trying to run a deno command. If `false` (default) then the error is printed on stdout but the julia execution does not stop. If `true` then the error is rethrown.
- `remove_node_modules`: Whether to remove the `node_modules` directory from the `dir` where the `deno` command is run after the build is finished. This defaults to `true` if there is no `node_modules` directory in `dir` before running the build command, and `false` otherwise.
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
function build(; dir = pwd(), stdin = devnull, stdout = devnull, stderr = nothing, remove_node_modules = nothing, rethrow_errors = false, entryPoints, kwargs...)
    nodes_modules_dir = joinpath(dir, "node_modules")
    clean_node_modules = @something remove_node_modules !isdir(nodes_modules_dir) # we remove if the dir did not exist already before building
    f = process_entrypoint(dir) # This we need for some windows issues, see the comment in process_entrypoint
    mktemp(dir) do scriptpath, io
        default_build_script!(scriptpath; entryPoints = map(f, entryPoints), kwargs...)
        bin = default_build_command(scriptpath)
        _run(bin; dir, stdin, stdout, stderr, rethrow_errors)
    end
    clean_node_modules && isdir(nodes_modules_dir) && rm(nodes_modules_dir, recursive = true)
    return nothing
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

Bundles a single entry point file to a standalone output file using `esbuild.build` through Deno.

This relies on the [deno-esbuild-plugin](https://github.com/due-sabati/deno-esbuild-plugin) to fully exploit Deno's caching, loading and module resolution capabilities. Making it easier to bundle JS modules on disk for offline use.

This function is a shortcut for `build(; entryPoints = [entrypoint], outfile, bundle = true, format = "esm", minify = true, platform = "browser", kwargs...)`.

# Example
```julia
using DenoESBuild

#= 
This will bundle all into a single js file located at `dist/main.js` all
functionality contained in `src/main.ts`, including all the required functions
used in `src/main.ts` but imported therein from other files or remote moduels
(e.g. npm).
=#
DenoESBuild.bundle("src/main.ts", "dist/main.js")
``` 

See also: [`DenoESBuild.build`](@ref)
"""
function bundle(entrypoint::AbstractString, outfile::AbstractString; kwargs...) 
    build(entrypoint, outfile; bundle = true, format = "esm", minify = true, platform = "browser", kwargs...)
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
function bundle(code::JSCode, args...; dir = pwd(), kwargs...) 
    mktemp(dir) do entrypoint, io
        write(io, code.code)
        close(io)
        bundle(entrypoint, args...; dir, kwargs...)
    end
end
