## Preconfigured downloaders
function writeUniprotMeta(downloader::Downloader,data::DataFrame;db=db,onconflict::String="REPLACE")
    tempTable,con  = createTempTable!(downloader;db=db)
    data = select(
        data,
        :accession,
        :metadata => ((x)->JSON3.write.(x)),
        :accession => ((x)->["https://rest.uniprot.org/uniprotkb/$i.json" for i in x]) => :json_url,
        :accession => ((x)->["https://www.uniprot.org/uniprotkb/$i/entry" for i in x]) => :page_url,
        :metadata =>((x)->[i.entryType for i in x]) => :status,
        :accession => ((x)->[Dates.format(Dates.now(),"YYYY-mm-dd HH:MM:SS") for i in x]) => :modified,
        renamecols = false
    )
    appendToTempTable!(data,tempTable,con,db=db)
    checkWrite(downloader,data,con,db=db,onconflict=onconflict)
end

uniprotMetaTableSpec = DBTableSpec(
    tableSchema = """CREATE TABLE IF NOT EXISTS uniprot_meta (
    accession varchar primary key,
    metadata json,
    json_url varchar,
    page_url varchar,
    status varchar,
    modified datetime
    )
    """,
    tableName = "uniprot_meta",
    insertRows = (downloader,data;db=db,onconflict::String="REPLACE")->writeUniprotMeta(downloader,data,db=db,onconflict=onconflict)
)

# use for downloading via uniprot accession id
uniprotAccessionDownloader =  BatchDownloader(
    epBase = "https://rest.uniprot.org/uniprotkb/search?&size=500&format=json&query=",
    tableSpec = uniprotMetaTableSpec,
    formatParams = (params)-> map(r->"accession:$(r)",params) .|> HTTP.escape |> y-> join(y,"+OR+"),
    transform = (resp) ->begin
        obj = JSON3.read(resp.body)
        res = obj.results
        nts = map(res) do obj
            (
                accession = obj.primaryAccession,
                metadata = obj
            )
        end
        DataFrame(nts)
    end,
    batchSize = 100,
)

#use the uniprotEnsemblDownloader for batch downloading based on ensembleId
uniprotEnsemblDownloader = BatchDownloader(
    epBase = "https://rest.uniprot.org/uniprotkb/search?size=500&format=json&query=",
    tableSpec = uniprotMetaTableSpec,
    formatParams = (params) -> map(r->"(xref:ensembl-$r)",params) .|> HTTP.escape |> y->join(y,"+OR+"),
    transform = (resp) -> JSON3.read(resp.body) |> y->y.results |> jsontable |> DataFrame,
    batchSize = 500,
)



#Functions
"""
    extractCrossRefs(downloader::BioInfoAggregator.Downloader; xref::Union{Nothing,String}=nothing, where::String="", db=db)

Extract and flatten UniProt cross-references from the local DuckDB database into a tidy `DataFrame`.

# Arguments
- `downloader`: A downloader instance conforming to the `uniprotAccessionDownloader` table specification.

# Keywords
- `where::String=""`: **Filter for the initial database fetch.** Use this to limit the scope of UniProt entries processed (e.g., `"primaryAccession = 'P12345'"`).
- `xref::Union{Nothing,String}=nothing`: **Filter for specific cross-reference types.** Use this to specify which external database references to return (e.g., `"PDB"`, `"Ensembl"`, or `"RefSeq"`). If `nothing`, all cross-references are returned.
- `db`: DuckDB database connection.

# Returns
- `DataFrame`: A flattened table containing cross-reference details associated with their `primaryAccession`.

# Implementation Details
The function performs a two-stage filtering process:
1. SQL-level filtering via the `where` clause during the initial `readDB` call.
2. Functional filtering of the resulting cross-reference collection based on the `xref` argument.
"""
function extractCrossRefs(downloader::BioInfoAggregator.Downloader; xref::Union{Nothing,String}=nothing, where::String="", db=db)
    @assert downloader.tableSpec == uniprotAccessionDownloader.tableSpec "Downloader must adhere to UniprotAccessionDownloader table spec."
    
    # Initial database fetch with user-defined where clause
    df = readDB(downloader; where=where, db=db)
    
    # Parse JSON metadata into a workable DataFrame
    metadata = JSON3.read.(df.metadata) |> JSON3.write |> jsontable |> DataFrame
    @assert "uniProtKBCrossReferences" in names(metadata) "No uniProtKBCrossReferences column found in data."
    
    # Functional extraction and mapping of nested cross-references
    xrefs = map(eachrow(metadata)) do row
        rawRefs = row.uniProtKBCrossReferences
        refDf = rawRefs |> jsontable |> DataFrame
        
        # Attach the primaryAccession to each cross-reference row
        transform(
            refDf,
            :database => (x -> repeat([row.primaryAccession], nrow(refDf))) => :primaryAccession
        )
    end
    
    # Combine individual DataFrames
    combinedRefs = vcat(xrefs..., cols=:union)
    
    # Filter by the specific xref database if requested
    return isnothing(xref) ? combinedRefs : filter(r -> r.database == xref, combinedRefs)
end



function getAccsByFamily(family::String;tableName::String="protein",db=db)
    conn = DBInterface.connect(db)
    DBInterface.execute(
        conn,
        "Select accession from $tableName where list_contains(interpro,?)",
        [family]
    ) |> DataFrame
end