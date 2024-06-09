using DataFrames
using CSV

function read_details(year::Int)
    data_details_folder = "/Users/mohitanand/Documents/data/vis-noaa-repo/details/"
    list_files = readdir(data_details_folder)

    fname = [f for f in list_files if occursin("d$(year)", f)][1]

    fname = data_details_folder * fname

    return CSV.File(fname) |> DataFrame
end




