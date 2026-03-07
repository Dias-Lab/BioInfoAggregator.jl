function getEmbeddings(family::String,embedColNames::Vector{String}
;querymod::String="",excludenulls::Bool=true,limit::Union{Nothing,Int}=nothing,db=db)
    conn = DBInterface.connect(db)
    if embedColNames == ["*"]
        df = DBInterface.execute(conn, "describe embeddings") |> DataFrame
        embedColNames = filter(r->occursin("_embed",r),df.column_name)
    end
    querymod = querymod != "" ? "and $querymod" : ""
    if excludenulls
        modifiers = ["$i is not null" for i in embedColNames]
        modString = join(modifiers, " and ")
        querymod = querymod * "and $modString"
    end
    if isa(limit,Int)
        querymod = querymod * " limit $limit"
    end
    colStringParts = ["e.$(i)::FLOAT[] as $(i)" for i in embedColNames]
    colString = join(colStringParts,",")
    try
        DBInterface.execute(
            conn,
            """SELECT 
                e.accession,
                $colString
            from
                embeddings as e left join protein as p on e.accession = p.accession
            where
                list_contains(p.interpro,?) $querymod""",
            [family]
        ) |> loadVecs
        
    catch e
        throw(e)
    finally
        DBInterface.close(conn)
    end
end