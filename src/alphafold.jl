alphafoldTableSpec = DBTableSpec(
    tableSchema = """CREATE TABLE IF NOT EXISTS alphafold_meta 
    (
        accession VARCHAR,
        modelEntityId VARCHAR,
        entry JSON,
        PRIMARY KEY(accession,modelEntityId)
    )""",

    tableName = "alphafold_meta",
    insertRows = (downloader,data;db=db,onconflict::String="REPLACE")->defaultTableWrite(downloader,data,db=db,onconflict=onconflict)
)

function parseAlphafoldRespBody(body::Vector{UInt8})
    str = String(body)
    if !in(str,["{}","Internal Server Error","upstream request timeout"])
        json = JSON3.read(str)
        nts = map(json) do j
            (
                accession = get(j,"uniprotAccession",missing),
                modelEntityId = get(j,"modelEntityId",missing),
                entry = JSON3.write(j)
            )
        end |> DataFrame
    end
end



alphafoldDownloader = BatchDownloader(
    epBase = "https://alphafold.ebi.ac.uk/api/prediction/",
    tableSpec = alphafoldTableSpec,
    formatParams = (params)->first(params),
    transform = (resp)-> parseAlphafoldRespBody(resp.body),
    batchSize = 1
)
