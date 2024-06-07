using CSV
using DataFrames
using GLMakie
using Shapefile

fname = "data/details/StormEvents_details-ftp_v1.0_d2020_c20240418.csv.gz"

data = CSV.File(fname) |> DataFrame

valid_ind = .!(ismissing.(data.BEGIN_LAT) .& ismissing.(data.END_LAT) .& ismissing.(data.BEGIN_LON) .& ismissing.(data.END_LON))

print(size(data))
data = data[valid_ind, :]
print(size(data))

data.lat_center = (data.BEGIN_LAT .+ data.END_LAT)./2
data.lon_center = (data.BEGIN_LON .+ data.END_LON)./2

f = Figure()
ax = Axis(f[1,1])
scatter!(ax, data.lon_center, data.lat_center)
f

data = Shapefile.Table("data/cb_2018_us_state_20m/cb_2018_us_state_20m.shp")

data.NAME