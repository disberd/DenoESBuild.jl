# DenoESBuild.jl
[![Build Status](https://github.com/disberd/DenoESBuild.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/disberd/DenoESBuild.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/disberd/DenoESBuild.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/disberd/DenoESBuild.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

DenoESBuild.jl is a Julia package that provides a simple interface for bundling JavaScript/TypeScript code using the `build` function of the [esbuild](https://esbuild.github.io/api/#build) library through Deno using the `Deno_jll.jl` package.

It also exploits the [esbuild-deno-plugin](https://github.com/twosaturdayscode/esbuild-deno-plugin) to allow deno caching, module resolution and loading as part of the esbuild build process.

> [!NOTE]
> When bundling files that refer to remote imports (e.g. `npm:...`), an internet connection is in principle required to fetch the remote libraries. This is not the case if the target libraries are already availabile in the Deno cache.


This package does not export any function, but the following methods are considered part of the public API:
- `DenoESBuild.build`
- `DenoESBuild.bundle`
- `DenoESBuild.JSCode`

## Example Use
The two examples below are both for the `bundle` function as that is the easiest way to use this package.

The `DenoESBuild.bundle` function is simply a small wrapper around the `DenoESBuild.build` function, that automatically sets the following flags to be passed as options to `esbuild.build`:
- `bundle: true`
- `minify: true`
- `format: "esm"`
- `platform: "browser"`

See the docstring of the `DenoESBuild.build` function for more details on its use.

### Bundle from input code
Here is a simple code snippet that will generate a single js (stored in `./dist/main.js`) file containing an ESM module that extracts the `ceil` function from the lodash library and re-exports it
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