"""
    This function is responsible for retrieving downloads based on the specification of
    the downloader. 

    ```function fetchDownloads(downloader::BatchDownloader,params::Vector{String})```
"""
function fetchDownloads(downloader::BatchDownloader,params::Vector{String};verbose=false)
    batches = Iterators.partition(params,downloader.batchSize) |> collect
    res = asyncmap(batches,ntasks=downloader.ntasks) do batch
            if verbose print("\rstarting for batch $(join(first(batch,5),","))...") end
            ep = downloader.epBase * downloader.formatParams(batch)
            resp = HTTP.request("GET",ep,downloader.headers,decompress=false,status_exception=false)
            out = downloader.transform(resp)
    end
    vcat(res...,cols=:union)
end

"""
    This function is responsible for retrieving downloads based on the specification of
    the downloader. 

    ```function fetchDownloads(downloader::BatchDownloader,params::Vector{String})```
"""
function fetchDownloads(downloader::PaginatedDownloader,params::Vector{String};verbose=false,delay::Float64=1.0)
    batches = Iterators.partition(params,downloader.batchSize) |> collect
    res = asyncmap(batches,ntasks=downloader.ntasks) do batch
            if verbose println("starting for batch $(join(first(batch,5),","))...") end
            ep = downloader.epBase * downloader.formatParams(batch)
            if verbose println(ep) end
            resp = HTTP.request("GET",ep,downloader.headers,decompress=false)
            if verbose println("Response received for $(join(first(batch,5),","))... ") end
            body = resp.body
            out = downloader.transform(resp)
            next = downloader.getNextPage(resp)
            if verbose println("Next at : $next") end
            while !isnothing(next)
                if verbose print("\r$(nrow(out)) fetched. Fetching next at $next") end
                sleep(delay)
                resp =  HTTP.request("GET",next,downloader.headers,decompress=false,status_exception = false)
                addition = downloader.transform(resp)
                out = vcat(out,addition,cols=:union)
                next = downloader.getNextPage(resp)
            end
            return out
    end
    out = vcat(res...,cols=:union)
    if verbose println("\r$(nrow(out)) fetched.") end
    return out
end

"""
Writes data to a table based on the TableSpec defined by the downloader.
`function writeData!(downloader::BioInfoAggregator.Downloader,data::DataFrame;db=db,onconflict::String="REPLACE")`
"""
function writeData!(downloader::BioInfoAggregator.Downloader,data::DataFrame;db=db,onconflict::String="REPLACE")
    data = downloader.tableSpec.insertRows(downloader,data,db=db,onconflict=onconflict)
    DBInterface.execute(db,"CHECKPOINT")
    return data
end

function defaultTableWrite(downloader::Downloader,data::DataFrame;db=db,onconflict::String="REPLACE")
    tempTable,con  = createTempTable!(downloader;db=db)
    appendToTempTable!(data,tempTable,con,db=db)
    checkWrite(downloader,data,con,db=db,onconflict=onconflict)
end


"""
    createTempTable!(downloader::BioInfoAggregator.Downloader; db=db)

Initialize a persistent table and a matching temporary table in the DuckDB database.

This function ensures the target table exists (via `CREATE TABLE IF NOT EXISTS`) and creates 
a session-specific `TEMP TABLE` with the prefix `temp_` for staging data. This pattern 
is typically used for safe batch insertions or data validation before final commit.

# Arguments
- `downloader::BioInfoAggregator.Downloader`: The downloader providing the `tableSpec` 
  (schema and table name).

# Keywords
- `db`: The DuckDB database handle. Defaults to the global `db`.

# Returns
- `Tuple{String, DuckDB.Connection}`: A pair containing:
  1. The name of the newly created temporary table (e.g., `"temp_fasta_file"`).
  2. The active database connection `con`. **Note:** The caller is responsible for 
     closing this connection after the transaction is complete.

# Example
```julia
tempName, con = createTempTable!(uniprotAccessionDownloader)
# Perform staging operations in tempName using con...
```
"""
function createTempTable!(downloader::BioInfoAggregator.Downloader; db=db)
    con = DBInterface.connect(db)
    schema = downloader.tableSpec.tableSchema
    table = downloader.tableSpec.tableName
    
    tempTable = "temp_$(table)"
    
    # Transform persistent schema into a temporary schema
    # "IF NOT EXISTS" is removed for the temp table to ensure a fresh staging area
    tempSchema = replace(schema, "TABLE" => "TEMP TABLE", table => tempTable, "IF NOT EXISTS" => "")
    
    # Ensure persistent table exists
    DBInterface.execute(con, schema)    
    
    # Create the temporary staging table
    DBInterface.execute(con, tempSchema)
    
    return tempTable, con
