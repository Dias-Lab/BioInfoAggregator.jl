# BioInfoAggregator.jl

[![Build Status](https://github.com/nas2011/BioInfoAggregator.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/nas2011/BioInfoAggregator.jl/actions/workflows/CI.yml?query=branch%3Amaster)

`BioInfoAggregator.jl` is a Julia package designed to streamline the retrieval, aggregation, and storage of bioinformatics data from major public repositories. It provides a robust framework for managing high-volume biological data using **DuckDB** for high-performance local storage.

## Features

- **Multi-Source Aggregation**: Integrated support for fetching data from:
  - **UniProt**: Metadata, accessions, and cross-references (Ensembl, etc.).
  - **Ensembl**: Genomic and transcriptomic data (CDS Fasta, etc.).
  - **InterPro**: Protein family and domain information.
- **Robust Downloader Framework**:
  - `BatchDownloader`: For high-throughput retrieval using batched identifiers.
  - `PaginatedDownloader`: For APIs with cursor-based or offset-based pagination.
  - `SingleDownloader`: For targeted, individual record retrieval.
- **Local Database Management**:
  - Powered by **DuckDB** for efficient querying and storage.
  - Automated table schema management via `DBTableSpec`.
  - Transaction-safe writes using temporary staging tables.
- **Data Utilities**:
  - Fasta file generation for specific protein families.
  - Integration for handling vector embeddings (e.g., ESM-2).
  - Built-in functions for database inspection and filtered reading.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/nas2011/BioInfoAggregator.jl")
```

## Quick Start

### 1. Configuration
The package requires a `config.toml` in the project root to define database paths and naming conventions.

```toml
databaseName = "bioinfo.db"

[dirs]
databaseDir = "./data/db"
resultDir = "./results"
resultSubDirs = ["fasta", "plots", "tables"]

[namingConfigs]
fileSuffix = "_agg"
```

### 2. Loading the Package
```julia
using BioInfoAggregator

# Check the active database
aboutDB()
```

### 3. Fetching and Storing Data
The package provides pre-configured downloaders for common tasks.

```julia
# Fetch UniProt metadata for a list of accessions
accessions = ["O95905", "P08246"]
data = fetchDownloads(uniprotAccessionDownloader, accessions; verbose=true)

# Write to the local DuckDB database
writeData!(uniprotAccessionDownloader, data)

# Read it back
results = readDB(uniprotAccessionDownloader; where="status = 'reviewed'")
```

## Core Components

### Downloaders
All downloaders share a common interface through `fetchDownloads` and `writeData!`. They encapsulate endpoint base urls, headers, formatting logic, and transformation functions.

### Database Schema
Schemas are defined in `DBTableSpec` objects within the source files (e.g., `src/uniprot.jl`, `src/ensembl.jl`), ensuring consistency between the API response and the local database.

## Skills
This repository includes specialized **Skills** for use with Gemini CLI or other agentic workflows:
- `loadBioInfoAggregator`: Automated initialization of the package environment.
- `uniprot-fetcher`: Standardized workflow for UniProt data ingestion.

## Contributing
Contributions are welcome! Please ensure that any new downloaders follow the `Downloader` abstract type and include a corresponding `DBTableSpec`.
