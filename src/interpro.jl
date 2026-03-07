

interproMemberTableSpec = DBTableSpec(
    tableSchema = """CREATE TABLE IF NOT EXISTS interpro_data(
    uniprot_accession VARCHAR PRIMARY KEY,
    metadata_name VARCHAR,
    metadata_source_database VARCHAR,
    metadata_length BIGINT,
    metadata_source_organism VARCHAR,
    metadata_gene VARCHAR,
    metadata_in_alphafold BOOLEAN,
    metadata_in_bfvd BOOLEAN,
    interpro_accession VARCHAR,
    entry_entry_protein_locations VARCHAR,
    entry_protein_length BIGINT,
    entry_source_database VARCHAR,
    entry_entry_type VARCHAR,
    entry_entry_integrated VARCHAR)""",
    tableName = "interpro_data",
    insertRows = (downloader,data;db=db,onconflict::String="REPLACE")->defaultTableWrite(downloader,data,db=db,onconflict=onconflict)
)

#download data about the members of the family
interproFamilyMemberDownloader = PaginatedDownloader(
    #epBase = "https://www.ebi.ac.uk/interpro/api//protein/UniProt/entry/InterPro",    
    epBase = "https://www.ebi.ac.uk/interpro/api/protein/UniProt/entry/InterPro",
    formatParams = (params)->"/$(first(params))?page_size=200&format=json",
    transform = (resp)->begin
        JSON3.read(resp.body) |>
            y->map(y.results) do r
                    hcat(
                        r.metadata |> DataFrame |> y->rename(y,["metadata_$i" for i in names(y)]),
                        r.entries  |> DataFrame |> y->rename(y,["entry_$i" for i in names(y)]) 
                )
                end |>
             y->vcat(y...)|>
             y->rename(y,[:metadata_accession=>:uniprot_accession,:entry_accession=>:interpro_accession]) |>
            y->transform(
                y,
                names(y) .=> (x->eltype(x) <: Union{JSON3.Object, JSON3.Array} ? [isnothing(i) ? missing : string(i) for i in x] : x),
                renamecols = false
            )
    end,
    getNextPage = (resp)-> JSON3.read(resp.body) |> y-> try y.next  catch nothing end,
    batchSize = 1,
    ntasks = Threads.nthreads(),
    tableSpec = interproMemberTableSpec
)

#Download data about a specific family
interproFamilyDownloader = PaginatedDownloader(    
    epBase = "https://www.ebi.ac.uk/interpro/api/entry/InterPro",
    formatParams = (params)->"/$(first(params))/?page_size=2&format=json",
    transform = (resp)-> JSON3.read(resp.body) |>y->"[$(JSON3.write(y.metadata))]" |> y->jsontable(y)|> DataFrame,
    getNextPage = (resp)-> JSON3.read(resp.body) |> y-> try y.next catch nothing end,
    batchSize = 1,
    ntasks = Threads.nthreads(),
)