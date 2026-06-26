begin
    using Pkg
    Pkg.activate(".")
    include("../src/BioInfoAggregator.jl")
    using .BioInfoAggregator
end


# --- 1. UniProt Data Download ---
# Example UniProt accessions (using camelCase per GEMINI.md)
exampleAccessions = [
    "O95905",
    "Q6ZWK4",
    "P08246",
    "P42694",
    "P04439"
]

# Fetching metadata from UniProt.
# fetchDownloads is a functional method that returns a new DataFrame.
uniprotData = fetchDownloads(uniprotAccessionDownloader, exampleAccessions, verbose=true)

# Persist the downloaded data to the database specified in config.toml.
writeData!(uniprotAccessionDownloader, uniprotData)


# --- 2. Querying and Processing Data ---
# Read all UniProt metadata from our local database.
localUniprotData = readDB(uniprotAccessionDownloader)

# Extract specific cross-references (e.g., Ensembl) for entries starting with 'P'.
# xref specifies the database type, while where filters the initial database fetch.
ensemblXrefs = extractCrossRefs(
    uniprotAccessionDownloader, 
    xref="Ensembl", 
    where="accession like 'P%'"
)

# Extract the list of Ensembl IDs from the cross-references for further processing.
ensemblIds = ensemblXrefs.id


# --- 3. Ensembl Sequence Fetching ---
# Use the ensemblCDSFastaDownloader to fetch CDS FASTA sequences for the collected IDs.
fastaResults = fetchDownloads(
    ensemblCDSFastaDownloader, 
    ensemblIds; 
    verbose=true
)

# Write the FASTA data to the local database.
writeData!(ensemblCDSFastaDownloader, fastaResults)


# --- 4. InterPro Data Aggregation ---
# Define an InterPro family to investigate (e.g., Homeobox).
interproFamilyId = "IPR000046"

# Fetch member accessions belonging to this InterPro family.
familyMembers = fetchDownloads(
    interproFamilyMemberDownloader, 
    [interproFamilyId], 
    verbose=true
)

# Persist family members to the database.
writeData!(interproFamilyMemberDownloader, familyMembers)

# --- 5 Alphafold ---
# Alphafold Metadata Fetching
alphafoldData = fetchDownloads(
    alphafoldDownloader,
    exampleAccessions,
    verbose=true
)

# Write Alphafold Metadata to database
writeData!(alphafoldDownloader,alphafoldData)

# Query Alphafold metadata
readDB(alphafoldDownloader,where="(entry->>'\$.gene') in ('ECD','HELZ')")


# --- 6. Database Inspection ---
# Show the current state of our biological information aggregator.
availableTables = aboutDB()

