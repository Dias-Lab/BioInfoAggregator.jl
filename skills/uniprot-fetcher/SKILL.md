---
name: uniprot-fetcher
description: Retrieve and store UniProt metadata using the uniprotAccessionDownloader. Use when you need to fetch biological entry data from UniProt using accession IDs and persist it to the DuckDB database.
---

# UniProt Data Fetching Workflow

This skill provides a standardized workflow for retrieving metadata from UniProt and storing it in the project's DuckDB database.

## Prerequisites

- The `BioInfoAggregator` module must be loaded.
- A valid `config.toml` must exist in the root directory.

## Core Workflow

To fetch and store UniProt data:

1. **Identify Accessions**: Gather a list of UniProt accession IDs (e.g., `["O95905", "P08246"]`).
2. **Fetch Data**: Use the `fetchDownloads` function with the `uniprotAccessionDownloader`.
   ```julia
   using BioInfoAggregator
   accessions = ["O95905", "P08246"]
   data = fetchDownloads(uniprotAccessionDownloader, accessions; verbose=true)
   ```
3. **Persist Data**: Use `writeData!` to store the results in the `uniprot_meta` table.
   ```julia
   writeData!(uniprotAccessionDownloader, data)
   ```

## Key Components

- **Downloader**: `uniprotAccessionDownloader` (BatchDownloader)
- **Table**: `uniprot_meta` (defined in `uniprotMetaTableSpec`)
- **Staging**: Uses `createTempTable!`, `appendToTempTable!`, and `checkWrite` internally via `writeUniprotMeta`.

## Post-Processing

After fetching, you can query the database or extract cross-references:

- **Read DB**: `readDB(uniprotAccessionDownloader)`
- **Extract Xrefs**: `extractCrossRefs(uniprotAccessionDownloader, xref="Ensembl")`
