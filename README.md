# DenoESBuild.jl
[![Coverage](https://codecov.io/gh/disberd/DenoESBuild.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/disberd/DenoESBuild.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

DenoESBuild.jl is a Julia package that provides a simple interface for bundling JavaScript/TypeScript code using the `build` function of the [esbuild](https://esbuild.github.io/api/) library through Deno using the `Deno_jll.jl` package.

It also exploits the [esbuild-deno-plugin](https://github.com/due-sabati/esbuild-deno-plugin) to allow deno caching, module resolution and loading as part of the esbuild build process.

> [!NOTE]
> When bundling files that refer to remote imports (e.g. `npm:...`), an internet connection is in princple required to fetch the remote libraries. This is not the case if the target libraries are already availabile in the Deno cache.


This package does not export any function, but the following methods are considered part of the public API:
- [`DenoESBuild.build`](@ref)
- [`DenoESBuild.bundle`](@ref)
- [`DenoESBuild.JSCode`](@ref)

## Example Use

### Bundle from input code
Here is a simple code snippet that will generate a single js (stored in `./dist/main.js`) file containing defining an ESM module that extracts the `ceil` function from the lodash library and re-exports it
```julia
using DenoESBuild

DenoESBuild.bundle(
    DenoESBuild.JSCode("""
        import { ceil } from "npm:lodash-es"
        export { ceil }
    """),
    "dist/main.js"
)
```

The `DenoESBuild.bundle` function will automatically build with the following flags passed as options to `esbuild.build`:
- `minify: true`
- `format: "esm"`
- `platform: "browser"`

### Bundle from file
This works even for a module structure divided into multiple files, as in the simple example explained below, which is mirroring the structure of the [`test/multifile`](test/multifile) subfolder.

#### Folder Structure
```bash
test/multifile/
├── module.ts         # Source module with tree-shakable imports from the `npm:date-fns` library
├── main_remote.ts    # Imports directly from `module.ts`
├── main_local.ts     # Imports from the bundled output
└── bundled.js        # Bundled output (created by esbuild, not present by default)
```


#### `module.ts` contents
```typescript
import { format, differenceInDays } from "npm:date-fns";

// Only using the format function (differenceInDays will be tree-shaken out)
function formatCurrentDate() {
  const now = new Date();
  // Format: "Monday, January 1, 2023"
  console.log("CHECK THIS");
  return format(now, "EEEE, MMMM d, yyyy");
}

export { formatCurrentDate };
```

#### `main_remote.ts` contents
```typescript
import { formatCurrentDate } from "./module.ts";

console.log(formatCurrentDate());
```

#### `main_local.ts` contents
```typescript
import { formatCurrentDate } from "./bundled.js";

console.log(formatCurrentDate());
```

#### Creating the bundle

```julia
using DenoESBuild

dir = joinpath("test", "multifile")
DenoESBuild.bundle(
    "module.ts", # Specifies that the file `module.ts` should be bundled
    "bundled.js"; # Specifies the file that will contain the bundled code
    dir # Specifies that the build command should be run in the `test/multifile` directory
)
```