end

"""
    appendToTempTable!(data::DataFrame, tableName::String, con::DuckDB.Connection; db=db)

Stream data from a `DataFrame` into a DuckDB table using the high-performance `Appender` API.

This function is optimized for bulk loading. It iterates through the `DataFrame` and appends 
each row to the specified table (typically a temporary staging table) while providing 
real-time progress updates in the terminal.

# Arguments
- `data::DataFrame`: The source dataset to be uploaded.
- `tableName::String`: The name of the target table (e.g., a temporary table created by `createTempTable!`).
- `con::DuckDB.Connection`: An active database connection.

# Keywords
- `db`: The database handle. Defaults to the global `db`.

# Returns
- `DuckDB.Connection`: The same connection object, allowing for subsequent operations.

# Note
This function automatically closes the `Appender` upon completion but leaves the 
`Connection` open for further use (e.g., merging the temp table into a persistent one).
"""
function appendToTempTable!(data::DataFrame,tableName::String,con::DuckDB.Connection;db=db)
    i = 1
    appender = DuckDB.Appender(con,tableName)
    for row in eachrow(data)
        print("\rInserting row $i")
        for field in row
            DuckDB.append(appender,field)
        end
        DuckDB.end_row(appender)
        i += 1
    end
    DuckDB.close(appender)
    return con
end

"""
    checkWrite(downloader::BioInfoAggregator.Downloader, data::DataFrame, con::DuckDB.Connection; db=db, onconflict::String="REPLACE")

Finalize a database write operation by verifying the staged data before merging into the main table.

This function acts as a safety gate for data ingestion. It compares the content of the 
temporary staging table (created via `createTempTable!`) against the original `DataFrame`. 

# Arguments
- `downloader`: The downloader instance specifying the target `tableName`.
- `data::DataFrame`: The original dataset that was intended for upload.
- `con::DuckDB.Connection`: The active database connection used for the staging operations.

# Keywords
- `db`: Database handle. Defaults to global `db`.
- `onconflict::String="REPLACE"`: SQL conflict resolution strategy. Options: `"REPLACE"`, `"IGNORE"`.

# Returns
- `DataFrame`: If the write is successful, returns the data that was written.
- `NamedTuple`: If there is a count mismatch, returns `(wrote = writtenDataFrame, connector = con)` 
  to allow for manual inspection of the temporary table.

# Behavior
- **Success:** If the row count matches, the staged data is inserted into the persistent table 
  using the specified `onconflict` strategy. The temporary table is then dropped and the 
  connection is closed.
- **Mismatch:** If the row count does not match, a warning is issued, and the temporary 
  table is preserved for debugging. The connection remains open.
"""
function checkWrite(downloader::BioInfoAggregator.Downloader, data::DataFrame, con::DuckDB.Connection; db=db, onconflict::String="REPLACE")
    conflictOptions = ["IGNORE", "REPLACE"]
    @assert in(onconflict, conflictOptions) "Options for onconflict are $conflictOptions"
    
    table = downloader.tableSpec.tableName
    tempTable = "temp_$(table)"
    
    # Retrieve what was actually staged
    written = DBInterface.execute(con, "SELECT * FROM $tempTable") |> DataFrame
    writtenLen = nrow(written)
    dataLen = nrow(data)
    
    if writtenLen != dataLen
        @warn "You only wrote $writtenLen of $dataLen records. The temporary table '$tempTable' has been preserved for inspection."
        return (wrote = written, connector = con)
    else
        try
            # Atomically merge and cleanup
            DBInterface.execute(con, "INSERT OR $onconflict INTO $table SELECT * FROM $tempTable")
            DBInterface.execute(con, "DROP TABLE $tempTable")
            DBInterface.close(con)
            return written
        catch e
            throw(e)
        end
    end
