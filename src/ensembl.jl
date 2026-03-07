ensemblTableSpec = DBTableSpec(
    tableSchema = """Create table if not exists ensembl_fasta_file(
    endemblId varchar primary key,
    fasta varchar,
    )
    """,
    tableName = "ensembl_fasta_file",
    insertRows = (downloader,data;db=db,onconflict::String="REPLACE")->defaultTableWrite(downloader,data,db=db,onconflict=onconflict)
    )

#use the ensemblCDSFastaDownloader to download fasta of the CDS for the ensemblId
ensemblCDSFastaDownloader = BatchDownloader(
    epBase = "https://rest.ensembl.org/sequence/id/",
    tableSpec = ensemblTableSpec,
    formatParams = (params) -> map(r->"$(split(r,".") |>first)?content-type=text/x-fasta;type=cds",params) |> y->join(y,""),
    transform = (resp) -> begin str = String(resp.body); DataFrame(:ensemblId=>[split(str,"\n")|>first |>y->replace(y,">" => "")],:fasta=>[str]) end,
    batchSize = 1
)