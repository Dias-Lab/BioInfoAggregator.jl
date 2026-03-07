@kwdef mutable struct DBTableSpec
    tableSchema::String
    tableName::String
    insertRows::Function
end

abstract type Downloader end

@kwdef mutable struct BatchDownloader <: Downloader
    epBase::String
    tableSpec::Union{Nothing,DBTableSpec}=nothing
    headers::Union{Vector{Pair{String,String}},Dict{String,String}}=Pair{String,String}[]
    formatParams::Function
    transform::Function
    ntasks::Int=Threads.nthreads()
    validate::Union{Nothing,Function}=nothing
    batchSize::Int
  
end

@kwdef mutable struct PaginatedDownloader <: Downloader
    epBase::String
    tableSpec::Union{Nothing,DBTableSpec}=nothing
    headers::Vector{Pair{String,String}}=Pair{String,String}[]
    formatParams::Function
    transform::Function
    ntasks::Int=Threads.nthreads()
    validate::Union{Nothing,Function}=nothing
    batchSize::Int
    getNextPage::Function
    
end

@kwdef mutable struct SingleDownloader <: Downloader 
    epBase::String
    tableSpec::Union{Nothing,DBTableSpec}=nothing
    headers::Union{Vector{Pair{String,String}},Dict{String,String}}=Pair{String,String}[]
    formatParams::Function
    transform::Function
    ntasks::Int=Threads.nthreads()
    validate::Union{Nothing,Function}=nothing
end

