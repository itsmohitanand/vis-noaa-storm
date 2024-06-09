include("core/io/read.jl")
include("core/utils.jl")

storm_data = get_details([2010:2024;])

storm_data

storm_data |> CSV.write("data/processed_details_2010_2024.gzip", compress=true)

