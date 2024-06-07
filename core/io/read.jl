using DataFrames
using CSV

function get_details(year::Int)
    data_details_folder = "data/details/"
    list_files = readdir(data_details_folder)

    fname = [f for f in list_files if occursin("d$(year)", f)][1]

    fname = data_details_folder * fname

    return CSV.File(fname) |> DataFrame
end