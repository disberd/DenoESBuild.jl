# DenoESBuild.jl

DenoESBuild.jl is a Julia package that provides a simple interface to the `esbuild` JavaScript/TypeScript bundler through Deno using the `Deno_jll.jl` package.

It also exploits the [esbuild-deno-plugin](https://github.com/due-sabati/esbuild-deno-plugin) to allow deno module resolution and loading as part of the esbuild build process.

This package does not export any function, but the following methods are considered part of the public API:
- [`DenoESBuild.build`](@ref)
- [`DenoESBuild.bundle`](@ref)
- [`DenoESBuild.jscode`](@ref)








