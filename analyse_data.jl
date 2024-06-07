using CSV
using DataFrames
using GLMakie
using Shapefile
using Rasters
using Dates
using Observables


include("core/io/read.jl")

storm_data = get_details(2023)

function remove_missing_loc(storm_data)
    valid_ind = .!(ismissing.(storm_data.BEGIN_LAT) .& ismissing.(storm_data.END_LAT) .& ismissing.(storm_data.BEGIN_LON) .& ismissing.(storm_data.END_LON))
    return storm_data[valid_ind, :]
end

storm_data = remove_missing_loc(storm_data)


function get_datetime(yearmonth, day, time)
    date = map(yearmonth, day, time) do ym, day, hs
        year =Int(floor(ym/100))
        month = ym - year*100
        hour = Int(floor(hs/100))
        second = hs - hour*100
        return DateTime(year, month, day, hour, second)
    end

    return date
end

begin_date_time = get_datetime(storm_data.BEGIN_YEARMONTH, storm_data.BEGIN_DAY, storm_data.BEGIN_TIME)
end_date_time = get_datetime(storm_data.END_YEARMONTH, storm_data.END_DAY, storm_data.END_TIME)

storm_data = select!(storm_data, Not([:BEGIN_YEARMONTH, :BEGIN_DAY, :BEGIN_TIME, :END_YEARMONTH, :END_DAY, :END_TIME]))

storm_data.begin_time = begin_date_time
storm_data.end_time = end_date_time

names(storm_data)

storm_data.EPISODE_ID

function damage_number(damage)
    dmg = map(damage) do x
        if ismissing(x)
            return convert(Float64, -1.0)
        elseif string(x[end]) == "K"
            return parse(Float64, x[1:end-1])*1000
        elseif string(x[end]) == "M" 
            return parse(Float64, x[1:end-1])*1000000
        elseif string(x[end]) == "B" 
            return parse(Float64, x[1:end-1])*1000000000
        else
            return parse(Float64, x)
        end
    end

return Float64.(dmg)
end

dmg = damage_number(storm_data.DAMAGE_PROPERTY)

storm_data.damage_property = dmg
select!(storm_data, Not(:DAMAGE_PROPERTY))


storm_data.lat_center = (storm_data.BEGIN_LAT .+ storm_data.END_LAT)./2
storm_data.lon_center = (storm_data.BEGIN_LON .+ storm_data.END_LON)./2

data = Shapefile.Table("data/cb_2018_us_state_20m/cb_2018_us_state_20m.shp")

Shapefile.shape(first(data)).parts

data.geometry[1].MBR


point_list = []
for row in eachrow(storm_data)
    push!(point_list, Point2f(row.lon_center, row.lat_center))
end


state_name = [n for n in data.NAME if !(n in ["Alaska", "Hawaii",  "Puerto Rico"])]
f = Figure(resolution=(1200, 1200))
menu = Menu(f[:, 13], options = state_name, default="California")

ax_map = Axis(f[1:7,1:12])
ax_state = Axis(f[8:12,1:6])
ax_hist = Axis(f[8:12,7:12])


for i=1:size(data.geometry)[1]
    
    geom = data.geometry[i]

    if !(data.NAME[i] in ["Alaska", "Hawaii",  "Puerto Rico"] )
        lon, lat = [], []
        map(geom.points) do p
            push!(lon, p.x)
            push!(lat, p.y)
        end

        for j=1:size(geom.parts)[1]-1

            start_ind = geom.parts[j]+1
            end_ind = geom.parts[j+1]
            lines!(ax_map, lon[start_ind:end_ind],  lat[start_ind:end_ind], color = :grey20)
        end
        lines!(ax_map, lon[geom.parts[end]+1:end],  lat[geom.parts[end]+1:end], color = :grey20)
        xlims!(ax_map, -125,-65)
        ylims!(ax_map, 24,50)

    end
end
f

scatter!(ax_map, storm_data.lon_center, storm_data.lat_center, markersize=2)
f


obs = Observable{String}("California")

l1 = on(obs) do val
    print("Observer is now $val");
end

geom_state = @lift data.geometry[data.NAME .== $obs][1]


function plot_state!(ax, geometry)
    
    ax_new = lift(geometry) do geom
        ax = empty!(ax)
        lon, lat = [], []        
        map(geom.points) do p
            push!(lon, p.x)
            push!(lat, p.y)
        end
        
        for j=1:size(geom.parts)[1]-1

            start_ind = geom.parts[j]+1
            end_ind = geom.parts[j+1]
            lines!(ax, lon[start_ind:end_ind],  lat[start_ind:end_ind], color = :grey20)
        end
        lines!(ax, lon[geom.parts[end]+1:end],  lat[geom.parts[end]+1:end], color = :grey20)
        pad = 1
        xlims!(ax, geom.MBR.left-pad, geom.MBR.right+pad )
        ylims!(ax, geom.MBR.bottom-pad, geom.MBR.top+pad )
        
        return ax
    end
    return ax_new
end

ax_state = plot_state!(ax_state, geom_state)

storm_points = map(storm_data.lon_center, storm_data.lat_center) do x, y 
    return Point2f(x, y)
end

state_storm_data = @lift storm_data[inpolygon(storm_points, $geom_state), :]


state_points = lift(state_storm_data) do ssd
    x = Float32.(ssd.lon_center)
    y = Float32.(ssd.lat_center)

    return Point2f.(x,y )
end


@lift scatter!($ax_state, state_points, markersize=3)



time = @lift $state_storm_data.begin_time


function plot_density!(ax, time)

    
    ax_new = lift(time) do dt
        ax = empty!(ax)

        n_events = size(dt)[1]        
        return density!(ax, Dates.month.(dt))

    end

    return ax_new

end

plot_density!(ax_hist, time)


on(menu.selection) do s 
    obs[] = s
end

