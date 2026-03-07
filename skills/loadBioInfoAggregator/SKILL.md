---
name: loadBioInfoAggregator
description: Load and initialize the BioInfoAggregator Julia package from its local source directory. Use when starting a new session or script that requires access to the aggregator's database utilities and downloaders.
---

# Loading BioInfoAggregator

Follow these steps to correctly load the package and initialize its global state (database connections and configuration).

## Standard Loading (from Project Root)

If you are working directly in the project root, use the following snippet:

```julia
using Pkg
Pkg.activate(".")
include("./src/BioInfoAggregator.jl")
using .BioInfoAggregator
```

## Loading from External Scripts

If your script is located in a subdirectory (e.g., `scripts/` or `test/`), ensure the path to the root is correctly specified:

```julia
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using .BioInfoAggregator
```

## Verification

After loading, verify that the package has initialized correctly by checking the global constants:

1. **Check Config**: `configDict` should contain the keys from `config.toml`.
2. **Check DB**: `db` should be an active DuckDB connection.
3. **Check Dirs**: `resultDir` and `runDir` should be established.

```julia
# Verify setup
println("Database Path: ", BioInfoAggregator.dbPath)
println("Results Directory: ", resultDir)
```

## Troubleshooting UNC Paths

If working on a network drive (UNC path), Julia may occasionally struggle with relative imports. Ensure you are using absolute paths for `Pkg.activate` if you encounter "Registry not found" or similar errors.