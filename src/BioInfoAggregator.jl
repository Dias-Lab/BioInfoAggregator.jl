module BioInfoAggregator

using TOML, HTTP, DataFrames, JSON3, JSONTables, DuckDB, Dates


global configDict = TOML.parse(read("./config.toml",String))
global const dbDir = configDict["dirs"]["databaseDir"]
global const dbPath = joinpath(dbDir,configDict["databaseName"])
if !isdir(dbDir) mkpath(dbDir) end
global const db = DuckDB.DB(dbPath)
DBInterface.execute(db,"CHECKPOINT")
global const resultDir = configDict["dirs"]["results"]["resDir"]
global const fileSuffix = configDict["namingConfigs"]["fileSuffix"]
global const runDir = joinpath(resultDir,"runs")

try
    if !isdir(resultDir) mkpath(resultDir) end
    if !isdir(runDir) mkpath(runDir) end
    subDirs = [joinpath(resultDir,subDir) for subDir in configDict["dirs"]["resultSubDirs"]]
    #make subdirs
    for dir in subDirs
        if !isdir(dir) mkpath(dir) end
    end
catch e
    println("Check config file, there was an error initilizing directories: $e")
end




include("downloaderStructs.jl")
include("uniprot.jl")
include("interpro.jl")
include("ensembl.jl")
include("utils.jl")
include("embeddings.jl")
include("alphafold.jl")


export
    #consts
    configDict,
    db,
    resultDir,
    runDir,
    fileSuffix,
    #structs
    DBTableSpec,
    BatchDownloader,
    PaginatedDownloader,
    SingleDownloader,
    #shared functions
    fetchDownloads,
    readDB,
    aboutDB,
    writeData!,
    createTempTable!,
    appendToTempTable!,
    checkWrite,
    getAccsByFamily,
    generateFasta,
    #embeddings
    getEmbeddings,
    #preconfigured downloaders
    #uniprot
    #funcs
    writeUniprotMeta,
    extractCrossRefs,
    getAccsByFamily,
    #tableSpecs
    uniprotMetaTableSpec,
    #downloaders
    uniprotAccessionDownloader,
    uniprotEnsemblDownloader,
    #ensembl
    #tableSpecs
    ensemblTableSpec,
    #downloaders
    ensemblCDSFastaDownloader,
    #interpro
    #downloaders
    interproFamilyMemberDownloader,
    interproFamilyDownloader,
    #alphafold
    #tableSpecs
    alphafoldTableSpec,
    #downloaders 
    alphafoldDownloader

end