end


"""
    readDB(downloader::BioInfoAggregator.Downloader; where::String="", db=db)

Retrieve data from the DuckDB database table associated with a specific `downloader`.

This function dynamically identifies the target table using the `tableSpec` within 
the `downloader` object. It returns the query results as a `DataFrame`.

# Arguments
- `downloader::BioInfoAggregator.Downloader`: The downloader object whose associated 
  table should be queried.

# Keywords
- `where::String=""`: An optional SQL `WHERE` clause to filter results (e.g., `"status = 'reviewed'"`).
- `db`: The DuckDB database connection. Defaults to the global `db` constant.

# Returns
- `DataFrame`: A collection of all rows and columns matching the query.

# Example
```julia
# Read all entries from the uniprot metadata table
metaData = readDB(uniprotAccessionDownloader)

# Read specific entries with a filter
specificData = readDB(ensemblCDSFastaDownloader; where="ensemblId = 'ENSG00000139618'")
```
"""
function readDB(downloader::BioInfoAggregator.Downloader; where::String="", db=db)
    tableName = downloader.tableSpec.tableName
    whereRegex = r"^(where|WHERE|Where)"
    where = occursin(whereRegex,where) ? replace(where, whereRegex=>"") : where
    whereClause = where != "" ? " WHERE $where" : ""
    
    stmt = "SELECT * FROM $tableName" * whereClause
    return DBInterface.execute(db, stmt) |> DataFrame
end

function aboutDB(;db=db)
    DBInterface.execute(db,"call duckdb_tables()") |> DataFrame |>
    y->select(
        y,
        [:database_name,:table_name,:estimated_size,:column_count,:has_primary_key]
    )
end

function getAccsByFamily(family::String;tableName::String="protein",db=db)
    conn = DBInterface.connect(db)
    DBInterface.execute(
        conn,
        "Select accession from $tableName where list_contains(interpro,?)",
        [family]
    ) |> DataFrame
end

#vector embedding functions
"""Function to change JSO3.Array type to Array{Float64}"""
function typed_copy(j3arr)
    n = length(j3arr)
    x = Vector{Float32}(undef, n)
    for i in 1:n
        x[i] = j3arr[i]
    end
    return x
end

function arrayColToFloat(vec)
    map(vec) do x
        ismissing(x) ? x : typed_copy(x)
    end
end

function loadVecs(res::DuckDB.QueryResult)
    df = DataFrame(res)
    transform(
        df,
        names(df,r"embed") .=> arrayColToFloat,
        renamecols = false
        )
end

function generateFasta(family::String,outdir::String;db=db)
    conn = DBInterface.connect(db)
    data = DBInterface.execute(
        conn,
        """select
            p.accession
            ,p.sequence
        from
            protein p left join embeddings e on p.accession = e.accession
        where
            e.esm_embed is null
            and list_contains(p.interpro,?)""",
        [family]
        ) |> DataFrame
    DBInterface.close(conn)
    towrite = map(eachrow(data)) do x
        """>$(x.accession)
        $(x.sequence)"""
    end |> y-> join(y,"\n")
    outFile = joinpath(outdir,"$(family).fasta")
    write(outFile,towrite)
    return outFile
end
